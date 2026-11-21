"""Genera el acceso directo relativo de la carpeta ejecutable (MS-SHLLINK)."""
from pathlib import Path
from struct import pack
from uuid import UUID


def crear_acceso(carpeta):
    destino = r'.\RegistroTrabajadores.exe'
    flags = 0x8 | 0x80  # HasRelativePath + IsUnicode
    encabezado = pack('<I16sIIQQQIiIHHII', 76,
                      UUID('00021401-0000-0000-c000-000000000046').bytes_le,
                      flags, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0)
    ruta = carpeta / 'Software para registro de trabajadores.lnk'
    ruta.write_bytes(encabezado + pack('<H', len(destino)) +
                     destino.encode('utf-16le') + pack('<I', 0))


if __name__ == '__main__':
    crear_acceso(Path(__file__).resolve().parent.parent)
