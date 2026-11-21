USE registro_trabajadores;

DELIMITER //

-- =====================================================================
-- 1. PROCEDIMIENTOS PARA TRABAJADOR (CRUD + Consulta C1)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_listar_trabajadores //
CREATE PROCEDURE sp_listar_trabajadores()
BEGIN
    SELECT t.id_trabajador,
           t.tipo_documento,t.identificacion,t.nacimiento,t.genero,t.correo,t.telefono,
           t.departamento,t.contrato,t.foto IS NOT NULL AS tiene_foto,t.nombre_adjunto,
           t.nombres,
           t.apellidos,
           t.fecha_registro,
           t.estado,
           t.id_cargo,
           c.nombre_cargo AS cargo,
           t.id_supervisor,
           CONCAT(s.nombres, ' ', s.apellidos) AS supervisor
    FROM trabajador t
    INNER JOIN cargo c ON c.id_cargo = t.id_cargo
    LEFT  JOIN trabajador s ON s.id_trabajador = t.id_supervisor
    ORDER BY t.id_trabajador;
END //

DROP PROCEDURE IF EXISTS sp_guardar_trabajador //
CREATE PROCEDURE sp_guardar_trabajador(
    IN p_id_trabajador INT,
    IN p_nombres VARCHAR(100),
    IN p_apellidos VARCHAR(100),
    IN p_fecha_registro DATE,
    IN p_estado VARCHAR(20),
    IN p_id_cargo INT,
    IN p_id_supervisor INT,
    IN p_tipo_documento VARCHAR(20),
    IN p_identificacion VARCHAR(24),
    IN p_nacimiento DATE,
    IN p_genero VARCHAR(30),
    IN p_correo VARCHAR(150),
    IN p_telefono VARCHAR(30),
    IN p_departamento VARCHAR(100),
    IN p_contrato VARCHAR(60),
    IN p_foto MEDIUMBLOB,
    IN p_adjunto MEDIUMBLOB,
    IN p_nombre_adjunto VARCHAR(150)
)
BEGIN
    IF p_id_trabajador IS NULL OR p_id_trabajador = 0 THEN
        INSERT INTO trabajador (nombres, apellidos, fecha_registro, estado, id_cargo, id_supervisor, tipo_documento, identificacion, nacimiento, genero, correo, telefono, departamento, contrato, foto, adjunto, nombre_adjunto)
        VALUES (p_nombres, p_apellidos, p_fecha_registro, p_estado, p_id_cargo, p_id_supervisor, p_tipo_documento, p_identificacion, p_nacimiento, p_genero, p_correo, p_telefono, p_departamento, p_contrato, p_foto, p_adjunto, p_nombre_adjunto);
    ELSE
        UPDATE trabajador
        SET nombres = p_nombres,
            apellidos = p_apellidos,
            fecha_registro = p_fecha_registro,
            estado = p_estado,
            id_cargo = p_id_cargo,
            id_supervisor = p_id_supervisor,
            tipo_documento = p_tipo_documento,
            identificacion = p_identificacion,
            nacimiento = p_nacimiento,
            genero = p_genero,
            correo = p_correo,
            telefono = p_telefono,
            departamento = p_departamento,
            contrato = p_contrato,
            foto = COALESCE(p_foto, foto),
            adjunto = COALESCE(p_adjunto, adjunto),
            nombre_adjunto = COALESCE(p_nombre_adjunto, nombre_adjunto)
        WHERE id_trabajador = p_id_trabajador;
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_eliminar_trabajador //
CREATE PROCEDURE sp_eliminar_trabajador(IN p_id_trabajador INT)
BEGIN
    DELETE FROM trabajador WHERE id_trabajador = p_id_trabajador;
END //

-- =====================================================================
-- 2. PROCEDIMIENTOS PARA CARGO (CRUD)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_guardar_cargo //
CREATE PROCEDURE sp_guardar_cargo(
    IN p_id_cargo INT,
    IN p_nombre_cargo VARCHAR(100),
    IN p_nivel_estructural VARCHAR(50),
    IN p_descripcion VARCHAR(255)
)
BEGIN
    IF p_id_cargo IS NULL OR p_id_cargo = 0 THEN
        INSERT INTO cargo (nombre_cargo, nivel_estructural, descripcion)
        VALUES (p_nombre_cargo, p_nivel_estructural, p_descripcion);
    ELSE
        UPDATE cargo
        SET nombre_cargo = p_nombre_cargo,
            nivel_estructural = p_nivel_estructural,
            descripcion = p_descripcion
        WHERE id_cargo = p_id_cargo;
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_eliminar_cargo //
CREATE PROCEDURE sp_eliminar_cargo(IN p_id_cargo INT)
BEGIN
    DELETE FROM cargo WHERE id_cargo = p_id_cargo;
END //

-- =====================================================================
-- 3. PROCEDIMIENTOS PARA INDUCCIÓN Y DETALLE (Maestro - Detalle M:N)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_insertar_induccion_cabecera //
CREATE PROCEDURE sp_insertar_induccion_cabecera(
    IN p_tipo_proceso VARCHAR(50),
    IN p_observaciones VARCHAR(255),
    IN p_fecha_induccion DATE,
    IN p_firma_trabajador VARCHAR(255),
    IN p_id_trabajador INT,
    OUT p_nuevo_id INT
)
BEGIN
    INSERT INTO registro_induccion (tipo_proceso, observaciones, fecha_induccion, firma_trabajador, id_trabajador)
    VALUES (p_tipo_proceso, p_observaciones, p_fecha_induccion, p_firma_trabajador, p_id_trabajador);
    SET p_nuevo_id = LAST_INSERT_ID();
END //

DROP PROCEDURE IF EXISTS sp_insertar_induccion_detalle //
CREATE PROCEDURE sp_insertar_induccion_detalle(
    IN p_id_induccion INT,
    IN p_id_detalle INT,
    IN p_id_documento INT,
    IN p_estado_cumplimiento VARCHAR(50),
    IN p_firma_responsable VARCHAR(255)
)
BEGIN
    INSERT INTO detalle_induccion (id_induccion, id_detalle, id_documento, estado_cumplimiento, firma_responsable)
    VALUES (p_id_induccion, p_id_detalle, p_id_documento, p_estado_cumplimiento, p_firma_responsable);
END //

DROP PROCEDURE IF EXISTS sp_eliminar_induccion //
CREATE PROCEDURE sp_eliminar_induccion(IN p_id_induccion INT)
BEGIN
    DELETE FROM registro_induccion WHERE id_induccion = p_id_induccion;
END //

-- =====================================================================
-- 4. PROCEDIMIENTOS PARA DOCUMENTO DE GESTIÓN (CRUD)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_guardar_documento //
CREATE PROCEDURE sp_guardar_documento(
    IN p_id_documento INT,
    IN p_codigo_normativo VARCHAR(50),
    IN p_titulo VARCHAR(150),
    IN p_version VARCHAR(20),
    IN p_fecha_aprobacion DATE
)
BEGIN
    IF p_id_documento IS NULL OR p_id_documento = 0 THEN
        INSERT INTO documento_gestion (codigo_normativo, titulo, version, fecha_aprobacion)
        VALUES (p_codigo_normativo, p_titulo, p_version, p_fecha_aprobacion);
    ELSE
        UPDATE documento_gestion
        SET codigo_normativo = p_codigo_normativo,
            titulo = p_titulo,
            version = p_version,
            fecha_aprobacion = p_fecha_aprobacion
        WHERE id_documento = p_id_documento;
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_eliminar_documento //
CREATE PROCEDURE sp_eliminar_documento(IN p_id_documento INT)
BEGIN
    DELETE FROM documento_gestion WHERE id_documento = p_id_documento;
END //

-- =====================================================================
-- 5. PROCEDIMIENTOS PARA ASISTENCIA (CRUD)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_guardar_asistencia //
CREATE PROCEDURE sp_guardar_asistencia(
    IN p_id_asistencia INT,
    IN p_fecha_hora DATETIME,
    IN p_tipo_marcacion VARCHAR(30),
    IN p_estado_marcacion VARCHAR(30),
    IN p_id_trabajador INT,
    IN p_id_dispositivo INT
)
BEGIN
    IF p_id_asistencia IS NULL OR p_id_asistencia = 0 THEN
        INSERT INTO asistencia (fecha_hora_marcacion, tipo_marcacion, estado_marcacion, id_trabajador, id_dispositivo)
        VALUES (p_fecha_hora, p_tipo_marcacion, p_estado_marcacion, p_id_trabajador, p_id_dispositivo);
    ELSE
        UPDATE asistencia
        SET fecha_hora_marcacion = p_fecha_hora,
            tipo_marcacion = p_tipo_marcacion,
            estado_marcacion = p_estado_marcacion,
            id_trabajador = p_id_trabajador,
            id_dispositivo = p_id_dispositivo
        WHERE id_asistencia = p_id_asistencia;
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_eliminar_asistencia //
CREATE PROCEDURE sp_eliminar_asistencia(IN p_id_asistencia INT)
BEGIN
    DELETE FROM asistencia WHERE id_asistencia = p_id_asistencia;
END //

-- =====================================================================
-- 6. PROCEDIMIENTOS PARA SEDE / DISPOSITIVO (CRUD)
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_guardar_sede //
CREATE PROCEDURE sp_guardar_sede(
    IN p_id_dispositivo INT,
    IN p_nombre_sede VARCHAR(100),
    IN p_direccion VARCHAR(200),
    IN p_codigo_ip VARCHAR(45),
    IN p_estado_dispositivo VARCHAR(20)
)
BEGIN
    IF p_id_dispositivo IS NULL OR p_id_dispositivo = 0 THEN
        INSERT INTO sede_dispositivo (nombre_sede, direccion, codigo_ip, estado_dispositivo)
        VALUES (p_nombre_sede, p_direccion, p_codigo_ip, p_estado_dispositivo);
    ELSE
        UPDATE sede_dispositivo
        SET nombre_sede = p_nombre_sede,
            direccion = p_direccion,
            codigo_ip = p_codigo_ip,
            estado_dispositivo = p_estado_dispositivo
        WHERE id_dispositivo = p_id_dispositivo;
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_eliminar_sede //
CREATE PROCEDURE sp_eliminar_sede(IN p_id_dispositivo INT)
BEGIN
    DELETE FROM sede_dispositivo WHERE id_dispositivo = p_id_dispositivo;
END //

DELIMITER ;