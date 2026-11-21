-- =====================================================================
-- Entrega 4: Consultas del proyecto (MySQL 8.0)
-- =====================================================================
USE registro_trabajadores;

-- C1. Listado de trabajadores con su cargo y su supervisor (autojoin)
SELECT t.id_trabajador,
       CONCAT(t.nombres, ' ', t.apellidos)  AS trabajador,
       c.nombre_cargo                       AS cargo,
       t.estado,
       CONCAT(s.nombres, ' ', s.apellidos)  AS supervisor
FROM trabajador t
INNER JOIN cargo c ON c.id_cargo = t.id_cargo
LEFT  JOIN trabajador s ON s.id_trabajador = t.id_supervisor
ORDER BY t.id_trabajador;

-- C2. Cantidad de trabajadores activos por cargo
SELECT c.nombre_cargo AS cargo,
       COUNT(t.id_trabajador) AS total_activos
FROM cargo c
LEFT JOIN trabajador t ON t.id_cargo = c.id_cargo AND t.estado = 'Activo'
GROUP BY c.id_cargo, c.nombre_cargo
ORDER BY total_activos DESC, c.nombre_cargo;

-- C3. Marcaciones de un dia con la sede o dispositivo donde se registraron
SELECT DATE(a.fecha_hora_marcacion)          AS fecha,
       TIME(a.fecha_hora_marcacion)          AS hora,
       CONCAT(t.nombres, ' ', t.apellidos)   AS trabajador,
       a.tipo_marcacion,
       a.estado_marcacion,
       d.nombre_sede
FROM asistencia a
INNER JOIN trabajador t       ON t.id_trabajador = a.id_trabajador
INNER JOIN sede_dispositivo d ON d.id_dispositivo = a.id_dispositivo
WHERE DATE(a.fecha_hora_marcacion) = '2026-10-19'
ORDER BY a.fecha_hora_marcacion;

-- C4. Trabajadores con 2 o mas tardanzas en octubre de 2026
SELECT t.id_trabajador,
       CONCAT(t.nombres, ' ', t.apellidos) AS trabajador,
       COUNT(*) AS total_tardanzas
FROM asistencia a
INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
WHERE a.estado_marcacion = 'Tardanza'
  AND a.fecha_hora_marcacion >= '2026-10-01'
  AND a.fecha_hora_marcacion <  '2026-11-01'
GROUP BY t.id_trabajador, t.nombres, t.apellidos
HAVING COUNT(*) >= 2
ORDER BY total_tardanzas DESC, trabajador;

-- C5. Horas trabajadas por trabajador y dia (primera entrada y ultima salida)
SELECT CONCAT(t.nombres, ' ', t.apellidos) AS trabajador,
       DATE(a.fecha_hora_marcacion)        AS fecha,
       MIN(CASE WHEN a.tipo_marcacion = 'Entrada'
                THEN a.fecha_hora_marcacion END) AS entrada,
       MAX(CASE WHEN a.tipo_marcacion = 'Salida'
                THEN a.fecha_hora_marcacion END) AS salida,
       ROUND(TIMESTAMPDIFF(MINUTE,
             MIN(CASE WHEN a.tipo_marcacion = 'Entrada'
                      THEN a.fecha_hora_marcacion END),
             MAX(CASE WHEN a.tipo_marcacion = 'Salida'
                      THEN a.fecha_hora_marcacion END)) / 60, 2) AS horas_trabajadas
FROM asistencia a
INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
WHERE DATE(a.fecha_hora_marcacion) = '2026-10-20'
GROUP BY t.id_trabajador, t.nombres, t.apellidos, DATE(a.fecha_hora_marcacion)
ORDER BY horas_trabajadas DESC;

-- C6. Total de marcaciones por sede o dispositivo
SELECT d.nombre_sede, d.codigo_ip, d.estado_dispositivo,
       COUNT(a.id_asistencia) AS total_marcaciones
FROM sede_dispositivo d
LEFT JOIN asistencia a ON a.id_dispositivo = d.id_dispositivo
GROUP BY d.id_dispositivo, d.nombre_sede, d.codigo_ip, d.estado_dispositivo
ORDER BY total_marcaciones DESC;

-- C7. Inducciones por trabajador con documentos cumplidos y pendientes
SELECT CONCAT(t.nombres, ' ', t.apellidos) AS trabajador,
       r.tipo_proceso,
       r.fecha_induccion,
       SUM(di.estado_cumplimiento = 'Cumplido')  AS cumplidos,
       SUM(di.estado_cumplimiento = 'Pendiente') AS pendientes
FROM registro_induccion r
INNER JOIN trabajador t         ON t.id_trabajador = r.id_trabajador
INNER JOIN detalle_induccion di ON di.id_induccion = r.id_induccion
GROUP BY r.id_induccion, t.nombres, t.apellidos, r.tipo_proceso, r.fecha_induccion
HAVING SUM(di.estado_cumplimiento = 'Pendiente') > 0
ORDER BY r.fecha_induccion;

-- C8. Porcentaje de cumplimiento de cada documento de gestion
SELECT g.codigo_normativo,
       g.titulo,
       COUNT(di.id_detalle) AS veces_revisado,
       ROUND(100 * SUM(di.estado_cumplimiento = 'Cumplido')
             / COUNT(di.id_detalle), 1) AS porcentaje_cumplimiento
FROM documento_gestion g
INNER JOIN detalle_induccion di ON di.id_documento = g.id_documento
GROUP BY g.id_documento, g.codigo_normativo, g.titulo
ORDER BY porcentaje_cumplimiento ASC, g.codigo_normativo;

-- C9. Trabajadores activos sin inducciones registradas
SELECT t.id_trabajador,
       CONCAT(t.nombres, ' ', t.apellidos) AS trabajador,
       c.nombre_cargo
FROM trabajador t
INNER JOIN cargo c ON c.id_cargo = t.id_cargo
WHERE t.estado = 'Activo'
  AND NOT EXISTS (SELECT 1 FROM registro_induccion r
                  WHERE r.id_trabajador = t.id_trabajador);

-- C10. Trabajadores activos sin ninguna marcacion el 20/10/2026 (ausentes)
SELECT t.id_trabajador,
       CONCAT(t.nombres, ' ', t.apellidos) AS trabajador,
       c.nombre_cargo
FROM trabajador t
INNER JOIN cargo c ON c.id_cargo = t.id_cargo
WHERE t.estado = 'Activo'
  AND NOT EXISTS (SELECT 1 FROM asistencia a
                  WHERE a.id_trabajador = t.id_trabajador
                    AND DATE(a.fecha_hora_marcacion) = '2026-10-20')
ORDER BY t.id_trabajador;

-- C11. Supervisores y cantidad de trabajadores a su cargo (autojoin)
SELECT CONCAT(s.nombres, ' ', s.apellidos) AS supervisor,
       c.nombre_cargo                       AS cargo_supervisor,
       COUNT(t.id_trabajador)               AS trabajadores_a_cargo
FROM trabajador s
INNER JOIN cargo c      ON c.id_cargo = s.id_cargo
INNER JOIN trabajador t ON t.id_supervisor = s.id_trabajador
GROUP BY s.id_trabajador, s.nombres, s.apellidos, c.nombre_cargo
ORDER BY trabajadores_a_cargo DESC, supervisor;

-- C12. Bitacora de auditoria generada por los triggers (05_triggers.sql)
SELECT id_auditoria, fecha_hora, tabla, operacion, id_registro, detalle, usuario_bd
FROM auditoria
ORDER BY id_auditoria DESC
LIMIT 100;
