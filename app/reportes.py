"""Catalogo de reportes (consultas de 03_consultas.sql + 2 adicionales).

Reportes con JOIN: C1 a C11  (11 de 12).  C12 (auditoria) lee la tabla que llenan los triggers.
"""
from datetime import datetime

REPORTES = {
    'c1': {
        'nombre': 'C1. Listado de trabajadores con cargo y supervisor (autojoin)',
        'usa_fecha': 0,
        'sql': """SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         c.nombre_cargo AS Cargo,
                         t.estado AS Estado,
                         IFNULL(CONCAT(s.nombres, ' ', s.apellidos), 'Sin supervisor') AS Supervisor
                  FROM trabajador t
                  INNER JOIN cargo c ON c.id_cargo = t.id_cargo
                  LEFT JOIN trabajador s ON s.id_trabajador = t.id_supervisor
                  ORDER BY t.id_trabajador""",
    },
    'c2': {
        'nombre': 'C2. Cantidad de trabajadores activos por cargo',
        'usa_fecha': 0,
        'sql': """SELECT c.nombre_cargo AS Cargo,
                         COUNT(t.id_trabajador) AS Total_Activos
                  FROM cargo c
                  LEFT JOIN trabajador t ON t.id_cargo = c.id_cargo AND t.estado = 'Activo'
                  GROUP BY c.id_cargo, c.nombre_cargo
                  ORDER BY Total_Activos DESC, c.nombre_cargo""",
    },
    'c3': {
        'nombre': 'C3. Marcaciones del día {fecha} con su sede/dispositivo',
        'usa_fecha': 1,
        'sql': """SELECT DATE(a.fecha_hora_marcacion) AS Fecha,
                         TIME(a.fecha_hora_marcacion) AS Hora,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         a.tipo_marcacion AS Tipo,
                         a.estado_marcacion AS Estado,
                         d.nombre_sede AS Sede
                  FROM asistencia a
                  INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
                  INNER JOIN sede_dispositivo d ON d.id_dispositivo = a.id_dispositivo
                  WHERE DATE(a.fecha_hora_marcacion) = %s
                  ORDER BY a.fecha_hora_marcacion""",
    },
    'c4': {
        'nombre': 'C4. Trabajadores con 2 o más tardanzas en el mes de {fecha}',
        'usa_fecha': 2,
        'sql': """SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         COUNT(*) AS Total_Tardanzas
                  FROM asistencia a
                  INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
                  WHERE a.estado_marcacion = 'Tardanza'
                    AND a.fecha_hora_marcacion >= DATE_FORMAT(%s, '%Y-%m-01')
                    AND a.fecha_hora_marcacion <  DATE_ADD(DATE_FORMAT(%s, '%Y-%m-01'), INTERVAL 1 MONTH)
                  GROUP BY t.id_trabajador, t.nombres, t.apellidos
                  HAVING COUNT(*) >= 2
                  ORDER BY Total_Tardanzas DESC, Trabajador""",
    },
    'c5': {
        'nombre': 'C5. Horas trabajadas por trabajador el día {fecha}',
        'usa_fecha': 1,
        'sql': """SELECT CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         DATE(a.fecha_hora_marcacion) AS Fecha,
                         MIN(CASE WHEN a.tipo_marcacion = 'Entrada' THEN a.fecha_hora_marcacion END) AS Entrada,
                         MAX(CASE WHEN a.tipo_marcacion = 'Salida' THEN a.fecha_hora_marcacion END) AS Salida,
                         ROUND(TIMESTAMPDIFF(MINUTE,
                               MIN(CASE WHEN a.tipo_marcacion = 'Entrada' THEN a.fecha_hora_marcacion END),
                               MAX(CASE WHEN a.tipo_marcacion = 'Salida' THEN a.fecha_hora_marcacion END)) / 60, 2) AS Horas_Trabajadas
                  FROM asistencia a
                  INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
                  WHERE DATE(a.fecha_hora_marcacion) = %s
                  GROUP BY t.id_trabajador, t.nombres, t.apellidos, DATE(a.fecha_hora_marcacion)
                  ORDER BY Horas_Trabajadas DESC""",
    },
    'c6': {
        'nombre': 'C6. Total de marcaciones por sede o dispositivo',
        'usa_fecha': 0,
        'sql': """SELECT d.nombre_sede AS Sede,
                         d.codigo_ip AS IP,
                         d.estado_dispositivo AS Estado,
                         COUNT(a.id_asistencia) AS Total_Marcaciones
                  FROM sede_dispositivo d
                  LEFT JOIN asistencia a ON a.id_dispositivo = d.id_dispositivo
                  GROUP BY d.id_dispositivo, d.nombre_sede, d.codigo_ip, d.estado_dispositivo
                  ORDER BY Total_Marcaciones DESC""",
    },
    'c7': {
        'nombre': 'C7. Inducciones con documentos pendientes',
        'usa_fecha': 0,
        'sql': """SELECT CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         r.tipo_proceso AS Tipo_Proceso,
                         r.fecha_induccion AS Fecha_Induccion,
                         SUM(di.estado_cumplimiento = 'Cumplido') AS Cumplidos,
                         SUM(di.estado_cumplimiento = 'Pendiente') AS Pendientes
                  FROM registro_induccion r
                  INNER JOIN trabajador t ON t.id_trabajador = r.id_trabajador
                  INNER JOIN detalle_induccion di ON di.id_induccion = r.id_induccion
                  GROUP BY r.id_induccion, t.nombres, t.apellidos, r.tipo_proceso, r.fecha_induccion
                  HAVING SUM(di.estado_cumplimiento = 'Pendiente') > 0
                  ORDER BY r.fecha_induccion""",
    },
    'c8': {
        'nombre': 'C8. Porcentaje de cumplimiento por documento de gestión',
        'usa_fecha': 0,
        'sql': """SELECT g.codigo_normativo AS Codigo,
                         g.titulo AS Documento,
                         COUNT(di.id_detalle) AS Veces_Revisado,
                         ROUND(100 * SUM(di.estado_cumplimiento = 'Cumplido') / COUNT(di.id_detalle), 1) AS Porcentaje_Cumplimiento
                  FROM documento_gestion g
                  INNER JOIN detalle_induccion di ON di.id_documento = g.id_documento
                  GROUP BY g.id_documento, g.codigo_normativo, g.titulo
                  ORDER BY Porcentaje_Cumplimiento ASC, g.codigo_normativo""",
    },
    'c9': {
        'nombre': 'C9. Trabajadores activos sin inducciones registradas',
        'usa_fecha': 0,
        'sql': """SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         c.nombre_cargo AS Cargo
                  FROM trabajador t
                  INNER JOIN cargo c ON c.id_cargo = t.id_cargo
                  WHERE t.estado = 'Activo'
                    AND NOT EXISTS (SELECT 1 FROM registro_induccion r WHERE r.id_trabajador = t.id_trabajador)
                  ORDER BY t.id_trabajador""",
    },
    'c10': {
        'nombre': 'C10. Trabajadores activos ausentes el día {fecha} (sin marcaciones)',
        'usa_fecha': 1,
        'sql': """SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         c.nombre_cargo AS Cargo
                  FROM trabajador t
                  INNER JOIN cargo c ON c.id_cargo = t.id_cargo
                  WHERE t.estado = 'Activo'
                    AND NOT EXISTS (SELECT 1 FROM asistencia a
                                    WHERE a.id_trabajador = t.id_trabajador
                                      AND DATE(a.fecha_hora_marcacion) = %s)
                  ORDER BY t.id_trabajador""",
    },
    'c11': {
        'nombre': 'C11. Supervisores y cantidad de trabajadores a su cargo (autojoin)',
        'usa_fecha': 0,
        'sql': """SELECT CONCAT(s.nombres, ' ', s.apellidos) AS Supervisor,
                         c.nombre_cargo AS Cargo_Supervisor,
                         COUNT(t.id_trabajador) AS Trabajadores_A_Cargo
                  FROM trabajador s
                  INNER JOIN cargo c ON c.id_cargo = s.id_cargo
                  INNER JOIN trabajador t ON t.id_supervisor = s.id_trabajador
                  GROUP BY s.id_trabajador, s.nombres, s.apellidos, c.nombre_cargo
                  ORDER BY Trabajadores_A_Cargo DESC, Supervisor""",
    },
    'c12': {
        'nombre': 'C12. Bitácora de auditoría generada por los triggers (últimos 100 movimientos)',
        'usa_fecha': 0,
        'sql': """SELECT id_auditoria AS ID,
                         fecha_hora AS Fecha_Hora,
                         tabla AS Tabla,
                         operacion AS Operacion,
                         id_registro AS Registro,
                         detalle AS Detalle,
                         usuario_bd AS Usuario
                  FROM auditoria
                  ORDER BY id_auditoria DESC
                  LIMIT 100""",
    },
}


def catalogo():
    lista = []
    for codigo, r in REPORTES.items():
        lista.append({
            'codigo': codigo,
            'nombre': r['nombre'].replace('{fecha}', 'seleccionado'),
            'usa_fecha': r['usa_fecha'] > 0,
            'con_join': ' JOIN ' in r['sql'],
        })
    return lista


def ejecutar_reporte(conexion, codigo, fecha):
    """Ejecuta un reporte y devuelve {titulo, columnas, filas}."""
    if codigo not in REPORTES:
        raise KeyError(codigo)
    r = REPORTES[codigo]
    try:
        datetime.strptime(fecha, '%Y-%m-%d')
    except (TypeError, ValueError):
        raise ValueError('La fecha del filtro debe tener el formato AAAA-MM-DD.')

    cursor = conexion.cursor(dictionary=True)
    try:
        cursor.execute(r['sql'], (fecha,) * r['usa_fecha'])
        filas = cursor.fetchall()
        columnas = [d[0] for d in cursor.description]
    finally:
        cursor.close()
    return {
        'titulo': r['nombre'].format(fecha=fecha),
        'columnas': columnas,
        'filas': filas,
    }
