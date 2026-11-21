"""Credenciales del evaluador y sesiones temporales del aplicativo local."""

from http.cookies import CookieError, SimpleCookie
import hmac
import os
import secrets
from threading import Lock
from time import monotonic

COOKIE = 'registro_sesion'
DURACION = 8 * 60 * 60
ESPERA = 30
MAX_INTENTOS = 5
MAX_SESIONES = 128

_sesiones = {}
_intentos = 0
_bloqueo_hasta = 0
_lock = Lock()


def iniciar(usuario, clave):
    """Devuelve el estado HTTP y un token opaco si se autorizó el acceso."""
    if not isinstance(usuario, str) or not isinstance(clave, str):
        return 400, None
    if not usuario or not clave or len(usuario) > 100 or len(clave) > 256:
        return 400, None
    esperado = os.environ.get('REGISTRO_LOGIN_USUARIO', 'evaluador')
    secreto = os.environ.get('REGISTRO_LOGIN_CLAVE', 'RegistroDemo2026!')
    usuario_correcto = hmac.compare_digest(usuario.encode(), esperado.encode())
    clave_correcta = hmac.compare_digest(clave.encode(), secreto.encode())
    global _intentos, _bloqueo_hasta
    with _lock:
        ahora = monotonic()
        if ahora < _bloqueo_hasta:
            return 429, None
        if not (usuario_correcto and clave_correcta):
            _intentos += 1
            if _intentos >= MAX_INTENTOS:
                _intentos = 0
                _bloqueo_hasta = ahora + ESPERA
                return 429, None
            return 401, None
        _intentos = 0
        for token, vence in tuple(_sesiones.items()):
            if vence <= ahora:
                del _sesiones[token]
        if len(_sesiones) >= MAX_SESIONES:
            del _sesiones[next(iter(_sesiones))]
        token = secrets.token_urlsafe(32)
        _sesiones[token] = ahora + DURACION
        return 200, token


def leer_cookie(cabecera):
    """Extrae el identificador de sesión sin confiar en otros datos del cliente."""
    try:
        dato = SimpleCookie(cabecera or '').get(COOKIE)
    except CookieError:
        return None
    return dato.value if dato else None


def valida(token):
    """Comprueba la sesión en el servidor y elimina el identificador vencido."""
    with _lock:
        vence = _sesiones.get(token)
        if vence is None:
            return False
        if vence <= monotonic():
            del _sesiones[token]
            return False
        return True


def cerrar(token):
    with _lock:
        _sesiones.pop(token, None)


def cookie(token=None):
    edad = DURACION if token else 0
    return f'{COOKIE}={token or ""}; Path=/; HttpOnly; SameSite=Strict; Max-Age={edad}'
