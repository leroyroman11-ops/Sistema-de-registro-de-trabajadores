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
