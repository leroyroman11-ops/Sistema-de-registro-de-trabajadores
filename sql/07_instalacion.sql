-- El servicio solo queda listo después de instalar todos los objetos SQL.
USE registro_trabajadores;

CREATE TABLE instalacion_registro (
    version INT PRIMARY KEY
) ENGINE = InnoDB;

INSERT INTO instalacion_registro (version) VALUES (1);
