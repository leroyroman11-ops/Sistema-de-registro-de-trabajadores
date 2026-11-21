"""Abre la conexión por la red interna de Docker Compose."""
import os

import mysql.connector


def conectar():
    return mysql.connector.connect(
        host='base', port=3306, user='registro',
        password=os.environ['REGISTRO_CLAVE'], database='registro_trabajadores',
        charset='utf8mb4', use_pure=True, connection_timeout=6,
    )
