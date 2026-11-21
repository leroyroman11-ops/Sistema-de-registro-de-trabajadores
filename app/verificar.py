"""Prueba de integración para la instalación local. Todos los cambios se revierten."""
from uuid import uuid4
from mysql.connector import Error
from conexion import conectar
from reportes import REPORTES, ejecutar_reporte

def verificar():
    conn = conectar()
    cur = conn.cursor()
    nombre = 'Verificación ' + uuid4().hex
    try:
        # El catálogo temporal permite probar sin depender de datos personales existentes.
        cur.callproc('sp_guardar_cargo', (None, nombre, 'Operativo', None))
        cur.execute('SELECT id_cargo FROM cargo WHERE nombre_cargo=%s', (nombre,))
        cargo = cur.fetchone()[0]
        trabajador = [None, nombre, 'Prueba', '2025-01-01', 'Activo', cargo, None] + [None] * 11
        cur.callproc('sp_guardar_trabajador', trabajador)
        cur.execute('SELECT id_trabajador FROM trabajador WHERE nombres=%s', (nombre,))
        trabajador[0] = cur.fetchone()[0]
        trabajador[2] = 'Actualizado'
        cur.callproc('sp_guardar_trabajador', trabajador)
        cur.execute('SELECT apellidos FROM trabajador WHERE id_trabajador=%s', (trabajador[0],))
        assert cur.fetchone()[0] == 'Actualizado', 'Error de actualización'
        try:
            cur.callproc('sp_guardar_trabajador', [*trabajador[:6], trabajador[0], *trabajador[7:]])
        except Error as exc:
            if exc.sqlstate != '45000':
                raise
        else:
            raise AssertionError('El trigger permitió la autosupervisión')
        cur.callproc('sp_eliminar_trabajador', (trabajador[0],))
        cur.execute('SELECT COUNT(*) FROM trabajador WHERE id_trabajador=%s', (trabajador[0],))
        assert cur.fetchone()[0] == 0, 'Error de eliminación'
        cur.execute("SELECT COUNT(DISTINCT operacion) FROM auditoria WHERE tabla='trabajador' AND id_registro=%s", (str(trabajador[0]),))
        assert cur.fetchone()[0] == 3, 'Auditoría incompleta'
        for codigo in REPORTES:
            resultado = ejecutar_reporte(conn, codigo, '2026-10-19')
            print(codigo.upper(), len(resultado['filas']), 'filas')
        print('Correcto: alta, cambio, baja, validación, auditoría y 12 reportes.')
    finally:
        conn.rollback()
        cur.close()
        conn.close()

if __name__ == '__main__':
    verificar()
