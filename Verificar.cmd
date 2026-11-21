@echo off
cd /d "%~dp0"
docker compose --env-file "%LOCALAPPDATA%\RegistroTrabajadoresDockerMySQL\conexion.env" exec -T aplicacion python verificar.py
pause
