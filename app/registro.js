'use strict';
// La ficha conserva los cambios en el formulario hasta que se confirma el tercer paso.
function iniciarFicha() {
  const form = $('#ficha'), campo = form.elements;
  const pasos = [...form.querySelectorAll('.paso')];
  let paso = 0, trabajador = null, vistaFoto = null;
  const navegar = id => document.querySelector('[data-tab="' + id + '"]').click();
  function foto(url) {
    $('#previa').replaceChildren(url ? h('img', {src: url, alt: 'Foto de perfil'}) : '＋');
  }
  function cambiarPaso(numero) {
    paso = numero;
    pasos.forEach((p, i) => { p.hidden = i !== paso; });
    document.querySelectorAll('.pasos li').forEach((p, i) => { p.className = i === paso ? 'actual' : i < paso ? 'hecho' : ''; });
    $('#atras').hidden = paso === 0;
    $('#avanzar').textContent = paso === 2 ? 'Guardar trabajador' : 'Siguiente paso →';
    $('#resumen-empleo').textContent = [campo.nombres.value, campo.apellidos.value].join(' ') + ' · ' + (campo.id_cargo.selectedOptions[0]?.textContent || '');
    $('#revision').textContent = 'Trabajador: ' + campo.nombres.value + ' ' + campo.apellidos.value + ' · ' + campo.estado.value;
  }
  function listas() {
    llenarSelect(campo.id_cargo, {op: opCargos});
    llenarSelect(campo.id_supervisor, {op: () => opSupervisores().filter(([id]) => id !== trabajador?.id_trabajador)});
  }
  function cargar(t = null) {
    trabajador = t;
    form.reset();
    if (vistaFoto) URL.revokeObjectURL(vistaFoto);
    vistaFoto = null;
    listas();
    campo.fecha_registro.value = hoy();
    if (t) for (const el of campo) {
      if (el.name && el.type !== 'file' && Object.hasOwn(t, el.name)) el.value = t[el.name] ?? '';
    }
    foto(t?.tiene_foto ? '/api/trabajadores/' + t.id_trabajador + '/foto' : null);
    $('#archivo-actual').replaceChildren(t?.nombre_adjunto ? h('a', {href: '/api/trabajadores/' + t.id_trabajador + '/adjunto'}, t.nombre_adjunto) : '');
    $('#editando').hidden = !t;
    $('#editando').textContent = t ? 'Editando la ficha de ' + t.nombres + ' ' + t.apellidos : '';
    campo.identificacion.setCustomValidity('');
    cambiarPaso(0);
  }
  function editar(t) { cargar(t); navegar('trabajadores'); }
  function avatar(t) {
    return h('span', {class:'avatar'}, t.tiene_foto ? h('img',{src:'/api/trabajadores/'+t.id_trabajador+'/foto',alt:''}) : (t.nombres[0]+t.apellidos[0]).toUpperCase());
  }
  async function eliminar(t) {
    if (!confirm('¿Eliminar la ficha de ' + t.nombres + ' ' + t.apellidos + '?')) return;
    try {
      const r = await api('trabajadores/' + t.id_trabajador, {method:'DELETE'});
      if (trabajador?.id_trabajador === t.id_trabajador) cargar();
      await recargarTodo(); alerta(r.mensaje);
    } catch (e) { alerta(e.message,'error'); }
  }
  function directorio() {
    const q = $('#busqueda').value.trim().toLocaleLowerCase('es');
    const filas = datos.trabajadores.filter(t => [t.nombres+' '+t.apellidos,t.cargo,t.identificacion].some(v => String(v || '').toLocaleLowerCase('es').includes(q)));
    $('#directorio').replaceChildren(filas.length ? h('table',{},h('thead',{},h('tr',{},['Trabajador','Cargo','Ingreso','Estado','Acciones'].map(x=>h('th',{},x)))),
      h('tbody',{},filas.map(t=>h('tr',{},h('td',{},t.nombres+' '+t.apellidos),h('td',{},t.cargo),h('td',{},t.fecha_registro),h('td',{},badgeEstado(t.estado)),h('td',{},h('div',{class:'actions'},
        h('button',{class:'btn-edit',onclick:()=>editar(t)},'Editar'),h('button',{class:'btn-delete',onclick:()=>eliminar(t)},'Eliminar'))))))) : h('p',{},'No se encontraron trabajadores.'));
  }
  function pintar() {
    listas(); directorio();
    const ultimos = [...datos.trabajadores].sort((a,b)=>b.id_trabajador-a.id_trabajador).slice(0,4);
    $('#recientes').replaceChildren(...ultimos.map(t=>h('button',{class:'persona',onclick:()=>editar(t)},avatar(t),h('span',{},h('strong',{},t.nombres+' '+t.apellidos),h('small',{},t.cargo),badgeEstado(t.estado)))));
    if (!ultimos.length) $('#recientes').textContent='Aún no hay trabajadores registrados.';
    pintarPanel();
  }

  const nombre = t => t.nombres + ' ' + t.apellidos;
  const estados = [
    ['Activo', 'Activos', 'verde'],
    ['Inactivo', 'Inactivos', 'ambar'],
    ['Cesado', 'Cesados', 'gris'],
  ];
  const formatoFecha = new Intl.DateTimeFormat('es-PE', {dateStyle:'long'});
  $('#fecha-panel').textContent = formatoFecha.format(new Date());
  document.querySelectorAll('[data-ir]').forEach(btn => {
    btn.onclick = () => {
      if (btn.dataset.ir === 'trabajadores') cargar();
      if (btn.dataset.ir === 'directorio') {
        $('#busqueda').value = '';
        directorio();
      }
      navegar(btn.dataset.ir);
    };
  });

  function pintarPanel() {
    const total = datos.trabajadores.length;
    const contar = estado => datos.trabajadores.filter(t => t.estado === estado).length;
    const conPendientes = datos.inducciones.filter(i => Number(i.pendientes) > 0).length;
    const hoyLocal = hoy();
    const marcaciones = datos.asistencia.filter(a => a.fecha_hora_marcacion.startsWith(hoyLocal)).length;
    const tarjetas = [
      ['Personal registrado', total, 'directorio', '☷', 'Fichas del directorio'],
      ['Trabajadores activos', contar('Activo'), 'directorio', '✓', 'Estado laboral activo'],
      ['Marcaciones de hoy', marcaciones, 'asistencia', '◷', 'Entradas, salidas y refrigerios'],
      ['Inducciones pendientes', conPendientes, 'inducciones', '☑', 'Con documentos por completar'],
    ];
    $('#metricas').replaceChildren(...tarjetas.map(([rotulo, valor, tab, icono, detalle]) =>
      h('button', {class:'metrica', onclick:() => {
        if (tab === 'directorio') { $('#busqueda').value = ''; directorio(); }
        navegar(tab);
      }},
        h('span', {class:'metrica-icono', 'aria-hidden':'true'}, icono),
        h('span', {class:'metrica-rotulo'}, rotulo),
        h('strong', {}, valor),
        h('small', {}, detalle))));
    const recientes = [...datos.trabajadores]
      .sort((a,b) => b.fecha_registro.localeCompare(a.fecha_registro) || b.id_trabajador - a.id_trabajador)
      .slice(0, 5);
    const filas = recientes.map(t => h('tr', {},
      h('td', {}, h('button', {type:'button', class:'alta-persona', onclick:() => editar(t)},
        avatar(t), h('span', {}, h('strong', {}, nombre(t)), h('small', {}, t.cargo)))),
      h('td', {}, t.fecha_registro.split('-').reverse().join('/')),
      h('td', {}, badgeEstado(t.estado))));
    $('#altas-panel').replaceChildren(filas.length ?
      h('table', {}, h('thead', {}, h('tr', {}, ['Trabajador','Ingreso','Estado'].map(n => h('th', {}, n)))),
        h('tbody', {}, filas)) : h('p', {class:'vacio'}, 'Aún no hay trabajadores registrados.'));
    $('#estados-panel').replaceChildren(...estados.map(([estado, rotulo, clase]) => {
      const valor = contar(estado);
      return h('div', {class:'estado-panel ' + clase},
        h('div', {}, h('span', {}, rotulo), h('strong', {}, valor)),
        h('progress', {max:total || 1, value:valor, 'aria-label':rotulo}));
    }));
    $('#pendientes-panel').replaceChildren(
      h('button', {class:'panel-enlace', onclick:() => navegar('inducciones')},
        'Consultar inducciones →'));
  }
  $('#busqueda').addEventListener('input',()=>{ navegar('directorio'); directorio(); });
  $('#cancelar').onclick = () => { if (confirm('¿Descartar los cambios de esta ficha?')) cargar(); };
  $('#atras').onclick = () => cambiarPaso(paso-1);
  campo.foto.onchange = () => {
    const f = campo.foto.files[0];
    if (f && f.size > 1024**2) { campo.foto.value=''; alerta('La foto debe pesar hasta 1 MB.','error'); }
    if (vistaFoto) URL.revokeObjectURL(vistaFoto);
    vistaFoto = campo.foto.files[0] ? URL.createObjectURL(campo.foto.files[0]) : null;
    foto(vistaFoto || (trabajador?.tiene_foto ? '/api/trabajadores/'+trabajador.id_trabajador+'/foto' : null));
  };
  // FileReader genera base64 sin convertir grandes arreglos en argumentos de función.
  function leer(f) {
    return new Promise((resolve,reject)=>{
      const lector = new FileReader();
      lector.onload=()=>resolve(lector.result.split(',')[1]);
      lector.onerror=()=>reject(new Error('No se pudo leer el archivo.'));
      lector.readAsDataURL(f);
    });
  }
  form.onsubmit = async ev => {
    ev.preventDefault();
    const numero=campo.identificacion.value.trim(), tipo=campo.tipo_documento.value;
    campo.identificacion.setCustomValidity((!!numero !== !!tipo || (tipo==='DNI' && !/^\d{8}$/.test(numero))) ? 'Complete tipo y número. El DNI debe tener ocho dígitos.' : '');
    for (const el of pasos[paso].querySelectorAll('input,select')) if (!el.reportValidity()) return;
    if (paso<2) { cambiarPaso(paso+1); return; }
    const boton=$('#avanzar'); if(boton.disabled) return;
    boton.disabled=true;
    try {
      const payload={id_trabajador:trabajador?.id_trabajador ?? null};
      for (const el of campo) {
        if (!el.name) continue;
        if (el.type!=='file') { payload[el.name]=el.value; continue; }
        const f=el.files[0]; if (!f) continue;
        if (el.name==='adjunto') {
          if (f.size>3*1024**2) throw new Error('El PDF debe pesar hasta 3 MB.');
          payload.nombre_adjunto=f.name;
        }
        payload[el.name]=await leer(f);
      }
      const res=await api('trabajadores',{method:'POST',body:JSON.stringify(payload)});
      cargar(); await recargarTodo(); alerta(res.mensaje);
    } catch(e) { alerta(e.message,'error'); } finally { boton.disabled=false; }
  };
  vistas.push(pintar); cargar();
}
