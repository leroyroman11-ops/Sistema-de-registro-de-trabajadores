@echo off
cd /d "%~dp0"
docker compose --env-file "%LOCALAPPDATA%\RegistroTrabajadoresDockerMySQL\conexion.env" stop
if errorlevel 1 pause
