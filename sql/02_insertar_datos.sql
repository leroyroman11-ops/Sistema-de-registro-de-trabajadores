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
