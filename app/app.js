'use strict';
/* Interfaz del sistema (JavaScript puro, sin librerias ni frameworks).
   Habla con main.py mediante una API JSON: cada guardar/eliminar termina
   en un procedimiento almacenado y los triggers validan en MySQL. */

// ---------------------------------------------------------------- utilidades
const $ = (sel, raiz = document) => raiz.querySelector(sel);

const pad = n => String(n).padStart(2, '0');
const hoy = () => { const d = new Date(); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`; };
const ahoraLocal = () => { const d = new Date(); return `${hoy()}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; };

/** Crea elementos DOM (los textos se insertan como texto: sin riesgo de inyeccion HTML). */
function h(etiqueta, atributos = {}, ...hijos) {
  const el = document.createElement(etiqueta);
  for (const [k, v] of Object.entries(atributos)) {
    if (k === 'class') el.className = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (v !== false && v !== null && v !== undefined) el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of hijos.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c.nodeType ? c : document.createTextNode(String(c)));
  }
  return el;
}

async function api(ruta, opciones = {}) {
  const resp = await fetch('/api/' + ruta, {
    headers: { 'Content-Type': 'application/json' },
    ...opciones,
  });
  if (resp.status === 401) {
    window.location.replace('/login');
    throw new Error('La sesión terminó. Vuelve a ingresar.');
  }
  let cuerpo = null;
  try { cuerpo = await resp.json(); } catch (e) { /* sin cuerpo */ }
  if (!resp.ok) throw new Error((cuerpo && cuerpo.error) || `Error ${resp.status}`);
  return cuerpo;
}

let temporizadorAlerta = null;
function alerta(texto, tipo = 'success') {
  const cont = $('#alerta');
  cont.replaceChildren(h('div', {
    class: `alert alert-${tipo === 'error' ? 'error' : 'success'}`,
    title: 'Clic para cerrar',
    onclick: () => cont.replaceChildren(),
  }, texto));
  clearTimeout(temporizadorAlerta);
  if (tipo !== 'error') temporizadorAlerta = setTimeout(() => cont.replaceChildren(), 6000);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

const nulo = (texto = 'NULL') => h('span', { class: 'nulo' }, texto);
const valorCelda = v => (v === null || v === undefined || v === '' ? nulo() : String(v));

function badge(texto, clase) { return h('span', { class: `badge ${clase}` }, texto); }
const badgeEstado = e => badge(e, { Activo: 'cumplido', Inactivo: 'pendiente', Cesado: 'neutro' }[e] || 'neutro');

// ---------------------------------------------------------------- estado global
const datos = { trabajadores: [], cargos: [], documentos: [], sedes: [], asistencia: [], inducciones: [] };
const vistas = [];   // funciones que repintan tablas y listas desplegables

async function recargarTodo() {
  const recursos = Object.keys(datos);
  const listas = await Promise.all(recursos.map(r => api(r)));
  recursos.forEach((r, i) => { datos[r] = listas[i]; });
  vistas.forEach(v => v());
}

// ---------------------------------------------------------------- esquemas CRUD
const opCargos = () => [['', '— Seleccione un cargo —'],
  ...datos.cargos.map(c => [c.id_cargo, `${c.id_cargo} - ${c.nombre_cargo}`])];
const opTrabajadores = () => [['', '— Seleccione al trabajador —'],
  ...datos.trabajadores.map(t => [t.id_trabajador, `${t.id_trabajador} - ${t.nombres} ${t.apellidos} (${t.estado})`])];
const opSupervisores = () => [['', '— Sin supervisor —'],
  ...datos.trabajadores.map(t => [t.id_trabajador, `${t.id_trabajador} - ${t.nombres} ${t.apellidos} (${t.cargo})`])];
const opSedes = () => datos.sedes.map(s => [s.id_dispositivo, `${s.id_dispositivo} - ${s.nombre_sede} (${s.codigo_ip} · ${s.estado_dispositivo})`]);

const ESQUEMAS = {
  trabajadores: {
    pk: 'id_trabajador',
    etiqueta: f => `al trabajador ${f.nombres} ${f.apellidos}`,
    campos: [
      { n: 'nombres', l: 'Nombres', t: 'text', req: true, max: 100, ph: 'Ej. Carlos Alberto' },
      { n: 'apellidos', l: 'Apellidos', t: 'text', req: true, max: 100, ph: 'Ej. Mendoza Quispe' },
      { n: 'fecha_registro', l: 'Fecha de registro', t: 'date', req: true, def: hoy },
      { n: 'estado', l: 'Estado laboral', t: 'select', req: true, op: ['Activo', 'Inactivo', 'Cesado'] },
      { n: 'id_cargo', l: 'Cargo asignado', t: 'select', req: true, op: opCargos },
      { n: 'id_supervisor', l: 'Supervisor / jefe inmediato (opcional)', t: 'select', op: opSupervisores },
    ],
    columnas: [
      { n: 'id_trabajador', l: 'ID' }, { n: 'nombres', l: 'Nombres' }, { n: 'apellidos', l: 'Apellidos' },
      { n: 'fecha_registro', l: 'Fecha registro' },
      { n: 'estado', l: 'Estado', f: f => badgeEstado(f.estado) },
      { n: 'cargo', l: 'Cargo' },
      { n: 'supervisor', l: 'Supervisor', f: f => f.supervisor || nulo('Sin supervisor') },
    ],
  },
  cargos: {
    pk: 'id_cargo',
    etiqueta: f => `el cargo ${f.nombre_cargo}`,
    campos: [
      { n: 'nombre_cargo', l: 'Nombre del cargo', t: 'text', req: true, max: 100, ph: 'Ej. Médico Especialista' },
      { n: 'nivel_estructural', l: 'Nivel estructural', t: 'select', req: true, def: () => 'Operativo',
        op: ['Directivo', 'Jefatura', 'Operativo', 'Administrativo', 'Apoyo'] },
      { n: 'descripcion', l: 'Descripción de funciones (opcional)', t: 'textarea', max: 255, ancho: true },
    ],
    columnas: [
      { n: 'id_cargo', l: 'ID' }, { n: 'nombre_cargo', l: 'Nombre del cargo' },
      { n: 'nivel_estructural', l: 'Nivel estructural' }, { n: 'descripcion', l: 'Descripción' },
    ],
  },
  documentos: {
    pk: 'id_documento',
    etiqueta: f => `el documento ${f.codigo_normativo}`,
    campos: [
      { n: 'codigo_normativo', l: 'Código normativo único', t: 'text', req: true, max: 50, ph: 'Ej. PIG-001' },
      { n: 'titulo', l: 'Título oficial', t: 'text', req: true, max: 150, ph: 'Ej. Política Integrada de Gestión' },
      { n: 'version', l: 'Versión', t: 'text', req: true, max: 20, def: () => '1.0' },
      { n: 'fecha_aprobacion', l: 'Fecha de aprobación', t: 'date', req: true, def: hoy },
    ],
    columnas: [
      { n: 'id_documento', l: 'ID' }, { n: 'codigo_normativo', l: 'Código' }, { n: 'titulo', l: 'Título' },
      { n: 'version', l: 'Versión' }, { n: 'fecha_aprobacion', l: 'Fecha aprobación' },
    ],
  },
  asistencia: {
    pk: 'id_asistencia',
    etiqueta: f => `la marcación #${f.id_asistencia}`,
    campos: [
      { n: 'id_trabajador', l: 'Trabajador', t: 'select', req: true, op: opTrabajadores },
      { n: 'id_dispositivo', l: 'Sede / dispositivo biométrico', t: 'select', req: true, op: opSedes },
      { n: 'fecha_hora_marcacion', l: 'Fecha y hora', t: 'datetime-local', req: true, def: ahoraLocal },
      { n: 'tipo_marcacion', l: 'Tipo de marcación', t: 'select', req: true, op: ['Entrada', 'Refrigerio', 'Salida'] },
      { n: 'estado_marcacion', l: 'Estado de marcación', t: 'select', req: true, op: ['Puntual', 'Tardanza'],
        nota: 'Los triggers lo recalculan: Entrada después de 08:05 = Tardanza.' },
    ],
    columnas: [
      { n: 'id_asistencia', l: 'ID' }, { n: 'fecha_hora_marcacion', l: 'Fecha y hora' },
      { n: 'trabajador', l: 'Trabajador' }, { n: 'nombre_sede', l: 'Sede' }, { n: 'tipo_marcacion', l: 'Tipo' },
      { n: 'estado_marcacion', l: 'Estado',
        f: f => badge(f.estado_marcacion, f.estado_marcacion === 'Tardanza' ? 'tardanza' : 'puntual') },
    ],
  },
  sedes: {
    pk: 'id_dispositivo',
    etiqueta: f => `la sede ${f.nombre_sede}`,
    campos: [
      { n: 'nombre_sede', l: 'Nombre de la sede', t: 'text', req: true, max: 100, ph: 'Ej. Sky Tower' },
      { n: 'direccion', l: 'Dirección física', t: 'text', req: true, max: 200, ph: 'Ej. Av. Ejército 1009, Yanahuara' },
      { n: 'codigo_ip', l: 'Dirección IP del dispositivo', t: 'text', req: true, max: 45, ph: 'Ej. 192.168.1.10',
        pattern: '^[0-9]{1,3}(\\.[0-9]{1,3}){3}$', title: 'Formato IPv4, por ejemplo 192.168.1.10' },
      { n: 'estado_dispositivo', l: 'Estado operativo', t: 'select', req: true, op: ['Activo', 'Mantenimiento', 'Inactivo'] },
    ],
    columnas: [
      { n: 'id_dispositivo', l: 'ID' }, { n: 'nombre_sede', l: 'Sede' }, { n: 'direccion', l: 'Dirección' },
      { n: 'codigo_ip', l: 'IP' }, { n: 'estado_dispositivo', l: 'Estado' },
    ],
  },
};

// ---------------------------------------------------------------- controles de formulario
function crearControl(c) {
  if (c.t === 'select') return h('select', { name: c.n, required: c.req });
  if (c.t === 'textarea') return h('textarea', { name: c.n, rows: 2, maxlength: c.max });
  return h('input', {
    type: c.t, name: c.n, required: c.req, maxlength: c.max, placeholder: c.ph,
    pattern: c.pattern, title: c.title, step: c.t === 'datetime-local' ? 1 : null,
  });
}

function llenarSelect(el, c) {
  const previo = el.value;
  const ops = typeof c.op === 'function' ? c.op() : c.op;
  el.replaceChildren(...ops.map(o => {
    const [valor, texto] = Array.isArray(o) ? o : [o, o];
    return h('option', { value: valor }, texto);
  }));
  if ([...el.options].some(o => o.value === previo)) el.value = previo;
}

function envolver(c, control) {
  return h('label', { class: 'campo' + (c.ancho ? ' campo-ancho' : '') },
    h('span', {}, c.l, c.req ? h('span', { class: 'req' }, ' *') : null),
    control,
    c.nota ? h('span', { class: 'nota' }, c.nota) : null);
}

function valorParaControl(c, v) {
  if (v === null || v === undefined) return '';
  if (c.t === 'datetime-local') return String(v).replace(' ', 'T');
  if (c.t === 'date') return String(v).slice(0, 10);
  return String(v);
}

// ---------------------------------------------------------------- CRUD generico
function crearCrud(recurso, contenedor) {
  const esq = ESQUEMAS[recurso];
  let idEdicion = null;
  const ctl = {};

  const aviso = h('div', { class: 'modo-edicion', hidden: true });
  const form = h('form', { class: 'form-grid', autocomplete: 'off' });
  form.append(aviso);
  for (const c of esq.campos) {
    ctl[c.n] = crearControl(c);
    form.append(envolver(c, ctl[c.n]));
  }
  const btnGuardar = h('button', { type: 'submit', class: 'btn-primary' }, 'Guardar');
  const btnLimpiar = h('button', { type: 'button', class: 'btn-secondary', onclick: () => limpiar() }, 'Limpiar / Nuevo');
  form.append(h('div', { class: 'form-actions' }, btnGuardar, btnLimpiar));

  const tbody = h('tbody');
  const contador = h('p', { class: 'contador' });
  const tabla = h('table', {},
    h('thead', {}, h('tr', {}, esq.columnas.map(c => h('th', {}, c.l)), h('th', {}, 'Acciones'))),
    tbody);
  contenedor.append(form, contador, h('div', { class: 'tabla-scroll' }, tabla));

  function llenarListas() {
    esq.campos.filter(c => c.t === 'select').forEach(c => llenarSelect(ctl[c.n], c));
  }

  function limpiar() {
    form.reset();
    idEdicion = null;
    aviso.hidden = true;
    btnGuardar.textContent = 'Guardar';
    esq.campos.forEach(c => { if (c.def) ctl[c.n].value = c.def(); });
  }

  function editar(fila) {
    esq.campos.forEach(c => { ctl[c.n].value = valorParaControl(c, fila[c.n]); });
    idEdicion = fila[esq.pk];
    aviso.textContent = `Editando el registro #${idEdicion}. Pulse "Limpiar / Nuevo" para cancelar.`;
    aviso.hidden = false;
    btnGuardar.textContent = 'Actualizar';
    form.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  async function eliminar(fila) {
    if (!confirm(`¿Eliminar ${esq.etiqueta(fila)}?`)) return;
    try {
      const r = await api(`${recurso}/${fila[esq.pk]}`, { method: 'DELETE' });
      alerta(r.mensaje);
      if (idEdicion === fila[esq.pk]) limpiar();
      await recargarTodo();
    } catch (e) { alerta(e.message, 'error'); }
  }

  form.addEventListener('submit', async ev => {
    ev.preventDefault();
    const payload = { [esq.pk]: idEdicion };
    esq.campos.forEach(c => { payload[c.n] = ctl[c.n].value; });
    try {
      const r = await api(recurso, { method: 'POST', body: JSON.stringify(payload) });
      alerta(r.mensaje);
      limpiar();
      await recargarTodo();
    } catch (e) { alerta(e.message, 'error'); }
  });

  function pintar() {
    const filas = datos[recurso];
    contador.textContent = `${filas.length} registro(s)`;
    if (!filas.length) {
      tbody.replaceChildren(h('tr', {}, h('td', { colspan: esq.columnas.length + 1, class: 'vacio' }, 'Sin registros')));
      return;
    }
    tbody.replaceChildren(...filas.map(fila => h('tr', {},
      esq.columnas.map(c => h('td', {}, c.f ? c.f(fila) : valorCelda(fila[c.n]))),
      h('td', {}, h('div', { class: 'actions' },
        h('button', { type: 'button', class: 'btn-edit', onclick: () => editar(fila) }, 'Editar'),
        h('button', { type: 'button', class: 'btn-delete', onclick: () => eliminar(fila) }, 'Eliminar'))))));
  }

  vistas.push(() => { llenarListas(); pintar(); });
  llenarListas();
  limpiar();
}

// ---------------------------------------------------------------- inducciones (maestro-detalle)
function crearInducciones() {
  const cont = $('#induccion-app');
  let idEdicion = null;

  const cab = [
    { n: 'id_trabajador', l: 'Trabajador', t: 'select', req: true, op: opTrabajadores },
    { n: 'tipo_proceso', l: 'Tipo de proceso', t: 'select', req: true, op: [['General', 'General'],
      ['Especifica', 'Específica'], ['Seguridad', 'Seguridad'], ['Reinduccion', 'Reinducción']] },
    { n: 'fecha_induccion', l: 'Fecha de inducción', t: 'date', req: true, def: hoy },
    { n: 'firma_trabajador', l: 'Ruta / validación de firma del trabajador', t: 'text', req: true, max: 255, ph: 'Ej. firmas/trab_013.png' },
    { n: 'observaciones', l: 'Observaciones (opcional)', t: 'textarea', max: 255, ancho: true },
  ];
  const ctl = {};
  const aviso = h('div', { class: 'modo-edicion', hidden: true });
  const form = h('form', { class: 'form-grid', autocomplete: 'off' });
  form.append(aviso);
  for (const c of cab) { ctl[c.n] = crearControl(c); form.append(envolver(c, ctl[c.n])); }

  // --- detalle
  const cuerpoDetalle = h('tbody');
  const opDocs = () => datos.documentos.map(d => [d.id_documento, `${d.codigo_normativo} - ${d.titulo}`]);

  function renumerar() {
    [...cuerpoDetalle.rows].forEach((tr, i) => { tr.cells[0].textContent = i + 1; });
  }

  function agregarFila(d = {}) {
    const selDoc = h('select', { required: true });
    llenarSelect(selDoc, { op: opDocs });
    if (d.id_documento) selDoc.value = d.id_documento;
    const selEst = h('select', { required: true }, h('option', { value: 'Cumplido' }, 'Cumplido'),
      h('option', { value: 'Pendiente' }, 'Pendiente'));
    if (d.estado_cumplimiento) selEst.value = d.estado_cumplimiento;
    const firma = h('input', { type: 'text', maxlength: 255, placeholder: 'Ej. firmas/rrhh_01.png' });
    firma.value = d.firma_responsable || '';
    const sincronizar = () => {
      const pendiente = selEst.value === 'Pendiente';
      firma.disabled = pendiente;
      if (pendiente) firma.value = '';
    };
    selEst.addEventListener('change', sincronizar);
    sincronizar();
    const tr = h('tr', {}, h('td'), h('td', {}, selDoc), h('td', {}, selEst), h('td', {}, firma),
      h('td', {}, h('button', { type: 'button', class: 'btn-delete', onclick: () => { tr.remove(); renumerar(); } }, 'Quitar')));
    tr._ctl = { selDoc, selEst, firma };
    cuerpoDetalle.append(tr);
    renumerar();
  }

  const cajaDetalle = h('div', { class: 'detalle-box' },
    h('h3', {}, 'Documentos revisados en la sesión (detalle_induccion)'),
    h('p', { class: 'nota' }, 'Un documento "Cumplido" exige la firma del responsable; uno "Pendiente" no la lleva (lo valida un trigger).'),
    h('div', { class: 'tabla-scroll' }, h('table', {},
      h('thead', {}, h('tr', {}, ['N.º', 'Documento de gestión', 'Estado', 'Firma del responsable', ''].map(t => h('th', {}, t)))),
      cuerpoDetalle)),
    h('button', { type: 'button', class: 'btn-secondary', onclick: () => agregarFila() }, '+ Agregar documento'));
  form.append(cajaDetalle);

  const btnGuardar = h('button', { type: 'submit', class: 'btn-primary' }, 'Registrar inducción completa');
  form.append(h('div', { class: 'form-actions' }, btnGuardar,
    h('button', { type: 'button', class: 'btn-secondary', onclick: () => limpiar() }, 'Limpiar / Nueva')));

  function limpiar() {
    form.reset();
    idEdicion = null;
    aviso.hidden = true;
    btnGuardar.textContent = 'Registrar inducción completa';
    cab.forEach(c => { if (c.def) ctl[c.n].value = c.def(); });
    cuerpoDetalle.replaceChildren();
    agregarFila();
  }

  async function editar(ind) {
    try {
      const r = await api(`inducciones/${ind.id_induccion}`);
      cab.forEach(c => { ctl[c.n].value = valorParaControl(c, r.cabecera[c.n]); });
      cuerpoDetalle.replaceChildren();
      r.detalles.forEach(d => agregarFila(d));
      if (!r.detalles.length) agregarFila();
      idEdicion = ind.id_induccion;
      aviso.textContent = `Editando la inducción #${idEdicion}. Al guardar se reemplaza su detalle.`;
      aviso.hidden = false;
      btnGuardar.textContent = 'Actualizar inducción';
      form.scrollIntoView({ behavior: 'smooth', block: 'start' });
    } catch (e) { alerta(e.message, 'error'); }
  }

  async function eliminar(ind) {
    if (!confirm(`¿Eliminar la inducción #${ind.id_induccion} de ${ind.trabajador} y todo su detalle?`)) return;
    try {
      const r = await api(`inducciones/${ind.id_induccion}`, { method: 'DELETE' });
      alerta(r.mensaje);
      if (idEdicion === ind.id_induccion) limpiar();
      await recargarTodo();
    } catch (e) { alerta(e.message, 'error'); }
  }

  form.addEventListener('submit', async ev => {
    ev.preventDefault();
    const payload = { id_induccion: idEdicion };
    cab.forEach(c => { payload[c.n] = ctl[c.n].value; });
    payload.detalles = [...cuerpoDetalle.rows].map(tr => ({
      id_documento: tr._ctl.selDoc.value,
      estado_cumplimiento: tr._ctl.selEst.value,
      firma_responsable: tr._ctl.firma.value,
    }));
    try {
      const r = await api('inducciones', { method: 'POST', body: JSON.stringify(payload) });
      alerta(r.mensaje);
      limpiar();
      await recargarTodo();
    } catch (e) { alerta(e.message, 'error'); }
  });

  // --- tabla
  const tbody = h('tbody');
  const contador = h('p', { class: 'contador' });
  const tabla = h('table', {},
    h('thead', {}, h('tr', {}, ['ID', 'Trabajador', 'Tipo', 'Fecha', 'Docs', 'Pendientes', 'Observaciones', 'Acciones']
      .map(t => h('th', {}, t)))), tbody);
  cont.append(form, h('h3', {}, 'Inducciones registradas'), contador, h('div', { class: 'tabla-scroll' }, tabla));

  function pintar() {
    const filas = datos.inducciones;
    contador.textContent = `${filas.length} inducción(es)`;
    if (!filas.length) {
      tbody.replaceChildren(h('tr', {}, h('td', { colspan: 8, class: 'vacio' }, 'Sin registros')));
      return;
    }
    tbody.replaceChildren(...filas.map(ind => h('tr', {},
      h('td', {}, ind.id_induccion), h('td', {}, ind.trabajador), h('td', {}, ind.tipo_proceso),
      h('td', {}, ind.fecha_induccion), h('td', {}, ind.total_docs),
      h('td', {}, Number(ind.pendientes) > 0 ? badge(ind.pendientes, 'pendiente') : badge('0', 'cumplido')),
      h('td', {}, valorCelda(ind.observaciones)),
      h('td', {}, h('div', { class: 'actions' },
        h('button', { type: 'button', class: 'btn-edit', onclick: () => editar(ind) }, 'Editar'),
        h('button', { type: 'button', class: 'btn-delete', onclick: () => eliminar(ind) }, 'Eliminar'))))));
  }

  function llenarListas() {
    cab.filter(c => c.t === 'select').forEach(c => llenarSelect(ctl[c.n], c));
    [...cuerpoDetalle.rows].forEach(tr => llenarSelect(tr._ctl.selDoc, { op: opDocs }));
  }

  vistas.push(() => { llenarListas(); pintar(); });
  llenarListas();
  limpiar();
}

// ---------------------------------------------------------------- reportes
function crearReportes() {
  const selCodigo = $('#rep-codigo');
  const inpFecha = $('#rep-fecha');
  const ayuda = $('#rep-ayuda');
  const titulo = $('#rep-titulo');
  const resultado = $('#rep-resultado');
  let catalogo = [];
  let ultimo = null;
  let cargado = false;

  inpFecha.value = '2026-10-19';   // los datos de ejemplo de asistencia son del 19 y 20/10/2026

  function actualizarAyuda() {
    const r = catalogo.find(x => x.codigo === selCodigo.value);
    if (!r) return;
    inpFecha.disabled = !r.usa_fecha;
    ayuda.textContent = r.usa_fecha
      ? 'Este reporte usa la fecha del filtro (los datos de ejemplo de asistencia son del 19 y 20/10/2026).'
      : 'Este reporte no usa filtro de fecha.';
  }

  async function ejecutar() {
    try {
      const r = await api(`reportes/${selCodigo.value}?fecha=${encodeURIComponent(inpFecha.value)}`);
      ultimo = r;
      titulo.textContent = r.titulo;
      if (!r.filas.length) {
        resultado.replaceChildren(h('p', { class: 'vacio' }, 'No se encontraron registros para los criterios seleccionados.'));
        return;
      }
      resultado.replaceChildren(h('table', {},
        h('thead', {}, h('tr', {}, r.columnas.map(c => h('th', {}, c.replaceAll('_', ' '))))),
        h('tbody', {}, r.filas.map(f => h('tr', {}, r.columnas.map(c => h('td', {}, valorCelda(f[c]))))))));
    } catch (e) { alerta(e.message, 'error'); }
  }

  function exportarCsv() {
    if (!ultimo || !ultimo.filas.length) { alerta('Ejecute primero un reporte con resultados.', 'error'); return; }
    const esc = v => `"${String(v ?? '').replaceAll('"', '""')}"`;
    const lineas = [ultimo.columnas.map(esc).join(';'),
      ...ultimo.filas.map(f => ultimo.columnas.map(c => esc(f[c])).join(';'))];
    const blob = new Blob(['\ufeff' + lineas.join('\r\n')], { type: 'text/csv;charset=utf-8' });
    const a = h('a', { href: URL.createObjectURL(blob), download: `reporte_${selCodigo.value}.csv` });
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  $('#rep-ejecutar').addEventListener('click', ejecutar);
  $('#rep-csv').addEventListener('click', exportarCsv);
  $('#rep-imprimir').addEventListener('click', () => window.print());
  selCodigo.addEventListener('change', () => { actualizarAyuda(); ejecutar(); });
  inpFecha.addEventListener('change', ejecutar);

  return async function activar() {
    if (cargado) { await ejecutar(); return; }
    try {
      catalogo = await api('reportes');
      selCodigo.replaceChildren(...catalogo.map(r =>
        h('option', { value: r.codigo }, r.nombre + (r.con_join ? '  [JOIN]' : ''))));
      cargado = true;
      actualizarAyuda();
      await ejecutar();
    } catch (e) { alerta(e.message, 'error'); }
  };
}

// ---------------------------------------------------------------- arranque
async function iniciar() {
  document.querySelectorAll('[data-crud]').forEach(div => crearCrud(div.dataset.crud, div));
  iniciarFicha();
  crearInducciones();
  const activarReportes = crearReportes();

  document.querySelectorAll('#tabs .tab-btn').forEach(btn => btn.addEventListener('click', () => {
    document.querySelectorAll('#tabs .tab-btn').forEach(b => b.classList.toggle('active', b === btn));
    document.querySelectorAll('.tab-content').forEach(s => s.classList.toggle('active', s.id === `tab-${btn.dataset.tab}`));
    $('#titulo').textContent = btn.dataset.tab === 'trabajadores' ? 'Registro de Trabajadores' : btn.textContent.slice(1);
    if (btn.dataset.tab === 'reportes') activarReportes();
  }));

  try {
    await recargarTodo();
  } catch (e) {
    alerta(e.message, 'error');
  }
}

document.addEventListener('DOMContentLoaded', iniciar);


document.addEventListener('DOMContentLoaded', () => {
  const cerrar = document.querySelector('#cerrar-sesion');
  cerrar?.addEventListener('click', async () => {
    cerrar.disabled = true;
    try {
      await api('logout', {method: 'POST', body: '{}'});
      window.location.replace('/login');
    } catch (error) {
      alerta(error.message, 'error');
      cerrar.disabled = false;
    }
  });
});
