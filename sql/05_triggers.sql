-- =====================================================================
-- Entrega 4: Triggers del proyecto (MySQL 8.0.16 o posterior)
-- Ejecutar DESPUES de 01_crear_bd.sql y 02_insertar_datos.sql
--
-- Contenido:
--   1. Tabla AUDITORIA (bitacora alimentada solo por triggers)
--   2. Triggers BEFORE  -> validacion y normalizacion de datos
--   3. Triggers AFTER   -> auditoria de INSERT / UPDATE / DELETE (7 tablas)
--
-- Nota: los DELETE en cascada de InnoDB no disparan triggers; por eso
-- trg_registro_induccion_bd borra el detalle de forma explicita.
-- =====================================================================
USE registro_trabajadores;

CREATE TABLE IF NOT EXISTS auditoria (
    id_auditoria  INT          NOT NULL AUTO_INCREMENT,
    tabla         VARCHAR(50)  NOT NULL,
    operacion     VARCHAR(10)  NOT NULL,
    id_registro   VARCHAR(50)  NOT NULL,
    detalle       TEXT         NULL,
    usuario_bd    VARCHAR(100) NOT NULL,
    fecha_hora    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_auditoria PRIMARY KEY (id_auditoria),
    INDEX idx_auditoria_tabla (tabla, fecha_hora)
) ENGINE = InnoDB;

DELIMITER //

-- =====================================================================
-- 2. TRIGGERS BEFORE (validaciones y normalizacion)
-- =====================================================================

-- TRABAJADOR ----------------------------------------------------------
DROP TRIGGER IF EXISTS trg_trabajador_bi //
CREATE TRIGGER trg_trabajador_bi BEFORE INSERT ON trabajador
FOR EACH ROW
BEGIN
    SET NEW.nombres   = TRIM(NEW.nombres);
    SET NEW.apellidos = TRIM(NEW.apellidos);
    IF NEW.nombres = '' OR NEW.apellidos = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los nombres y apellidos del trabajador no pueden estar vacios.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_trabajador_bu //
CREATE TRIGGER trg_trabajador_bu BEFORE UPDATE ON trabajador
FOR EACH ROW
BEGIN
    SET NEW.nombres   = TRIM(NEW.nombres);
    SET NEW.apellidos = TRIM(NEW.apellidos);
    IF NEW.nombres = '' OR NEW.apellidos = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Los nombres y apellidos del trabajador no pueden estar vacios.';
    END IF;
    IF NEW.id_supervisor IS NOT NULL AND NEW.id_supervisor = NEW.id_trabajador THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un trabajador no puede ser su propio supervisor.';
    END IF;
END //

-- CARGO ---------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_cargo_bi //
CREATE TRIGGER trg_cargo_bi BEFORE INSERT ON cargo
FOR EACH ROW
BEGIN
    SET NEW.nombre_cargo = TRIM(NEW.nombre_cargo);
    IF NEW.nombre_cargo = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El nombre del cargo no puede estar vacio.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_cargo_bu //
CREATE TRIGGER trg_cargo_bu BEFORE UPDATE ON cargo
FOR EACH ROW
BEGIN
    SET NEW.nombre_cargo = TRIM(NEW.nombre_cargo);
    IF NEW.nombre_cargo = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El nombre del cargo no puede estar vacio.';
    END IF;
END //

-- DOCUMENTO_GESTION ---------------------------------------------------
DROP TRIGGER IF EXISTS trg_documento_gestion_bi //
CREATE TRIGGER trg_documento_gestion_bi BEFORE INSERT ON documento_gestion
FOR EACH ROW
BEGIN
    SET NEW.codigo_normativo = UPPER(TRIM(NEW.codigo_normativo));
    SET NEW.titulo           = TRIM(NEW.titulo);
    IF NEW.codigo_normativo = '' OR NEW.titulo = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El codigo normativo y el titulo del documento son obligatorios.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_documento_gestion_bu //
CREATE TRIGGER trg_documento_gestion_bu BEFORE UPDATE ON documento_gestion
FOR EACH ROW
BEGIN
    SET NEW.codigo_normativo = UPPER(TRIM(NEW.codigo_normativo));
    SET NEW.titulo           = TRIM(NEW.titulo);
    IF NEW.codigo_normativo = '' OR NEW.titulo = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El codigo normativo y el titulo del documento son obligatorios.';
    END IF;
END //

-- SEDE_DISPOSITIVO (cada octeto de la IP debe estar entre 0 y 255) -----
DROP TRIGGER IF EXISTS trg_sede_dispositivo_bi //
CREATE TRIGGER trg_sede_dispositivo_bi BEFORE INSERT ON sede_dispositivo
FOR EACH ROW
BEGIN
    IF CAST(SUBSTRING_INDEX(NEW.codigo_ip, '.', 1) AS UNSIGNED) > 255
       OR CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.codigo_ip, '.', 2), '.', -1) AS UNSIGNED) > 255
       OR CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.codigo_ip, '.', 3), '.', -1) AS UNSIGNED) > 255
       OR CAST(SUBSTRING_INDEX(NEW.codigo_ip, '.', -1) AS UNSIGNED) > 255 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La direccion IP no es valida: cada octeto debe estar entre 0 y 255.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_sede_dispositivo_bu //
CREATE TRIGGER trg_sede_dispositivo_bu BEFORE UPDATE ON sede_dispositivo
FOR EACH ROW
BEGIN
    IF CAST(SUBSTRING_INDEX(NEW.codigo_ip, '.', 1) AS UNSIGNED) > 255
       OR CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.codigo_ip, '.', 2), '.', -1) AS UNSIGNED) > 255
       OR CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.codigo_ip, '.', 3), '.', -1) AS UNSIGNED) > 255
       OR CAST(SUBSTRING_INDEX(NEW.codigo_ip, '.', -1) AS UNSIGNED) > 255 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La direccion IP no es valida: cada octeto debe estar entre 0 y 255.';
    END IF;
END //

-- ASISTENCIA ----------------------------------------------------------
-- Reglas: solo marcan trabajadores Activos en dispositivos Activos, una
-- sola Entrada por dia, y el estado se calcula (Entrada despues de las
-- 08:05:00 = Tardanza; cualquier otra marcacion = Puntual).
DROP TRIGGER IF EXISTS trg_asistencia_bi //
CREATE TRIGGER trg_asistencia_bi BEFORE INSERT ON asistencia
FOR EACH ROW
BEGIN
    DECLARE v_estado_trabajador VARCHAR(20);
    DECLARE v_estado_dispositivo VARCHAR(20);

    SELECT estado INTO v_estado_trabajador
    FROM trabajador WHERE id_trabajador = NEW.id_trabajador;
    IF v_estado_trabajador IS NOT NULL AND v_estado_trabajador <> 'Activo' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo los trabajadores con estado Activo pueden registrar marcaciones.';
    END IF;

    SELECT estado_dispositivo INTO v_estado_dispositivo
    FROM sede_dispositivo WHERE id_dispositivo = NEW.id_dispositivo;
    IF v_estado_dispositivo IS NOT NULL AND v_estado_dispositivo <> 'Activo' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El dispositivo biometrico no esta Activo (mantenimiento o inactivo).';
    END IF;

    IF NEW.tipo_marcacion = 'Entrada' THEN
        IF EXISTS (SELECT 1 FROM asistencia
                   WHERE id_trabajador = NEW.id_trabajador
                     AND tipo_marcacion = 'Entrada'
                     AND DATE(fecha_hora_marcacion) = DATE(NEW.fecha_hora_marcacion)) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El trabajador ya registro su Entrada en esa fecha.';
        END IF;
        IF TIME(NEW.fecha_hora_marcacion) > '08:05:00' THEN
            SET NEW.estado_marcacion = 'Tardanza';
        ELSE
            SET NEW.estado_marcacion = 'Puntual';
        END IF;
    ELSE
        SET NEW.estado_marcacion = 'Puntual';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_asistencia_bu //
CREATE TRIGGER trg_asistencia_bu BEFORE UPDATE ON asistencia
FOR EACH ROW
BEGIN
    DECLARE v_estado_trabajador VARCHAR(20);
    DECLARE v_estado_dispositivo VARCHAR(20);

    SELECT estado INTO v_estado_trabajador
    FROM trabajador WHERE id_trabajador = NEW.id_trabajador;
    IF v_estado_trabajador IS NOT NULL AND v_estado_trabajador <> 'Activo' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Solo los trabajadores con estado Activo pueden registrar marcaciones.';
    END IF;

    SELECT estado_dispositivo INTO v_estado_dispositivo
    FROM sede_dispositivo WHERE id_dispositivo = NEW.id_dispositivo;
    IF v_estado_dispositivo IS NOT NULL AND v_estado_dispositivo <> 'Activo' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El dispositivo biometrico no esta Activo (mantenimiento o inactivo).';
    END IF;

    IF NEW.tipo_marcacion = 'Entrada' THEN
        IF EXISTS (SELECT 1 FROM asistencia
                   WHERE id_trabajador = NEW.id_trabajador
                     AND id_asistencia <> OLD.id_asistencia
                     AND tipo_marcacion = 'Entrada'
                     AND DATE(fecha_hora_marcacion) = DATE(NEW.fecha_hora_marcacion)) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'El trabajador ya registro su Entrada en esa fecha.';
        END IF;
        IF TIME(NEW.fecha_hora_marcacion) > '08:05:00' THEN
            SET NEW.estado_marcacion = 'Tardanza';
        ELSE
            SET NEW.estado_marcacion = 'Puntual';
        END IF;
    ELSE
        SET NEW.estado_marcacion = 'Puntual';
    END IF;
END //

-- REGISTRO_INDUCCION --------------------------------------------------
DROP TRIGGER IF EXISTS trg_registro_induccion_bi //
CREATE TRIGGER trg_registro_induccion_bi BEFORE INSERT ON registro_induccion
FOR EACH ROW
BEGIN
    DECLARE v_fecha_registro DATE;
    SELECT fecha_registro INTO v_fecha_registro
    FROM trabajador WHERE id_trabajador = NEW.id_trabajador;
    IF v_fecha_registro IS NOT NULL AND NEW.fecha_induccion < v_fecha_registro THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha de induccion no puede ser anterior a la fecha de registro del trabajador.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_registro_induccion_bu //
CREATE TRIGGER trg_registro_induccion_bu BEFORE UPDATE ON registro_induccion
FOR EACH ROW
BEGIN
    DECLARE v_fecha_registro DATE;
    SELECT fecha_registro INTO v_fecha_registro
    FROM trabajador WHERE id_trabajador = NEW.id_trabajador;
    IF v_fecha_registro IS NOT NULL AND NEW.fecha_induccion < v_fecha_registro THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha de induccion no puede ser anterior a la fecha de registro del trabajador.';
    END IF;
END //

-- Borra el detalle de forma explicita para que quede auditado
DROP TRIGGER IF EXISTS trg_registro_induccion_bd //
CREATE TRIGGER trg_registro_induccion_bd BEFORE DELETE ON registro_induccion
FOR EACH ROW
BEGIN
    DELETE FROM detalle_induccion WHERE id_induccion = OLD.id_induccion;
END //

-- DETALLE_INDUCCION ---------------------------------------------------
DROP TRIGGER IF EXISTS trg_detalle_induccion_bi //
CREATE TRIGGER trg_detalle_induccion_bi BEFORE INSERT ON detalle_induccion
FOR EACH ROW
BEGIN
    IF NEW.estado_cumplimiento NOT IN ('Cumplido', 'Pendiente') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El estado de cumplimiento debe ser Cumplido o Pendiente.';
    END IF;
    IF NEW.estado_cumplimiento = 'Cumplido'
       AND (NEW.firma_responsable IS NULL OR TRIM(NEW.firma_responsable) = '') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un documento Cumplido requiere la firma del responsable.';
    END IF;
    IF NEW.estado_cumplimiento = 'Pendiente' THEN
        SET NEW.firma_responsable = NULL;
    END IF;
END //

DROP TRIGGER IF EXISTS trg_detalle_induccion_bu //
CREATE TRIGGER trg_detalle_induccion_bu BEFORE UPDATE ON detalle_induccion
FOR EACH ROW
BEGIN
    IF NEW.estado_cumplimiento NOT IN ('Cumplido', 'Pendiente') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El estado de cumplimiento debe ser Cumplido o Pendiente.';
    END IF;
    IF NEW.estado_cumplimiento = 'Cumplido'
       AND (NEW.firma_responsable IS NULL OR TRIM(NEW.firma_responsable) = '') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un documento Cumplido requiere la firma del responsable.';
    END IF;
    IF NEW.estado_cumplimiento = 'Pendiente' THEN
        SET NEW.firma_responsable = NULL;
    END IF;
END //

-- =====================================================================
-- 3. TRIGGERS AFTER (auditoria de INSERT / UPDATE / DELETE)
-- =====================================================================


-- Auditoria: trabajador
DROP TRIGGER IF EXISTS trg_trabajador_ai //
CREATE TRIGGER trg_trabajador_ai AFTER INSERT ON trabajador
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('trabajador', 'INSERT', NEW.id_trabajador,
            CONCAT_WS(' | ',
            CONCAT('nombres=', IFNULL(NEW.nombres, 'NULL')),
            CONCAT('apellidos=', IFNULL(NEW.apellidos, 'NULL')),
            CONCAT('fecha_registro=', IFNULL(NEW.fecha_registro, 'NULL')),
            CONCAT('estado=', IFNULL(NEW.estado, 'NULL')),
            CONCAT('id_cargo=', IFNULL(NEW.id_cargo, 'NULL')),
            CONCAT('id_supervisor=', IFNULL(NEW.id_supervisor, 'NULL'))),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_trabajador_au //
CREATE TRIGGER trg_trabajador_au AFTER UPDATE ON trabajador
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('trabajador', 'UPDATE', NEW.id_trabajador,
            CONCAT_WS(' | ',
            IF(NOT (OLD.nombres <=> NEW.nombres), CONCAT('nombres: ', IFNULL(OLD.nombres, 'NULL'), ' -> ', IFNULL(NEW.nombres, 'NULL')), NULL),
            IF(NOT (OLD.apellidos <=> NEW.apellidos), CONCAT('apellidos: ', IFNULL(OLD.apellidos, 'NULL'), ' -> ', IFNULL(NEW.apellidos, 'NULL')), NULL),
            IF(NOT (OLD.fecha_registro <=> NEW.fecha_registro), CONCAT('fecha_registro: ', IFNULL(OLD.fecha_registro, 'NULL'), ' -> ', IFNULL(NEW.fecha_registro, 'NULL')), NULL),
            IF(NOT (OLD.estado <=> NEW.estado), CONCAT('estado: ', IFNULL(OLD.estado, 'NULL'), ' -> ', IFNULL(NEW.estado, 'NULL')), NULL),
            IF(NOT (OLD.id_cargo <=> NEW.id_cargo), CONCAT('id_cargo: ', IFNULL(OLD.id_cargo, 'NULL'), ' -> ', IFNULL(NEW.id_cargo, 'NULL')), NULL),
            IF(NOT (OLD.id_supervisor <=> NEW.id_supervisor), CONCAT('id_supervisor: ', IFNULL(OLD.id_supervisor, 'NULL'), ' -> ', IFNULL(NEW.id_supervisor, 'NULL')), NULL)),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_trabajador_ad //
CREATE TRIGGER trg_trabajador_ad AFTER DELETE ON trabajador
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('trabajador', 'DELETE', OLD.id_trabajador,
            CONCAT_WS(' | ',
            CONCAT('nombres=', IFNULL(OLD.nombres, 'NULL')),
            CONCAT('apellidos=', IFNULL(OLD.apellidos, 'NULL')),
            CONCAT('fecha_registro=', IFNULL(OLD.fecha_registro, 'NULL')),
            CONCAT('estado=', IFNULL(OLD.estado, 'NULL')),
            CONCAT('id_cargo=', IFNULL(OLD.id_cargo, 'NULL')),
            CONCAT('id_supervisor=', IFNULL(OLD.id_supervisor, 'NULL'))),
            CURRENT_USER());
END //

-- Auditoria: cargo
DROP TRIGGER IF EXISTS trg_cargo_ai //
CREATE TRIGGER trg_cargo_ai AFTER INSERT ON cargo
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('cargo', 'INSERT', NEW.id_cargo,
            CONCAT_WS(' | ',
            CONCAT('nombre_cargo=', IFNULL(NEW.nombre_cargo, 'NULL')),
            CONCAT('descripcion=', IFNULL(NEW.descripcion, 'NULL')),
            CONCAT('nivel_estructural=', IFNULL(NEW.nivel_estructural, 'NULL'))),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_cargo_au //
CREATE TRIGGER trg_cargo_au AFTER UPDATE ON cargo
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('cargo', 'UPDATE', NEW.id_cargo,
            CONCAT_WS(' | ',
            IF(NOT (OLD.nombre_cargo <=> NEW.nombre_cargo), CONCAT('nombre_cargo: ', IFNULL(OLD.nombre_cargo, 'NULL'), ' -> ', IFNULL(NEW.nombre_cargo, 'NULL')), NULL),
            IF(NOT (OLD.descripcion <=> NEW.descripcion), CONCAT('descripcion: ', IFNULL(OLD.descripcion, 'NULL'), ' -> ', IFNULL(NEW.descripcion, 'NULL')), NULL),
            IF(NOT (OLD.nivel_estructural <=> NEW.nivel_estructural), CONCAT('nivel_estructural: ', IFNULL(OLD.nivel_estructural, 'NULL'), ' -> ', IFNULL(NEW.nivel_estructural, 'NULL')), NULL)),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_cargo_ad //
CREATE TRIGGER trg_cargo_ad AFTER DELETE ON cargo
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('cargo', 'DELETE', OLD.id_cargo,
            CONCAT_WS(' | ',
            CONCAT('nombre_cargo=', IFNULL(OLD.nombre_cargo, 'NULL')),
            CONCAT('descripcion=', IFNULL(OLD.descripcion, 'NULL')),
            CONCAT('nivel_estructural=', IFNULL(OLD.nivel_estructural, 'NULL'))),
            CURRENT_USER());
END //

-- Auditoria: sede_dispositivo
DROP TRIGGER IF EXISTS trg_sede_dispositivo_ai //
CREATE TRIGGER trg_sede_dispositivo_ai AFTER INSERT ON sede_dispositivo
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('sede_dispositivo', 'INSERT', NEW.id_dispositivo,
            CONCAT_WS(' | ',
            CONCAT('nombre_sede=', IFNULL(NEW.nombre_sede, 'NULL')),
            CONCAT('direccion=', IFNULL(NEW.direccion, 'NULL')),
            CONCAT('codigo_ip=', IFNULL(NEW.codigo_ip, 'NULL')),
            CONCAT('estado_dispositivo=', IFNULL(NEW.estado_dispositivo, 'NULL'))),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_sede_dispositivo_au //
CREATE TRIGGER trg_sede_dispositivo_au AFTER UPDATE ON sede_dispositivo
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('sede_dispositivo', 'UPDATE', NEW.id_dispositivo,
            CONCAT_WS(' | ',
            IF(NOT (OLD.nombre_sede <=> NEW.nombre_sede), CONCAT('nombre_sede: ', IFNULL(OLD.nombre_sede, 'NULL'), ' -> ', IFNULL(NEW.nombre_sede, 'NULL')), NULL),
            IF(NOT (OLD.direccion <=> NEW.direccion), CONCAT('direccion: ', IFNULL(OLD.direccion, 'NULL'), ' -> ', IFNULL(NEW.direccion, 'NULL')), NULL),
            IF(NOT (OLD.codigo_ip <=> NEW.codigo_ip), CONCAT('codigo_ip: ', IFNULL(OLD.codigo_ip, 'NULL'), ' -> ', IFNULL(NEW.codigo_ip, 'NULL')), NULL),
            IF(NOT (OLD.estado_dispositivo <=> NEW.estado_dispositivo), CONCAT('estado_dispositivo: ', IFNULL(OLD.estado_dispositivo, 'NULL'), ' -> ', IFNULL(NEW.estado_dispositivo, 'NULL')), NULL)),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_sede_dispositivo_ad //
CREATE TRIGGER trg_sede_dispositivo_ad AFTER DELETE ON sede_dispositivo
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('sede_dispositivo', 'DELETE', OLD.id_dispositivo,
            CONCAT_WS(' | ',
            CONCAT('nombre_sede=', IFNULL(OLD.nombre_sede, 'NULL')),
            CONCAT('direccion=', IFNULL(OLD.direccion, 'NULL')),
            CONCAT('codigo_ip=', IFNULL(OLD.codigo_ip, 'NULL')),
            CONCAT('estado_dispositivo=', IFNULL(OLD.estado_dispositivo, 'NULL'))),
            CURRENT_USER());
END //

-- Auditoria: documento_gestion
DROP TRIGGER IF EXISTS trg_documento_gestion_ai //
CREATE TRIGGER trg_documento_gestion_ai AFTER INSERT ON documento_gestion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('documento_gestion', 'INSERT', NEW.id_documento,
            CONCAT_WS(' | ',
            CONCAT('titulo=', IFNULL(NEW.titulo, 'NULL')),
            CONCAT('codigo_normativo=', IFNULL(NEW.codigo_normativo, 'NULL')),
            CONCAT('version=', IFNULL(NEW.version, 'NULL')),
            CONCAT('fecha_aprobacion=', IFNULL(NEW.fecha_aprobacion, 'NULL'))),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_documento_gestion_au //
CREATE TRIGGER trg_documento_gestion_au AFTER UPDATE ON documento_gestion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('documento_gestion', 'UPDATE', NEW.id_documento,
            CONCAT_WS(' | ',
            IF(NOT (OLD.titulo <=> NEW.titulo), CONCAT('titulo: ', IFNULL(OLD.titulo, 'NULL'), ' -> ', IFNULL(NEW.titulo, 'NULL')), NULL),
            IF(NOT (OLD.codigo_normativo <=> NEW.codigo_normativo), CONCAT('codigo_normativo: ', IFNULL(OLD.codigo_normativo, 'NULL'), ' -> ', IFNULL(NEW.codigo_normativo, 'NULL')), NULL),
            IF(NOT (OLD.version <=> NEW.version), CONCAT('version: ', IFNULL(OLD.version, 'NULL'), ' -> ', IFNULL(NEW.version, 'NULL')), NULL),
            IF(NOT (OLD.fecha_aprobacion <=> NEW.fecha_aprobacion), CONCAT('fecha_aprobacion: ', IFNULL(OLD.fecha_aprobacion, 'NULL'), ' -> ', IFNULL(NEW.fecha_aprobacion, 'NULL')), NULL)),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_documento_gestion_ad //
CREATE TRIGGER trg_documento_gestion_ad AFTER DELETE ON documento_gestion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('documento_gestion', 'DELETE', OLD.id_documento,
            CONCAT_WS(' | ',
            CONCAT('titulo=', IFNULL(OLD.titulo, 'NULL')),
            CONCAT('codigo_normativo=', IFNULL(OLD.codigo_normativo, 'NULL')),
            CONCAT('version=', IFNULL(OLD.version, 'NULL')),
            CONCAT('fecha_aprobacion=', IFNULL(OLD.fecha_aprobacion, 'NULL'))),
            CURRENT_USER());
END //

-- Auditoria: registro_induccion
DROP TRIGGER IF EXISTS trg_registro_induccion_ai //
CREATE TRIGGER trg_registro_induccion_ai AFTER INSERT ON registro_induccion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('registro_induccion', 'INSERT', NEW.id_induccion,
            CONCAT_WS(' | ',
            CONCAT('tipo_proceso=', IFNULL(NEW.tipo_proceso, 'NULL')),
            CONCAT('observaciones=', IFNULL(NEW.observaciones, 'NULL')),
            CONCAT('fecha_induccion=', IFNULL(NEW.fecha_induccion, 'NULL')),
            CONCAT('firma_trabajador=', IFNULL(NEW.firma_trabajador, 'NULL')),
            CONCAT('id_trabajador=', IFNULL(NEW.id_trabajador, 'NULL'))),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_registro_induccion_au //
CREATE TRIGGER trg_registro_induccion_au AFTER UPDATE ON registro_induccion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('registro_induccion', 'UPDATE', NEW.id_induccion,
            CONCAT_WS(' | ',
            IF(NOT (OLD.tipo_proceso <=> NEW.tipo_proceso), CONCAT('tipo_proceso: ', IFNULL(OLD.tipo_proceso, 'NULL'), ' -> ', IFNULL(NEW.tipo_proceso, 'NULL')), NULL),
            IF(NOT (OLD.observaciones <=> NEW.observaciones), CONCAT('observaciones: ', IFNULL(OLD.observaciones, 'NULL'), ' -> ', IFNULL(NEW.observaciones, 'NULL')), NULL),
            IF(NOT (OLD.fecha_induccion <=> NEW.fecha_induccion), CONCAT('fecha_induccion: ', IFNULL(OLD.fecha_induccion, 'NULL'), ' -> ', IFNULL(NEW.fecha_induccion, 'NULL')), NULL),
            IF(NOT (OLD.firma_trabajador <=> NEW.firma_trabajador), CONCAT('firma_trabajador: ', IFNULL(OLD.firma_trabajador, 'NULL'), ' -> ', IFNULL(NEW.firma_trabajador, 'NULL')), NULL),
            IF(NOT (OLD.id_trabajador <=> NEW.id_trabajador), CONCAT('id_trabajador: ', IFNULL(OLD.id_trabajador, 'NULL'), ' -> ', IFNULL(NEW.id_trabajador, 'NULL')), NULL)),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_registro_induccion_ad //
CREATE TRIGGER trg_registro_induccion_ad AFTER DELETE ON registro_induccion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('registro_induccion', 'DELETE', OLD.id_induccion,
            CONCAT_WS(' | ',
            CONCAT('tipo_proceso=', IFNULL(OLD.tipo_proceso, 'NULL')),
            CONCAT('observaciones=', IFNULL(OLD.observaciones, 'NULL')),
            CONCAT('fecha_induccion=', IFNULL(OLD.fecha_induccion, 'NULL')),
            CONCAT('firma_trabajador=', IFNULL(OLD.firma_trabajador, 'NULL')),
            CONCAT('id_trabajador=', IFNULL(OLD.id_trabajador, 'NULL'))),
            CURRENT_USER());
END //

-- Auditoria: asistencia
DROP TRIGGER IF EXISTS trg_asistencia_ai //
CREATE TRIGGER trg_asistencia_ai AFTER INSERT ON asistencia
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('asistencia', 'INSERT', NEW.id_asistencia,
            CONCAT_WS(' | ',
            CONCAT('fecha_hora_marcacion=', IFNULL(NEW.fecha_hora_marcacion, 'NULL')),
            CONCAT('tipo_marcacion=', IFNULL(NEW.tipo_marcacion, 'NULL')),
            CONCAT('estado_marcacion=', IFNULL(NEW.estado_marcacion, 'NULL')),
            CONCAT('id_trabajador=', IFNULL(NEW.id_trabajador, 'NULL')),
            CONCAT('id_dispositivo=', IFNULL(NEW.id_dispositivo, 'NULL'))),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_asistencia_au //
CREATE TRIGGER trg_asistencia_au AFTER UPDATE ON asistencia
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('asistencia', 'UPDATE', NEW.id_asistencia,
            CONCAT_WS(' | ',
            IF(NOT (OLD.fecha_hora_marcacion <=> NEW.fecha_hora_marcacion), CONCAT('fecha_hora_marcacion: ', IFNULL(OLD.fecha_hora_marcacion, 'NULL'), ' -> ', IFNULL(NEW.fecha_hora_marcacion, 'NULL')), NULL),
            IF(NOT (OLD.tipo_marcacion <=> NEW.tipo_marcacion), CONCAT('tipo_marcacion: ', IFNULL(OLD.tipo_marcacion, 'NULL'), ' -> ', IFNULL(NEW.tipo_marcacion, 'NULL')), NULL),
            IF(NOT (OLD.estado_marcacion <=> NEW.estado_marcacion), CONCAT('estado_marcacion: ', IFNULL(OLD.estado_marcacion, 'NULL'), ' -> ', IFNULL(NEW.estado_marcacion, 'NULL')), NULL),
            IF(NOT (OLD.id_trabajador <=> NEW.id_trabajador), CONCAT('id_trabajador: ', IFNULL(OLD.id_trabajador, 'NULL'), ' -> ', IFNULL(NEW.id_trabajador, 'NULL')), NULL),
            IF(NOT (OLD.id_dispositivo <=> NEW.id_dispositivo), CONCAT('id_dispositivo: ', IFNULL(OLD.id_dispositivo, 'NULL'), ' -> ', IFNULL(NEW.id_dispositivo, 'NULL')), NULL)),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_asistencia_ad //
CREATE TRIGGER trg_asistencia_ad AFTER DELETE ON asistencia
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('asistencia', 'DELETE', OLD.id_asistencia,
            CONCAT_WS(' | ',
            CONCAT('fecha_hora_marcacion=', IFNULL(OLD.fecha_hora_marcacion, 'NULL')),
            CONCAT('tipo_marcacion=', IFNULL(OLD.tipo_marcacion, 'NULL')),
            CONCAT('estado_marcacion=', IFNULL(OLD.estado_marcacion, 'NULL')),
            CONCAT('id_trabajador=', IFNULL(OLD.id_trabajador, 'NULL')),
            CONCAT('id_dispositivo=', IFNULL(OLD.id_dispositivo, 'NULL'))),
            CURRENT_USER());
END //

-- Auditoria: detalle_induccion
DROP TRIGGER IF EXISTS trg_detalle_induccion_ai //
CREATE TRIGGER trg_detalle_induccion_ai AFTER INSERT ON detalle_induccion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('detalle_induccion', 'INSERT', CONCAT(NEW.id_induccion, '-', NEW.id_detalle),
            CONCAT_WS(' | ',
            CONCAT('id_documento=', IFNULL(NEW.id_documento, 'NULL')),
            CONCAT('estado_cumplimiento=', IFNULL(NEW.estado_cumplimiento, 'NULL')),
            CONCAT('firma_responsable=', IFNULL(NEW.firma_responsable, 'NULL'))),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_detalle_induccion_au //
CREATE TRIGGER trg_detalle_induccion_au AFTER UPDATE ON detalle_induccion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('detalle_induccion', 'UPDATE', CONCAT(NEW.id_induccion, '-', NEW.id_detalle),
            CONCAT_WS(' | ',
            IF(NOT (OLD.id_documento <=> NEW.id_documento), CONCAT('id_documento: ', IFNULL(OLD.id_documento, 'NULL'), ' -> ', IFNULL(NEW.id_documento, 'NULL')), NULL),
            IF(NOT (OLD.estado_cumplimiento <=> NEW.estado_cumplimiento), CONCAT('estado_cumplimiento: ', IFNULL(OLD.estado_cumplimiento, 'NULL'), ' -> ', IFNULL(NEW.estado_cumplimiento, 'NULL')), NULL),
            IF(NOT (OLD.firma_responsable <=> NEW.firma_responsable), CONCAT('firma_responsable: ', IFNULL(OLD.firma_responsable, 'NULL'), ' -> ', IFNULL(NEW.firma_responsable, 'NULL')), NULL)),
            CURRENT_USER());
END //

DROP TRIGGER IF EXISTS trg_detalle_induccion_ad //
CREATE TRIGGER trg_detalle_induccion_ad AFTER DELETE ON detalle_induccion
FOR EACH ROW
BEGIN
    INSERT INTO auditoria (tabla, operacion, id_registro, detalle, usuario_bd)
    VALUES ('detalle_induccion', 'DELETE', CONCAT(OLD.id_induccion, '-', OLD.id_detalle),
            CONCAT_WS(' | ',
            CONCAT('id_documento=', IFNULL(OLD.id_documento, 'NULL')),
            CONCAT('estado_cumplimiento=', IFNULL(OLD.estado_cumplimiento, 'NULL')),
            CONCAT('firma_responsable=', IFNULL(OLD.firma_responsable, 'NULL'))),
            CURRENT_USER());
END //

DELIMITER ;
