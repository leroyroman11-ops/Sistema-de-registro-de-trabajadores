# Software para registro de trabajadores

Aplicativo académico sin frameworks. El navegador muestra una interfaz HTML, CSS y JavaScript. Un servidor Python 3.12 atiende las solicitudes y se conecta a MySQL 8.4 mediante MySQL Connector/Python. Docker Compose administra los dos servicios y el volumen de datos.

## Inicio de sesión para evaluación

- Usuario: `evaluador`
- Contraseña: `RegistroDemo2026!`

La sesión se valida en el servidor y caduca a las ocho horas, al cerrar sesión o al reiniciar el proceso. Las rutas de datos, reportes, edición, eliminación y archivos personales requieren una sesión. La ruta de estado se usa para comprobar el arranque y devuelve el indicador de disponibilidad. El servicio se publica únicamente en el equipo local.

Para definir otras credenciales de evaluación, añada `REGISTRO_LOGIN_USUARIO` y `REGISTRO_LOGIN_CLAVE` al archivo local `%LOCALAPPDATA%\RegistroTrabajadoresDockerMySQL\conexion.env` y vuelva a ejecutar el iniciador. Ese archivo también contiene la contraseña de conexión a MySQL.

## Inicio en Windows

1. Abra Docker Desktop con el motor de contenedores Linux.
2. Desde esta carpeta, abra `RegistroTrabajadores.exe` o ejecute `Iniciar.cmd`.
3. Abra http://127.0.0.1:8766/ si el navegador no se abre automáticamente e inicie sesión. En el primer inicio se necesita Internet para descargar las imágenes y las dependencias.
4. Use `Verificar.cmd` mientras estén activos ambos servicios. `Detener.cmd` detiene el programa y conserva su volumen MySQL.

El ejecutable x64 es un iniciador. Python y MySQL se ejecutan dentro de Docker. El código objeto de Python 3.12 está en `objeto/`. El proyecto Compose no publica el puerto de la base de datos.

## Código fuente y flujo de operaciones

| Ruta | Función |
|---|---|
| `app/index.html`, `app/styles.css` | Estructura visual, formularios y estilo de los módulos. |
| `app/app.js` | Manejo de la API, formularios de catálogos, inducción y reportes. |
| `app/registro.js` | Registro por pasos, directorio, búsqueda y panel de indicadores. |
| `app/main.py` | Rutas HTTP, validación de entrada, procedimientos de escritura y manejo de transacciones. |
| `app/login.html`, `app/login.css` y `app/login.js` | Interfaz de acceso, validación del formulario y envío de credenciales. |
| `app/sesiones.py` | Verificación de credenciales, emisión y revocación de sesiones, caducidad y límite de intentos. |
| `app/requirements.txt` | Versión del conector de MySQL instalada por el Dockerfile. |
| `app/conexion.py` | Apertura de una conexión MySQL con las credenciales del entorno. |
| `app/reportes.py` | SQL de los doce reportes, parámetros de fecha y conversión a filas para la interfaz. |
| `app/verificar.py` | Prueba de integración de alta, modificación, validación y eliminación de un trabajador, auditoría y ejecución de reportes. Revierte sus datos de prueba. |
| `sql/01_crear_bd.sql`, `sql/02_insertar_datos.sql` | Tablas, claves y datos de ejemplo. |
| `sql/04_procedimientos.sql`, `sql/06_procedimientos_complementarios.sql` | Listado y operaciones de escritura, incluidas la cabecera y los documentos de inducción. |
| `sql/05_triggers.sql` | Reglas de negocio y bitácora. |
| `sql/07_instalacion.sql` | Marcador final de instalación que consulta el control de salud. |
| `inicio/` | Fuente y compilación del iniciador de Windows con GNU binutils. |

Las rutas de lectura consultan MySQL y devuelven JSON. Las rutas de escritura invocan procedimientos almacenados con parámetros. MySQL dispara las validaciones y las operaciones de auditoría. El servidor confirma la transacción al completar la operación. El guardado de una inducción incluye cabecera y detalles en una sola transacción.

En una instalación nueva, Docker carga los SQL individuales en el orden 01, 02, 04, 05, 06 y 07. El archivo 03 reúne consultas de referencia. El catálogo que se ejecuta en la aplicación está definido en `app/reportes.py`. También se entrega un script consolidado para revisión y ejecución manual en una instancia de prueba independiente.

## Pruebas

El primer arranque incluye 13 trabajadores, 8 cargos, 3 sedes con dispositivos, 6 documentos, 37 marcaciones y 12 inducciones. Los reportes de asistencia pueden probarse con el 19 o 20 de octubre de 2026. C12 empieza vacío porque los datos iniciales se cargan antes de crear los triggers. Luego lista las operaciones confirmadas en la base.

## Repositorio en GitHub

Este código está organizado para un repositorio de Git. El paquete de entrega contiene también una copia Git local en formato bundle y las instrucciones para publicarla. El enlace del repositorio remoto se obtiene después de publicar el código con una cuenta de GitHub.
