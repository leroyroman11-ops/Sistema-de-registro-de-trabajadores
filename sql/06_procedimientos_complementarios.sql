-- =====================================================================
-- Entrega 4: Procedimientos complementarios a 04_procedimientos.sql
-- (completan el CRUD maestro-detalle de INDUCCION: modificar y rehacer detalle)
-- =====================================================================
USE registro_trabajadores;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_actualizar_induccion //
CREATE PROCEDURE sp_actualizar_induccion(
    IN p_id_induccion INT,
    IN p_tipo_proceso VARCHAR(50),
    IN p_observaciones VARCHAR(255),
    IN p_fecha_induccion DATE,
    IN p_firma_trabajador VARCHAR(255),
    IN p_id_trabajador INT
)
BEGIN
    UPDATE registro_induccion
    SET tipo_proceso     = p_tipo_proceso,
        observaciones    = p_observaciones,
        fecha_induccion  = p_fecha_induccion,
        firma_trabajador = p_firma_trabajador,
        id_trabajador    = p_id_trabajador
    WHERE id_induccion = p_id_induccion;
END //

DROP PROCEDURE IF EXISTS sp_eliminar_detalles_induccion //
CREATE PROCEDURE sp_eliminar_detalles_induccion(IN p_id_induccion INT)
BEGIN
    DELETE FROM detalle_induccion WHERE id_induccion = p_id_induccion;
END //

DELIMITER ;
