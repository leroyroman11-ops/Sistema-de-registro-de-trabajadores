-- Software para registro de trabajadores | Entregable 5

-- MySQL 8.4. Ejecutar una vez en una instancia de prueba con un esquema nuevo.

-- Para la instalación con Docker use Iniciar.cmd: Compose carga los SQL individuales.

SET NAMES utf8mb4;

-- Archivo: 01_crear_bd.sql

-- =====================================================================
-- Software para registro de trabajadores
-- Entrega 4: Script de creacion de la base de datos (MySQL 8.0)
-- =====================================================================
CREATE DATABASE IF NOT EXISTS registro_trabajadores
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE registro_trabajadores;

-- ---------------------------------------------------------------------
-- Tablas independientes (entidades fuertes)
-- ---------------------------------------------------------------------
CREATE TABLE cargo (
    id_cargo           INT          NOT NULL AUTO_INCREMENT,
    nombre_cargo       VARCHAR(100) NOT NULL,
    descripcion        VARCHAR(255) NULL,
    nivel_estructural  VARCHAR(50)  NOT NULL,
    CONSTRAINT pk_cargo PRIMARY KEY (id_cargo),
    CONSTRAINT uq_cargo_nombre UNIQUE (nombre_cargo)
) ENGINE = InnoDB;

CREATE TABLE sede_dispositivo (
    id_dispositivo      INT          NOT NULL AUTO_INCREMENT,
    nombre_sede         VARCHAR(100) NOT NULL,
    direccion           VARCHAR(200) NOT NULL,
    codigo_ip           VARCHAR(45)  NOT NULL,
    estado_dispositivo  VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_sede_dispositivo PRIMARY KEY (id_dispositivo),
    CONSTRAINT ck_dispositivo_estado
        CHECK (estado_dispositivo IN ('Activo', 'Mantenimiento', 'Inactivo')),
    CONSTRAINT ck_dispositivo_ip
        CHECK (codigo_ip REGEXP '^[0-9]{1,3}([.][0-9]{1,3}){3}$')
) ENGINE = InnoDB;

CREATE TABLE documento_gestion (
    id_documento      INT          NOT NULL AUTO_INCREMENT,
    titulo            VARCHAR(150) NOT NULL,
    codigo_normativo  VARCHAR(50)  NOT NULL,
    version           VARCHAR(20)  NOT NULL DEFAULT '1.0',
    fecha_aprobacion  DATE         NOT NULL,
    CONSTRAINT pk_documento_gestion PRIMARY KEY (id_documento),
    CONSTRAINT uq_documento_codigo UNIQUE (codigo_normativo)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- TRABAJADOR (incluye la relacion reflexiva "supervisa")
-- ---------------------------------------------------------------------
CREATE TABLE trabajador (
    id_trabajador   INT          NOT NULL AUTO_INCREMENT,
    nombres         VARCHAR(100) NOT NULL,
    apellidos       VARCHAR(100) NOT NULL,
    identificacion VARCHAR(24) NULL,
    tipo_documento VARCHAR(20) NULL,
    nacimiento DATE NULL,
    genero VARCHAR(30) NULL,
    correo VARCHAR(150) NULL,
    telefono VARCHAR(30) NULL,
    departamento VARCHAR(100) NULL,
    contrato VARCHAR(60) NULL,
    foto MEDIUMBLOB NULL,
    adjunto MEDIUMBLOB NULL,
    nombre_adjunto VARCHAR(150) NULL,
    fecha_registro  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    estado          VARCHAR(20)  NOT NULL,
    id_cargo        INT          NOT NULL,
    id_supervisor   INT          NULL,
    UNIQUE (tipo_documento, identificacion),
    CONSTRAINT pk_trabajador PRIMARY KEY (id_trabajador),
    CONSTRAINT ck_trabajador_estado
        CHECK (estado IN ('Activo', 'Inactivo', 'Cesado')),
    CONSTRAINT fk_trabajador_cargo
        FOREIGN KEY (id_cargo) REFERENCES cargo (id_cargo)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_trabajador_supervisor
        FOREIGN KEY (id_supervisor) REFERENCES trabajador (id_trabajador)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Tablas dependientes
-- ---------------------------------------------------------------------
CREATE TABLE registro_induccion (
    id_induccion      INT          NOT NULL AUTO_INCREMENT,
    tipo_proceso      VARCHAR(50)  NOT NULL,
    observaciones     VARCHAR(255) NULL,
    fecha_induccion   DATE         NOT NULL,
    firma_trabajador  VARCHAR(255) NOT NULL,
    id_trabajador     INT          NOT NULL,
    CONSTRAINT pk_registro_induccion PRIMARY KEY (id_induccion),
    CONSTRAINT fk_induccion_trabajador
        FOREIGN KEY (id_trabajador) REFERENCES trabajador (id_trabajador)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE asistencia (
    id_asistencia         INT         NOT NULL AUTO_INCREMENT,
    fecha_hora_marcacion  DATETIME    NOT NULL,
    tipo_marcacion        VARCHAR(30) NOT NULL,
    estado_marcacion      VARCHAR(30) NOT NULL DEFAULT 'Puntual',
    id_trabajador         INT         NOT NULL,
    id_dispositivo        INT         NOT NULL,
    dia_entrada DATE GENERATED ALWAYS AS
        (CASE WHEN tipo_marcacion='Entrada' THEN DATE(fecha_hora_marcacion) ELSE NULL END) STORED,
    UNIQUE (id_trabajador, dia_entrada),
    CONSTRAINT pk_asistencia PRIMARY KEY (id_asistencia),
    CONSTRAINT ck_asistencia_tipo
        CHECK (tipo_marcacion IN ('Entrada', 'Salida', 'Refrigerio')),
    CONSTRAINT fk_asistencia_trabajador
        FOREIGN KEY (id_trabajador) REFERENCES trabajador (id_trabajador)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_asistencia_dispositivo
        FOREIGN KEY (id_dispositivo) REFERENCES sede_dispositivo (id_dispositivo)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Tabla asociativa de la relacion M:N REGISTRO_INDUCCION - DOCUMENTO_GESTION
CREATE TABLE detalle_induccion (
    id_induccion         INT          NOT NULL,
    id_detalle           INT          NOT NULL,
    id_documento         INT          NOT NULL,
    estado_cumplimiento  VARCHAR(50)  NOT NULL,
    firma_responsable    VARCHAR(255) NULL,
    CONSTRAINT pk_detalle_induccion PRIMARY KEY (id_induccion, id_detalle),
    CONSTRAINT fk_detalle_induccion
        FOREIGN KEY (id_induccion) REFERENCES registro_induccion (id_induccion)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_detalle_documento
        FOREIGN KEY (id_documento) REFERENCES documento_gestion (id_documento)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Indices secundarios (claves foraneas y campos de busqueda frecuente)
-- ---------------------------------------------------------------------
CREATE INDEX idx_trabajador_cargo       ON trabajador (id_cargo);
CREATE INDEX idx_trabajador_supervisor  ON trabajador (id_supervisor);
CREATE INDEX idx_induccion_trabajador   ON registro_induccion (id_trabajador);
CREATE INDEX idx_asistencia_trabajador
    ON asistencia (id_trabajador, fecha_hora_marcacion);
CREATE INDEX idx_asistencia_dispositivo ON asistencia (id_dispositivo);
CREATE INDEX idx_detalle_documento      ON detalle_induccion (id_documento);

-- Archivo: 02_insertar_datos.sql

-- =====================================================================
-- Entrega 4: Insercion de datos de prueba
-- =====================================================================
USE registro_trabajadores;

-- CARGO ---------------------------------------------------------------
INSERT INTO cargo (nombre_cargo, descripcion, nivel_estructural) VALUES
('Gerente General', 'Dirección general de la organización', 'Directivo'),
('Jefe de Recursos Humanos','Gestion del personal e inducciones', 'Jefatura'),
('Medico General', 'Atencion medica ambulatoria', 'Operativo'),
('Medico Especialista', 'Atencion en especialidades medicas', 'Operativo'),
('Enfermera', 'Apoyo asistencial y procedimientos de enfermeria','Operativo'),
('Tecnico de Laboratorio','Toma y procesamiento de muestras', 'Operativo'),
('Recepcionista', 'Atencion al paciente y admision', 'Administrativo'),
('Personal de Limpieza', NULL, 'Apoyo');

-- SEDE_DISPOSITIVO ----------------------------------------------------
INSERT INTO sede_dispositivo (nombre_sede, direccion, codigo_ip, estado_dispositivo)
VALUES
('Sede Central', 'Av. Primavera 245, Arequipa', '192.168.1.10', 'Activo'),
('Sky Tower', 'Av. Ejercito 1009, Yanahuara', '192.168.2.10', 'Activo'),
('Torre Cayma', 'Av. Cayma 512, Cayma', '192.168.3.10', 'Mantenimiento');

-- DOCUMENTO_GESTION ---------------------------------------------------
INSERT INTO documento_gestion (titulo, codigo_normativo, version, fecha_aprobacion)
VALUES
('Politica Integrada de Gestion', 'PIG-001', '2.0', '2025-01-15'),
('Reglamento Interno de Trabajo', 'RIT-002', '1.3', '2024-06-10'),
('Plan de Seguridad y Salud en el Trabajo', 'SST-003', '1.1', '2025-03-20'),
('Protocolo de Bioseguridad', 'BIO-004', '3.0', '2025-08-05'),
('Codigo de Etica', 'ETI-005', '1.0', '2024-02-01'),
('Procedimiento de Gestion de Residuos Solidos','RES-006','1.2', '2025-05-12');

-- TRABAJADOR (primero los supervisores) -------------------------------
INSERT INTO trabajador
    (nombres, apellidos, fecha_registro, estado, id_cargo, id_supervisor)
VALUES
('Carlos Alberto', 'Mendoza Quispe', '2023-01-10', 'Activo', 1, NULL),  -- 1
('Rosa Maria', 'Huaman Flores', '2023-02-01', 'Activo', 2, 1),  -- 2
('Luis Fernando', 'Paredes Salas', '2023-03-15', 'Activo', 4, 1),  -- 3
('Ana Lucia', 'Vargas Condori', '2023-04-20', 'Activo', 5, 3),  -- 4
('Jorge Luis', 'Ramos Choque', '2023-06-05', 'Activo', 3, 3),  -- 5
('Patricia', 'Mamani Apaza', '2024-01-08', 'Activo', 6, 3),  -- 6
('Diana Carolina', 'Torres Cutipa', '2024-02-12', 'Activo', 7, 2),  -- 7
('Miguel Angel', 'Cuba Sulla', '2024-03-18', 'Activo', 8, 2),  -- 8
('Sofia Alejandra', 'Quispe Larico', '2024-07-01', 'Activo', 5, 3),  -- 9
('Raul Eduardo', 'Pinto Zevallos', '2025-01-20', 'Inactivo', 3, 3),  -- 10
('Marisol', 'Chambi Huanca', '2025-05-06', 'Activo', 7, 2),  -- 11
('Victor Hugo', 'Salazar Medina', '2022-11-14', 'Cesado', 6, 3),  -- 12
('Elena Beatriz', 'Nina Castro', '2026-10-19', 'Activo', 5, 3);  -- 13 (reciente)

-- REGISTRO_INDUCCION --------------------------------------------------
INSERT INTO registro_induccion
    (tipo_proceso, observaciones, fecha_induccion, firma_trabajador, id_trabajador)
VALUES
('General', 'Sin observaciones', '2023-01-11', 'firmas/trab_001.png', 1),  -- 1
('General', NULL, '2023-02-02', 'firmas/trab_002.png', 2),  -- 2
('Especifica', 'Induccion en pediatria', '2023-03-16', 'firmas/trab_003.png', 3),
('General', NULL, '2023-04-21', 'firmas/trab_004.png', 4),  -- 4
('Seguridad', 'Reforzar uso de EPP', '2023-06-06', 'firmas/trab_005.png', 5),  -- 5
('Especifica', NULL, '2024-01-09', 'firmas/trab_006.png', 6),  -- 6
('General', NULL, '2024-02-13', 'firmas/trab_007.png', 7),  -- 7
('Seguridad', 'Capacitacion en residuos', '2024-03-19', 'firmas/trab_008.png', 8),
('General', NULL, '2024-07-02', 'firmas/trab_009.png', 9),  -- 9
('Seguridad', 'Actualizacion bioseguridad', '2025-03-10', 'firmas/trab_004b.png', 4),
('General', NULL, '2025-05-07', 'firmas/trab_011.png', 11), -- 11
('General', 'Induccion de personal cesado', '2022-11-15', 'firmas/trab_012.png', 12);

-- DETALLE_INDUCCION ---------------------------------------------------
INSERT INTO detalle_induccion
    (id_induccion, id_detalle, id_documento, estado_cumplimiento, firma_responsable)
VALUES
(1,1,1,'Cumplido','firmas/rrhh_01.png'),
(1,2,2,'Cumplido','firmas/rrhh_01.png'),
(2,1,1,'Cumplido','firmas/rrhh_01.png'),
(2,2,2,'Cumplido','firmas/rrhh_01.png'),
(2,3,5,'Cumplido','firmas/rrhh_01.png'),
(3,1,2,'Cumplido','firmas/rrhh_02.png'),
(3,2,4,'Cumplido','firmas/rrhh_02.png'),
(4,1,2,'Cumplido','firmas/rrhh_02.png'),
(4,2,4,'Pendiente',NULL),
(5,1,3,'Cumplido','firmas/rrhh_02.png'),
(5,2,4,'Pendiente',NULL),
(6,1,4,'Cumplido','firmas/rrhh_03.png'),
(6,2,6,'Cumplido','firmas/rrhh_03.png'),
(7,1,1,'Cumplido','firmas/rrhh_03.png'),
(7,2,2,'Cumplido','firmas/rrhh_03.png'),
(7,3,5,'Pendiente',NULL),
(8,1,3,'Cumplido','firmas/rrhh_03.png'),
(8,2,6,'Pendiente',NULL),
(9,1,2,'Cumplido','firmas/rrhh_01.png'),
(9,2,4,'Cumplido','firmas/rrhh_01.png'),
(10,1,4,'Cumplido','firmas/rrhh_01.png'),
(10,2,3,'Cumplido','firmas/rrhh_01.png'),
(11,1,1,'Cumplido','firmas/rrhh_02.png'),
(11,2,5,'Cumplido','firmas/rrhh_02.png'),
(12,1,2,'Cumplido','firmas/rrhh_01.png');

-- ASISTENCIA ----------------------------------------------------------
-- Lunes 19 y martes 20 de octubre de 2026 (puntualidad: entrada hasta 08:05)
-- Nota: el trabajador 8 no marca el 20/10 y el 13 aun no registra marcaciones.
INSERT INTO asistencia
    (fecha_hora_marcacion, tipo_marcacion, estado_marcacion,
     id_trabajador, id_dispositivo)
VALUES
-- Lunes 19
('2026-10-19 07:55:10','Entrada', 'Puntual', 1,1),
('2026-10-19 17:02:40','Salida', 'Puntual', 1,1),
('2026-10-19 07:58:03','Entrada', 'Puntual', 2,1),
('2026-10-19 13:00:12','Refrigerio','Puntual', 2,1),
('2026-10-19 17:00:05','Salida', 'Puntual', 2,1),
('2026-10-19 08:12:45','Entrada', 'Tardanza',3,2),
('2026-10-19 17:30:20','Salida', 'Puntual', 3,2),
('2026-10-19 07:50:30','Entrada', 'Puntual', 4,1),
('2026-10-19 16:05:11','Salida', 'Puntual', 4,1),
('2026-10-19 08:03:00','Entrada', 'Puntual', 5,2),
('2026-10-19 16:30:44','Salida', 'Puntual', 5,2),
('2026-10-19 08:20:15','Entrada', 'Tardanza',6,1),
('2026-10-19 16:10:09','Salida', 'Puntual', 6,1),
('2026-10-19 07:45:00','Entrada', 'Puntual', 7,1),
('2026-10-19 16:00:30','Salida', 'Puntual', 7,1),
('2026-10-19 07:40:22','Entrada', 'Puntual', 8,1),
('2026-10-19 15:35:50','Salida', 'Puntual', 8,1),
('2026-10-19 08:15:33','Entrada', 'Tardanza',9,2),
('2026-10-19 16:20:18','Salida', 'Puntual', 9,2),
-- Martes 20
('2026-10-20 07:57:41','Entrada', 'Puntual', 1,1),
('2026-10-20 17:10:02','Salida', 'Puntual', 1,1),
('2026-10-20 08:30:10','Entrada', 'Tardanza',2,1),
('2026-10-20 17:05:55','Salida', 'Puntual', 2,1),
('2026-10-20 08:02:19','Entrada', 'Puntual', 3,2),
('2026-10-20 17:25:31','Salida', 'Puntual', 3,2),
('2026-10-20 08:10:05','Entrada', 'Tardanza',4,1),
('2026-10-20 16:08:42','Salida', 'Puntual', 4,1),
('2026-10-20 08:00:00','Entrada', 'Puntual', 5,2),
('2026-10-20 16:32:10','Salida', 'Puntual', 5,2),
('2026-10-20 08:25:48','Entrada', 'Tardanza',6,1),
('2026-10-20 16:15:27','Salida', 'Puntual', 6,1),
('2026-10-20 07:50:12','Entrada', 'Puntual', 7,1),
('2026-10-20 16:02:36','Salida', 'Puntual', 7,1),
('2026-10-20 08:18:50','Entrada', 'Tardanza',9,2),
('2026-10-20 16:25:03','Salida', 'Puntual', 9,2),
('2026-10-20 07:59:30','Entrada', 'Puntual', 11,1),
('2026-10-20 16:01:45','Salida', 'Puntual', 11,1);

-- Archivo: 04_procedimientos.sql

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

-- Archivo: 05_triggers.sql

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

-- Archivo: 06_procedimientos_complementarios.sql

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

-- Archivo: 07_instalacion.sql

-- El servicio solo queda listo después de instalar todos los objetos SQL.
USE registro_trabajadores;

CREATE TABLE instalacion_registro (
    version INT PRIMARY KEY
) ENGINE = InnoDB;

INSERT INTO instalacion_registro (version) VALUES (1);

-- Consultas C1 a C12 tal como se ejecutan desde el aplicativo.

SET @fecha_reporte = CAST('2026-10-19' AS DATE);

-- C1. Listado de trabajadores con cargo y supervisor (autojoin)

SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         c.nombre_cargo AS Cargo,
                         t.estado AS Estado,
                         IFNULL(CONCAT(s.nombres, ' ', s.apellidos), 'Sin supervisor') AS Supervisor
                  FROM trabajador t
                  INNER JOIN cargo c ON c.id_cargo = t.id_cargo
                  LEFT JOIN trabajador s ON s.id_trabajador = t.id_supervisor
                  ORDER BY t.id_trabajador;

-- C2. Cantidad de trabajadores activos por cargo

SELECT c.nombre_cargo AS Cargo,
                         COUNT(t.id_trabajador) AS Total_Activos
                  FROM cargo c
                  LEFT JOIN trabajador t ON t.id_cargo = c.id_cargo AND t.estado = 'Activo'
                  GROUP BY c.id_cargo, c.nombre_cargo
                  ORDER BY Total_Activos DESC, c.nombre_cargo;

-- C3. Marcaciones del día seleccionada con su sede/dispositivo

SELECT DATE(a.fecha_hora_marcacion) AS Fecha,
                         TIME(a.fecha_hora_marcacion) AS Hora,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         a.tipo_marcacion AS Tipo,
                         a.estado_marcacion AS Estado,
                         d.nombre_sede AS Sede
                  FROM asistencia a
                  INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
                  INNER JOIN sede_dispositivo d ON d.id_dispositivo = a.id_dispositivo
                  WHERE DATE(a.fecha_hora_marcacion) = @fecha_reporte
                  ORDER BY a.fecha_hora_marcacion;

-- C4. Trabajadores con 2 o más tardanzas en el mes de seleccionada

SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         COUNT(*) AS Total_Tardanzas
                  FROM asistencia a
                  INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
                  WHERE a.estado_marcacion = 'Tardanza'
                    AND a.fecha_hora_marcacion >= DATE_FORMAT(@fecha_reporte, '%Y-%m-01')
                    AND a.fecha_hora_marcacion <  DATE_ADD(DATE_FORMAT(@fecha_reporte, '%Y-%m-01'), INTERVAL 1 MONTH)
                  GROUP BY t.id_trabajador, t.nombres, t.apellidos
                  HAVING COUNT(*) >= 2
                  ORDER BY Total_Tardanzas DESC, Trabajador;

-- C5. Horas trabajadas por trabajador el día seleccionada

SELECT CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         DATE(a.fecha_hora_marcacion) AS Fecha,
                         MIN(CASE WHEN a.tipo_marcacion = 'Entrada' THEN a.fecha_hora_marcacion END) AS Entrada,
                         MAX(CASE WHEN a.tipo_marcacion = 'Salida' THEN a.fecha_hora_marcacion END) AS Salida,
                         ROUND(TIMESTAMPDIFF(MINUTE,
                               MIN(CASE WHEN a.tipo_marcacion = 'Entrada' THEN a.fecha_hora_marcacion END),
                               MAX(CASE WHEN a.tipo_marcacion = 'Salida' THEN a.fecha_hora_marcacion END)) / 60, 2) AS Horas_Trabajadas
                  FROM asistencia a
                  INNER JOIN trabajador t ON t.id_trabajador = a.id_trabajador
                  WHERE DATE(a.fecha_hora_marcacion) = @fecha_reporte
                  GROUP BY t.id_trabajador, t.nombres, t.apellidos, DATE(a.fecha_hora_marcacion)
                  ORDER BY Horas_Trabajadas DESC;

-- C6. Total de marcaciones por sede o dispositivo

SELECT d.nombre_sede AS Sede,
                         d.codigo_ip AS IP,
                         d.estado_dispositivo AS Estado,
                         COUNT(a.id_asistencia) AS Total_Marcaciones
                  FROM sede_dispositivo d
                  LEFT JOIN asistencia a ON a.id_dispositivo = d.id_dispositivo
                  GROUP BY d.id_dispositivo, d.nombre_sede, d.codigo_ip, d.estado_dispositivo
                  ORDER BY Total_Marcaciones DESC;

-- C7. Inducciones con documentos pendientes

SELECT CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         r.tipo_proceso AS Tipo_Proceso,
                         r.fecha_induccion AS Fecha_Induccion,
                         SUM(di.estado_cumplimiento = 'Cumplido') AS Cumplidos,
                         SUM(di.estado_cumplimiento = 'Pendiente') AS Pendientes
                  FROM registro_induccion r
                  INNER JOIN trabajador t ON t.id_trabajador = r.id_trabajador
                  INNER JOIN detalle_induccion di ON di.id_induccion = r.id_induccion
                  GROUP BY r.id_induccion, t.nombres, t.apellidos, r.tipo_proceso, r.fecha_induccion
                  HAVING SUM(di.estado_cumplimiento = 'Pendiente') > 0
                  ORDER BY r.fecha_induccion;

-- C8. Porcentaje de cumplimiento por documento de gestión

SELECT g.codigo_normativo AS Codigo,
                         g.titulo AS Documento,
                         COUNT(di.id_detalle) AS Veces_Revisado,
                         ROUND(100 * SUM(di.estado_cumplimiento = 'Cumplido') / COUNT(di.id_detalle), 1) AS Porcentaje_Cumplimiento
                  FROM documento_gestion g
                  INNER JOIN detalle_induccion di ON di.id_documento = g.id_documento
                  GROUP BY g.id_documento, g.codigo_normativo, g.titulo
                  ORDER BY Porcentaje_Cumplimiento ASC, g.codigo_normativo;

-- C9. Trabajadores activos sin inducciones registradas

SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         c.nombre_cargo AS Cargo
                  FROM trabajador t
                  INNER JOIN cargo c ON c.id_cargo = t.id_cargo
                  WHERE t.estado = 'Activo'
                    AND NOT EXISTS (SELECT 1 FROM registro_induccion r WHERE r.id_trabajador = t.id_trabajador)
                  ORDER BY t.id_trabajador;

-- C10. Trabajadores activos ausentes el día seleccionada (sin marcaciones)

SELECT t.id_trabajador AS ID,
                         CONCAT(t.nombres, ' ', t.apellidos) AS Trabajador,
                         c.nombre_cargo AS Cargo
                  FROM trabajador t
                  INNER JOIN cargo c ON c.id_cargo = t.id_cargo
                  WHERE t.estado = 'Activo'
                    AND NOT EXISTS (SELECT 1 FROM asistencia a
                                    WHERE a.id_trabajador = t.id_trabajador
                                      AND DATE(a.fecha_hora_marcacion) = @fecha_reporte)
                  ORDER BY t.id_trabajador;

-- C11. Supervisores y cantidad de trabajadores a su cargo (autojoin)

SELECT CONCAT(s.nombres, ' ', s.apellidos) AS Supervisor,
                         c.nombre_cargo AS Cargo_Supervisor,
                         COUNT(t.id_trabajador) AS Trabajadores_A_Cargo
                  FROM trabajador s
                  INNER JOIN cargo c ON c.id_cargo = s.id_cargo
                  INNER JOIN trabajador t ON t.id_supervisor = s.id_trabajador
                  GROUP BY s.id_trabajador, s.nombres, s.apellidos, c.nombre_cargo
                  ORDER BY Trabajadores_A_Cargo DESC, Supervisor;

-- C12. Bitácora de auditoría generada por los triggers (últimos 100 movimientos)

SELECT id_auditoria AS ID,
                         fecha_hora AS Fecha_Hora,
                         tabla AS Tabla,
                         operacion AS Operacion,
                         id_registro AS Registro,
                         detalle AS Detalle,
                         usuario_bd AS Usuario
                  FROM auditoria
                  ORDER BY id_auditoria DESC
                  LIMIT 100;
