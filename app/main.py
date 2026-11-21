"""Sistema de Gestion de Personal y Control de Asistencia - Registro de personal.

Sin frameworks: servidor HTTP de la libreria estandar (http.server) + conector MySQL.
Todo INSERT / UPDATE / DELETE se hace llamando a procedimientos almacenados
(04 y 06) y las reglas de negocio las aplican los triggers (05).
"""
import json
import os
import re
import sys
import base64
import binascii
import ipaddress
from contextlib import contextmanager
from datetime import date, datetime, timedelta
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse, quote

from mysql.connector import Error

import conexion
import sesiones
from reportes import catalogo, ejecutar_reporte


# ---------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------
def carpeta_recursos():
    """Carpeta con index.html / styles.css / app.js (dentro del .exe usa _MEIPASS)."""
    return getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))


ARCHIVOS_ACCESO = {
    '/login': ('login.html', 'text/html; charset=utf-8'),
    '/login.css': ('login.css', 'text/css; charset=utf-8'),
    '/login.js': ('login.js', 'application/javascript; charset=utf-8'),
}

ARCHIVOS_ESTATICOS = {
    '/': ('index.html', 'text/html; charset=utf-8'),
    '/index.html': ('index.html', 'text/html; charset=utf-8'),
    '/styles.css': ('styles.css', 'text/css; charset=utf-8'),
    '/registro.js': ('registro.js', 'application/javascript; charset=utf-8'),
    '/app.js': ('app.js', 'application/javascript; charset=utf-8'),
}


class ErrorValidacion(Exception):
    pass


class SinConexion(Exception):
    pass


def _json_default(o):
    if isinstance(o, datetime):
        return o.strftime('%Y-%m-%d %H:%M:%S')
    if isinstance(o, date):
        return o.isoformat()
    if isinstance(o, timedelta):          # TIME() de MySQL
        total = int(o.total_seconds())
        h, resto = divmod(total, 3600)
        m, s = divmod(resto, 60)
        return f'{h:02d}:{m:02d}:{s:02d}'
    if isinstance(o, Decimal):
        return int(o) if o == o.to_integral_value() else float(o)
    if isinstance(o, (bytes, bytearray)):
        return o.decode('utf-8', 'replace')
    return str(o)


@contextmanager
def base_datos():
    try:
        conn = conexion.conectar()
    except Error as exc:
        raise SinConexion('No se pudo conectar con la base del registro. Comprueba el estado de Docker Desktop y vuelve a abrir el programa.') from exc
    try:
        yield conn
    finally:
        conn.close()


def consultar(conn, sql, params=()):
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(sql, params)
        return cursor.fetchall()
    finally:
        cursor.close()


def llamar_listado(conn, procedimiento):
    """Ejecuta un procedimiento que devuelve filas (sp_listar_trabajadores)."""
    cursor = conn.cursor()
    try:
        cursor.callproc(procedimiento)
        filas = []
        for resultado in cursor.stored_results():
            columnas = resultado.column_names
            for fila in resultado.fetchall():
                filas.append(dict(zip(columnas, fila)))
        return filas
    finally:
        cursor.close()


def convertir(etiqueta, valor, tipo):
    """Valida y convierte un campo del formulario. Tipo terminado en ? = opcional."""
    opcional = tipo.endswith('?')
    base = tipo.rstrip('?')
    if valor is None or (isinstance(valor, str) and valor.strip() == ''):
        if opcional:
            return None
        raise ErrorValidacion(f'El campo "{etiqueta}" es obligatorio.')
    try:
        if base == 'int':
            return int(valor)
        if base == 'date':
            texto = str(valor)
            datetime.strptime(texto, '%Y-%m-%d')
            return texto
        if base == 'datetime':
            texto = str(valor).replace('T', ' ')
            if len(texto) == 16:
                texto += ':00'
            datetime.strptime(texto, '%Y-%m-%d %H:%M:%S')
            return texto
    except ValueError:
        raise ErrorValidacion(f'El campo "{etiqueta}" tiene un valor no válido.')
    if base == 'ip':
        try:
            return str(ipaddress.IPv4Address(valor))
        except ValueError:
            raise ErrorValidacion('Ingrese una dirección IPv4 válida.')
    return str(valor).strip()


def traducir_error(e, recurso=None, accion=None):
    """Convierte errores de MySQL en mensajes claros para el usuario."""
    errno = getattr(e, 'errno', None)
    if errno == 1451:
        extra = ' Cámbielo a estado Cesado en lugar de eliminarlo.' if recurso == 'trabajadores' else ''
        return 'No se puede eliminar: el registro tiene datos relacionados en otras tablas.' + extra
    if errno == 1452:
        return 'Alguno de los valores relacionados (cargo, trabajador, sede, documento) no existe.'
    if errno == 1062:
        return f'Ya existe un registro con ese valor único. ({e.msg})'
    if errno in (3819, 4025):
        return f'Algún dato no cumple las restricciones de la tabla. ({e.msg})'
    return e.msg or str(e)


# ---------------------------------------------------------------------
# Recursos CRUD: cada uno apunta a sus procedimientos almacenados
#   campos = (nombre, tipo, etiqueta) en el MISMO orden que los parametros del SP
# ---------------------------------------------------------------------
RECURSOS = {
    'trabajadores': {
        'pk': 'id_trabajador',
        'guardar': 'sp_guardar_trabajador',
        'eliminar': 'sp_eliminar_trabajador',
        'campos': [('id_trabajador', 'int?', 'ID'), ('nombres', 'str', 'Nombres'),
                   ('apellidos', 'str', 'Apellidos'), ('fecha_registro', 'date', 'Fecha de registro'),
                   ('estado', 'str', 'Estado'), ('id_cargo', 'int', 'Cargo'),
                   ('id_supervisor', 'int?', 'Supervisor'),
                   ('tipo_documento','str?','Tipo de documento'), ('identificacion','str?','Identificación'),
                   ('nacimiento','date?','Nacimiento'), ('genero','str?','Género'),
                   ('correo','str?','Correo'), ('telefono','str?','Teléfono'),
                   ('departamento','str?','Departamento'), ('contrato','str?','Contrato')],
        'listar': lambda conn: llamar_listado(conn, 'sp_listar_trabajadores'),
    },
    'cargos': {
        'pk': 'id_cargo',
        'guardar': 'sp_guardar_cargo',
        'eliminar': 'sp_eliminar_cargo',
        'campos': [('id_cargo', 'int?', 'ID'), ('nombre_cargo', 'str', 'Nombre del cargo'),
                   ('nivel_estructural', 'str', 'Nivel estructural'),
                   ('descripcion', 'str?', 'Descripción')],
        'listar': lambda conn: consultar(conn, 'SELECT * FROM cargo ORDER BY id_cargo'),
    },
    'documentos': {
        'pk': 'id_documento',
        'guardar': 'sp_guardar_documento',
        'eliminar': 'sp_eliminar_documento',
        'campos': [('id_documento', 'int?', 'ID'), ('codigo_normativo', 'str', 'Código normativo'),
                   ('titulo', 'str', 'Título'), ('version', 'str', 'Versión'),
                   ('fecha_aprobacion', 'date', 'Fecha de aprobación')],
        'listar': lambda conn: consultar(conn, 'SELECT * FROM documento_gestion ORDER BY id_documento'),
    },
    'sedes': {
        'pk': 'id_dispositivo',
        'guardar': 'sp_guardar_sede',
        'eliminar': 'sp_eliminar_sede',
        'campos': [('id_dispositivo', 'int?', 'ID'), ('nombre_sede', 'str', 'Nombre de la sede'),
                   ('direccion', 'str', 'Dirección'), ('codigo_ip', 'ip', 'Dirección IP'),
                   ('estado_dispositivo', 'str', 'Estado del dispositivo')],
        'listar': lambda conn: consultar(conn, 'SELECT * FROM sede_dispositivo ORDER BY id_dispositivo'),
    },
    'asistencia': {
        'pk': 'id_asistencia',
        'guardar': 'sp_guardar_asistencia',
        'eliminar': 'sp_eliminar_asistencia',
        'campos': [('id_asistencia', 'int?', 'ID'), ('fecha_hora_marcacion', 'datetime', 'Fecha y hora'),
                   ('tipo_marcacion', 'str', 'Tipo de marcación'),
                   ('estado_marcacion', 'str', 'Estado de marcación'),
                   ('id_trabajador', 'int', 'Trabajador'), ('id_dispositivo', 'int', 'Sede/dispositivo')],
        'listar': lambda conn: consultar(conn, """
            SELECT a.*, CONCAT(t.nombres, ' ', t.apellidos) AS trabajador, d.nombre_sede
            FROM asistencia a
            INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
            INNER JOIN sede_dispositivo d ON d.id_dispositivo = a.id_dispositivo
            ORDER BY a.fecha_hora_marcacion DESC, a.id_asistencia DESC"""),
    },
}


def decodificar_archivo(texto, limite, etiqueta):
    """Decodifica un adjunto acotado antes de comenzar la transacción."""
    if not texto:
        return None
    try:
        contenido = base64.b64decode(texto, validate=True)
    except (TypeError, ValueError, binascii.Error):
        raise ErrorValidacion(f'{etiqueta}: el contenido es inválido.')
    if not contenido or len(contenido) > limite:
        raise ErrorValidacion(f'{etiqueta}: el archivo excede el tamaño permitido o está vacío.')
    return contenido


def anexos_trabajador(datos):
    numero = str(datos.get('identificacion') or '').strip()
    tipo = datos.get('tipo_documento')
    if bool(tipo) != bool(numero) or (tipo == 'DNI' and not re.fullmatch(r'[0-9]{8}', numero)):
        raise ErrorValidacion('Complete el tipo y número de documento. El DNI requiere ocho dígitos.')
    if datos.get('nacimiento') and datos['nacimiento'] >= datos['fecha_registro']:
        raise ErrorValidacion('El nacimiento debe ser anterior al ingreso.')
    foto = decodificar_archivo(datos.get('foto'), 1024**2, 'Foto')
    if foto and not (foto.startswith(bytes.fromhex('89504E470D0A1A0A')) or foto.startswith(bytes.fromhex('FFD8FF'))):
        raise ErrorValidacion('La foto debe ser PNG o JPEG.')
    pdf = decodificar_archivo(datos.get('adjunto'), 3 * 1024**2, 'Documento')
    if pdf and not pdf.startswith(b'%PDF-'):
        raise ErrorValidacion('El documento debe ser PDF.')
    return [base64.b64encode(foto).decode('ascii') if foto else None,
            base64.b64encode(pdf).decode('ascii') if pdf else None, str(datos.get('nombre_adjunto') or 'Documento.pdf')[:150] if pdf else None]


def guardar_recurso(recurso, datos):
    spec = RECURSOS[recurso]
    valores = [convertir(etq, datos.get(nombre), tipo) for nombre, tipo, etq in spec['campos']]
    if recurso == "trabajadores":
        valores.extend(anexos_trabajador(datos))
    es_nuevo = valores[0] is None
    with base_datos() as conn:
        cursor = conn.cursor()
        try:
            if not es_nuevo:
                comprobar_fila(conn, recurso, valores[0])
            # FROM_BASE64 evita que la codificación de texto altere los octetos.
            parametros = ['%s'] * len(valores)
            if recurso == 'trabajadores':
                parametros[-3:-1] = ['FROM_BASE64(%s)', 'FROM_BASE64(%s)']
            marcadores = ','.join(parametros)
            cursor.execute(f"CALL {spec['guardar']}({marcadores})", valores)
            while cursor.nextset():
                pass
            conn.commit()
        except Error:
            conn.rollback()
            raise
        finally:
            cursor.close()
    return 'Registro creado correctamente.' if es_nuevo else 'Registro actualizado correctamente.'


TABLAS = {'trabajadores':'trabajador', 'cargos':'cargo', 'sedes':'sede_dispositivo',
          'asistencia':'asistencia', 'documentos':'documento_gestion', 'inducciones':'registro_induccion'}


def comprobar_fila(conn, recurso, identificador):
    """Bloquea el registro hasta el commit para distinguir una baja concurrente."""
    tabla = TABLAS[recurso]
    clave = 'id_induccion' if recurso == 'inducciones' else RECURSOS[recurso]['pk']
    if not consultar(conn, f'SELECT {clave} FROM {tabla} WHERE {clave}=%s FOR UPDATE', (identificador,)):
        raise ErrorValidacion('El registro ya no existe. Actualice la página.')


def eliminar_recurso(recurso, id_registro):
    spec = RECURSOS[recurso]
    with base_datos() as conn:
        cursor = conn.cursor()
        try:
            comprobar_fila(conn, recurso, id_registro)
            cursor.callproc(spec['eliminar'], (id_registro,))
            conn.commit()
        except Error:
            conn.rollback()
            raise
        finally:
            cursor.close()
    return 'Registro eliminado correctamente.'


# ---------------------------------------------------------------------
# Inducciones (maestro-detalle: registro_induccion + detalle_induccion)
# ---------------------------------------------------------------------
def listar_inducciones(conn):
    return consultar(conn, """
        SELECT r.id_induccion, r.id_trabajador, r.tipo_proceso, r.fecha_induccion,
               IFNULL(r.observaciones, '') AS observaciones,
               CONCAT(t.nombres, ' ', t.apellidos) AS trabajador,
               COUNT(di.id_detalle) AS total_docs,
               IFNULL(SUM(di.estado_cumplimiento = 'Pendiente'), 0) AS pendientes
        FROM registro_induccion r
        INNER JOIN trabajador t ON t.id_trabajador = r.id_trabajador
        LEFT JOIN detalle_induccion di ON di.id_induccion = r.id_induccion
        GROUP BY r.id_induccion, r.id_trabajador, r.tipo_proceso, r.fecha_induccion,
                 r.observaciones, t.nombres, t.apellidos
        ORDER BY r.id_induccion DESC""")


def obtener_induccion(conn, id_induccion):
    cab = consultar(conn, 'SELECT * FROM registro_induccion WHERE id_induccion = %s', (id_induccion,))
    if not cab:
        raise ErrorValidacion('La inducción no existe.')
    det = consultar(conn, """SELECT id_detalle, id_documento, estado_cumplimiento,
                                    IFNULL(firma_responsable, '') AS firma_responsable
                             FROM detalle_induccion WHERE id_induccion = %s ORDER BY id_detalle""",
                    (id_induccion,))
    return {'cabecera': cab[0], 'detalles': det}


def guardar_induccion(datos):
    id_induccion = convertir('ID', datos.get('id_induccion'), 'int?')
    id_trabajador = convertir('Trabajador', datos.get('id_trabajador'), 'int')
    tipo = convertir('Tipo de proceso', datos.get('tipo_proceso'), 'str')
    fecha = convertir('Fecha de inducción', datos.get('fecha_induccion'), 'date')
    firma = convertir('Firma del trabajador', datos.get('firma_trabajador'), 'str')
    obs = convertir('Observaciones', datos.get('observaciones'), 'str?')

    detalles = datos.get('detalles') or []
    if not detalles:
        raise ErrorValidacion('Agregue al menos un documento revisado en la inducción.')
    filas = []
    for i, d in enumerate(detalles, start=1):
        filas.append((
            i,
            convertir(f'Documento (fila {i})', d.get('id_documento'), 'int'),
            convertir(f'Estado (fila {i})', d.get('estado_cumplimiento'), 'str'),
            convertir(f'Firma responsable (fila {i})', d.get('firma_responsable'), 'str?'),
        ))

    with base_datos() as conn:
        cursor = conn.cursor()
        try:
            if id_induccion is None:
                args = cursor.callproc('sp_insertar_induccion_cabecera',
                                       (tipo, obs, fecha, firma, id_trabajador, 0))
                id_final = args[5]
            else:
                comprobar_fila(conn, 'inducciones', id_induccion)
                cursor.callproc('sp_actualizar_induccion',
                                (id_induccion, tipo, obs, fecha, firma, id_trabajador))
                cursor.callproc('sp_eliminar_detalles_induccion', (id_induccion,))
                id_final = id_induccion
            for id_det, id_doc, estado, f_resp in filas:
                cursor.callproc('sp_insertar_induccion_detalle',
                                (id_final, id_det, id_doc, estado, f_resp))
            conn.commit()      # todo o nada: cabecera + detalle en una transaccion
        except Error:
            conn.rollback()
            raise
        finally:
            cursor.close()
    verbo = 'creada' if id_induccion is None else 'actualizada'
    return f'Inducción #{id_final} {verbo} con {len(filas)} documento(s).'


# ---------------------------------------------------------------------
# Servidor HTTP
# ---------------------------------------------------------------------
class Manejador(BaseHTTPRequestHandler):
    server_version = 'RegistroTrabajadores/1.1'

    def end_headers(self):
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

    def log_message(self, formato, *args):       # consola limpia
        pass

    # --- respuestas ---
    def _json(self, codigo, datos, cookie=None):
        cuerpo = json.dumps(datos, default=_json_default, ensure_ascii=False).encode('utf-8')
        self.send_response(codigo)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(cuerpo)))
        self.send_header('Cache-Control', 'no-store')
        if cookie:
            self.send_header('Set-Cookie', cookie)
        self.end_headers()
        self.wfile.write(cuerpo)

    def _archivo(self, nombre, tipo):
        ruta = os.path.join(carpeta_recursos(), nombre)
        try:
            with open(ruta, 'rb') as f:
                cuerpo = f.read()
        except OSError:
            self._json(404, {'error': f'No se encontró {nombre}.'})
            return
        self.send_response(200)
        self.send_header('Content-Type', tipo)
        self.send_header('Content-Length', str(len(cuerpo)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(cuerpo)

    def _error(self, e, recurso=None):
        if isinstance(e, ErrorValidacion):
            self._json(400, {'error': str(e)})
        elif isinstance(e, SinConexion):
            self._json(503, {'error': str(e)})
        elif isinstance(e, Error):
            self._json(409, {'error': traducir_error(e, recurso)})
        else:
            print('Error interno:', repr(e))
            self._json(500, {'error': 'Ocurrió un error interno. Revisa el estado del aplicativo.'})

    def _leer_json(self, limite=6_000_000):
        largo = int(self.headers.get('Content-Length') or 0)
        if largo < 0 or largo > limite:
            raise ErrorValidacion('La solicitud es demasiado grande.')
        try:
            datos = json.loads(self.rfile.read(largo) or b'{}')
        except ValueError:
            raise ErrorValidacion('El cuerpo de la solicitud no es JSON válido.')
        if not isinstance(datos, dict):
            raise ErrorValidacion('El cuerpo de la solicitud no es válido.')
        return datos

    def _token(self):
        return sesiones.leer_cookie(self.headers.get('Cookie'))

    def _redirigir(self, destino):
        self.send_response(303)
        self.send_header('Location', destino)
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _acceso_local(self, escritura=False):
        host = self.headers.get('Host', '')
        origen = self.headers.get('Origin')
        if re.fullmatch(r'(?:localhost|127\.0\.0\.1)(?::[0-9]+)?', host) and (
            not escritura or not origen or origen == f'http://{host}'
        ):
            return True
        self._json(403, {'error': 'Abre el aplicativo desde su dirección local.'})
        return False

    def _requiere_sesion(self):
        if sesiones.valida(self._token()):
            return True
        self._json(401, {'error': 'Inicia sesión para continuar.'})
        return False

    def _iniciar_sesion(self):
        datos = self._leer_json(limite=4096)
        codigo, token = sesiones.iniciar(datos.get('usuario'), datos.get('clave'))
        if token:
            sesiones.cerrar(self._token())
            self._json(200, {'mensaje': 'Acceso autorizado.'}, cookie=sesiones.cookie(token))
            return
        errores = {
            400: 'Completa el usuario y la contraseña.',
            401: 'Usuario o contraseña incorrectos.',
            429: 'Demasiados intentos. Espera 30 segundos y vuelve a intentar.',
        }
        self._json(codigo, {'error': errores[codigo]})

    # --- rutas ---
    def do_GET(self):
        url = urlparse(self.path)
        ruta = url.path
        if not self._acceso_local():
            return
        if ruta in ARCHIVOS_ACCESO:
            if ruta == '/login' and sesiones.valida(self._token()):
                self._redirigir('/')
            else:
                self._archivo(*ARCHIVOS_ACCESO[ruta])
            return
        if ruta in ARCHIVOS_ESTATICOS:
            if ruta in ('/', '/index.html') and not sesiones.valida(self._token()):
                self._redirigir('/login')
            else:
                self._archivo(*ARCHIVOS_ESTATICOS[ruta])
            return
        recurso = None
        try:
            if ruta == '/api/estado':
                with base_datos() as conn:
                    consultar(conn, 'SELECT nombre_adjunto FROM trabajador LIMIT 0')
                    consultar(conn, 'SELECT id_auditoria FROM auditoria LIMIT 0')
                    llamar_listado(conn, 'sp_listar_trabajadores')
                self._json(200, {'listo': True})
                return
            if not self._requiere_sesion():
                return
            archivo = re.fullmatch(r'/api/trabajadores/(\d+)/(foto|adjunto)', ruta)
            if archivo:
                campo = archivo.group(2)
                with base_datos() as conn:
                    filas = consultar(conn, f'SELECT {campo} AS contenido, nombre_adjunto FROM trabajador WHERE id_trabajador=%s', (int(archivo.group(1)),))
                if not filas or not filas[0]['contenido']:
                    self._json(404, {'error': 'Archivo no encontrado.'})
                    return
                cuerpo = bytes(filas[0]['contenido'])
                self.send_response(200)
                if campo == 'adjunto':
                    self.send_header('Content-Type', 'application/pdf')
                    self.send_header('Content-Disposition', "attachment; filename*=UTF-8''" + quote(filas[0]['nombre_adjunto'] or 'documento.pdf', safe=''))
                else:
                    self.send_header('Content-Type', 'image/png' if cuerpo.startswith(b'\x89PNG') else 'image/jpeg')
                self.send_header('Content-Length', str(len(cuerpo)))
                self.send_header('Cache-Control','no-store')
                self.end_headers()
                self.wfile.write(cuerpo)
                return
            if ruta == '/api/reportes':
                self._json(200, catalogo())
                return
            m = re.fullmatch(r'/api/reportes/(c\d+)', ruta)
            if m:
                fecha = parse_qs(url.query).get('fecha', [date.today().isoformat()])[0]
                with base_datos() as conn:
                    self._json(200, ejecutar_reporte(conn, m.group(1), fecha))
                return
            m = re.fullmatch(r'/api/inducciones(?:/(\d+))?', ruta)
            if m:
                with base_datos() as conn:
                    if m.group(1):
                        self._json(200, obtener_induccion(conn, int(m.group(1))))
                    else:
                        self._json(200, listar_inducciones(conn))
                return
            m = re.fullmatch(r'/api/(\w+)', ruta)
            if m and m.group(1) in RECURSOS:
                recurso = m.group(1)
                with base_datos() as conn:
                    self._json(200, RECURSOS[recurso]['listar'](conn))
                return
            self._json(404, {'error': 'Ruta no encontrada.'})
        except KeyError:
            self._json(404, {'error': 'Reporte no encontrado.'})
        except ValueError as e:
            self._json(400, {'error': str(e)})
        except Exception as e:
            self._error(e, recurso)

    def do_POST(self):
        ruta = urlparse(self.path).path
        recurso = None
        if not self._acceso_local(escritura=True):
            return
        if ruta != '/api/login' and not self._requiere_sesion():
            return
        if self.headers.get_content_type() != 'application/json':
            self._json(415, {'error': 'Se requiere contenido JSON.'})
            return
        try:
            if ruta == '/api/login':
                self._iniciar_sesion()
                return
            if ruta == '/api/logout':
                sesiones.cerrar(self._token())
                self._json(200, {'mensaje': 'Sesión cerrada.'}, cookie=sesiones.cookie())
                return
            datos = self._leer_json()
            if ruta == '/api/inducciones':
                self._json(200, {'mensaje': guardar_induccion(datos)})
                return
            m = re.fullmatch(r'/api/(\w+)', ruta)
            if m and m.group(1) in RECURSOS:
                recurso = m.group(1)
                self._json(200, {'mensaje': guardar_recurso(recurso, datos)})
                return
            self._json(404, {'error': 'Ruta no encontrada.'})
        except Exception as e:
            self._error(e, recurso)

    def do_DELETE(self):
        if not self._acceso_local(escritura=True) or not self._requiere_sesion():
            return
        ruta = urlparse(self.path).path
        recurso = None
        try:
            m = re.fullmatch(r'/api/(\w+)/(\d+)', ruta)
            if m and m.group(1) == 'inducciones':
                with base_datos() as conn:
                    cursor = conn.cursor()
                    try:
                        comprobar_fila(conn, 'inducciones', int(m.group(2)))
                        cursor.callproc('sp_eliminar_induccion', (int(m.group(2)),))
                        conn.commit()
                    except Error:
                        conn.rollback()
                        raise
                    finally:
                        cursor.close()
                self._json(200, {'mensaje': 'Inducción eliminada con su detalle.'})
                return
            if m and m.group(1) in RECURSOS:
                recurso = m.group(1)
                self._json(200, {'mensaje': eliminar_recurso(recurso, int(m.group(2)))})
                return
            self._json(404, {'error': 'Ruta no encontrada.'})
        except Exception as e:
            self._error(e, recurso)


def main():
    with ThreadingHTTPServer(('0.0.0.0', 8000), Manejador) as servidor:
        servidor.serve_forever()


if __name__ == '__main__':
    main()
