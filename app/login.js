'use strict';

const formulario = document.querySelector('#login');
const mensaje = document.querySelector('#mensaje');
const boton = document.querySelector('#entrar');

formulario.addEventListener('submit', async evento => {
  evento.preventDefault();
  mensaje.hidden = true;
  boton.disabled = true;
  try {
    const respuesta = await fetch('/api/login', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(Object.fromEntries(new FormData(formulario))),
    });
    if (respuesta.ok) {
      location.replace('/');
      return;
    }
    const datos = await respuesta.json();
    mensaje.textContent = datos.error;
  } catch {
    mensaje.textContent = 'No se pudo contactar con el aplicativo. Inténtalo nuevamente.';
  } finally {
    boton.disabled = false;
  }
  formulario.elements.clave.value = '';
  formulario.elements.clave.focus();
  mensaje.hidden = false;
});
