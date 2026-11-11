<script>
  // Serviços: veterinários, banho e tosa, adestradores, passeadores, hotéis, criadores e adoção.
  // Dá para agendar, ligar, chamar no WhatsApp e cadastrar o próprio negócio.
  import { onMount } from 'svelte';
  import { api, formatDate, formatDistance, openExternal, providerKinds, today, whatsapp } from '../lib/api.js';
  import { app, showError, toast } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let kind = $state('');
  let providers = $state(null);
  let selected = $state(null);
  let myDogs = $state([]);
  let appointments = $state([]);
  let booking = $state({ dog_id: null, service: '', date_time: '', notes: '' });
  let registering = $state(false);
  let reg = $state({ name: '', kind: 'veterinario', description: '', services: '', phone: '', address: '' });

  const load = async () => (providers = await api('GET', `/providers?kind=${kind}`).catch((e) => (showError(e), [])));
  const loadAppointments = async () => (appointments = await api('GET', '/appointments').catch(() => []));
  onMount(async () => {
    load();
    loadAppointments();
    myDogs = (await api('GET', '/dogs/mine').catch(() => [])).filter((d) => !d.removed_at);
  });

  const servicesOf = (p) => p.services.split(',').map((s) => s.trim()).filter(Boolean);

  function open(p) {
    selected = p;
    booking = { dog_id: myDogs[0]?.id ?? null, service: servicesOf(p)[0] ?? '', date_time: '', notes: '' };
  }

  async function book(e) {
    e.preventDefault();
    try {
      const r = await api('POST', '/appointments', { ...booking, provider_id: selected.id, date_time: booking.date_time.replace('T', ' ') });
      toast(r.message);
      selected = null;
      loadAppointments();
    } catch (err) { showError(err); }
  }

  async function cancel(a) {
    if (!confirm(`Cancelar ${a.service} em ${a.provider_name}?`)) return;
    try { await api('POST', `/appointments/${a.id}/cancel`); loadAppointments(); } catch (err) { showError(err); }
  }

  async function register(e) {
    e.preventDefault();
    if (app.me.lat == null) return toast('Defina sua localização no Perfil: o endereço será marcado nela.');
    try {
      const r = await api('POST', '/providers', { ...reg, lat: app.me.lat, lng: app.me.lng });
      toast(r.message);
      registering = false;
      load();
    } catch (err) { showError(err); }
  }

  const upcoming = $derived(appointments.filter((a) => a.status !== 'cancelado' && a.date_time >= today()));
</script>

<div class="page-header">
  <h1>Serviços</h1>
  <button class="tonal big" onclick={() => (registering = !registering)}><Icon name={registering ? 'close' : 'add_business'} /> {registering ? 'Fechar' : 'Cadastrar meu negócio'}</button>
</div>

{#if registering}
  <form class="card reg rise" onsubmit={register}>
    <h2>Cadastro de profissional ou estabelecimento</h2>
    <div class="grid2">
      <label>Nome <input bind:value={reg.name} required /></label>
      <label>Tipo
        <select bind:value={reg.kind}>{#each Object.entries(providerKinds) as [k, v]}<option value={k}>{v.label}</option>{/each}</select>
      </label>
      <label>Telefone / WhatsApp <input bind:value={reg.phone} required placeholder="(11) 91234-5678" /></label>
      <label>Endereço <input bind:value={reg.address} /></label>
    </div>
    <label>Serviços (separe por vírgula) <input bind:value={reg.services} placeholder="Ex.: Consulta, Vacinação, Castração" /></label>
    <label>Descrição <textarea rows="2" bind:value={reg.description}></textarea></label>
    <p class="muted small">O cadastro ganha o selo de verificado depois da análise da moderação.</p>
    <button class="primary big"><Icon name="send" /> Enviar cadastro</button>
  </form>
{/if}

{#if upcoming.length}
  <section class="appts">
    <h3><Icon name="event_available" /> Meus agendamentos</h3>
    {#each upcoming as a (a.id)}
      <div class="appt">
        <div class="when"><strong>{a.date_time.slice(8, 10)}/{a.date_time.slice(5, 7)}</strong><small>{a.date_time.slice(11, 16)}</small></div>
        <div class="grow"><strong>{a.service}</strong> · {a.dog_name}<br /><small>{a.provider_name}</small></div>
        <span class="chip {a.status === 'confirmado' ? 'success' : 'tonal'}">{a.status === 'confirmado' ? 'Confirmado' : 'Aguardando'}</span>
        <button class="text" onclick={() => cancel(a)}>Cancelar</button>
      </div>
    {/each}
  </section>
{/if}

<div class="kinds">
  <button class="kind" class:on={kind === ''} onclick={() => { kind = ''; load(); }}><span class="k-icon shape-cookie9"><Icon name="apps" filled /></span>Todos</button>
  {#each Object.entries(providerKinds) as [k, v], i}
    <button class="kind" class:on={kind === k} onclick={() => { kind = k; load(); }}>
      <span class="k-icon shape-{['flower', 'cookie12', 'blob', 'cookie9'][i % 4]}"><Icon name={v.icon} filled /></span>{v.label}
    </button>
  {/each}
</div>

{#if providers && providers.length === 0}<div class="empty"><Icon name="search_off" />Nenhum cadastro aqui ainda.</div>{/if}

<div class="grid">
  {#each providers ?? [] as p, i (p.id)}
    <button class="prov rise" style="animation-delay:{i * 40}ms" onclick={() => open(p)}>
      <span class="p-icon shape-{['cookie12', 'flower', 'cookie9'][i % 3]}"><Icon name={providerKinds[p.kind].icon} filled size={36} /></span>
      <span class="p-body">
        <strong class="p-name">{p.name} {#if p.verified}<Icon name="verified" filled size={20} />{/if}</strong>
        <small>{providerKinds[p.kind].label}{p.distance_m != null ? ` · ${formatDistance(p.distance_m)}` : ''}</small>
        <span class="p-desc">{p.description}</span>
        <span class="tags">{#each servicesOf(p).slice(0, 3) as s}<span class="chip">{s}</span>{/each}</span>
      </span>
    </button>
  {/each}
</div>

{#if selected}
  <div class="scrim" role="presentation" onclick={() => (selected = null)}></div>
  <div class="dialog" role="dialog" aria-label={selected.name}>
    <span class="p-icon big shape-flower"><Icon name={providerKinds[selected.kind].icon} filled size={48} /></span>
    <h2>{selected.name} {#if selected.verified}<Icon name="verified" filled />{/if}</h2>
    <p class="muted">{providerKinds[selected.kind].label} · {selected.address}{selected.distance_m != null ? ` · ${formatDistance(selected.distance_m)}` : ''}</p>
    <p>{selected.description}</p>
    <div class="row wrap">
      <button class="tonal" onclick={() => openExternal(`tel:${selected.phone}`)}><Icon name="call" /> Ligar</button>
      <button class="tonal" onclick={() => openExternal(whatsapp(selected.phone, `Oi! Vi vocês no All Love 🐾`))}><Icon name="chat" /> WhatsApp</button>
      <button class="tonal" onclick={() => openExternal(`https://www.google.com/maps/search/?api=1&query=${selected.lat},${selected.lng}`)}><Icon name="map" /> Mapa</button>
    </div>
    {#if myDogs.length && selected.kind !== 'adocao'}
      <form class="book" onsubmit={book}>
        <h3><Icon name="calendar_month" /> Agendar</h3>
        <div class="grid2">
          <label>Cão <select bind:value={booking.dog_id}>{#each myDogs as d}<option value={d.id}>{d.name}</option>{/each}</select></label>
          <label>Serviço <select bind:value={booking.service}>{#each servicesOf(selected) as s}<option>{s}</option>{/each}</select></label>
        </div>
        <label>Quando <input type="datetime-local" bind:value={booking.date_time} required /></label>
        <label>Observações <input bind:value={booking.notes} placeholder="Ex.: ele tem medo de secador" /></label>
        <div class="row end">
          <button type="button" class="text" onclick={() => (selected = null)}>Fechar</button>
          <button class="primary"><Icon name="event_available" /> Pedir horário</button>
        </div>
      </form>
    {:else}
      <div class="row end"><button class="text" onclick={() => (selected = null)}>Fechar</button></div>
    {/if}
  </div>
{/if}

<style>
  .reg { background: var(--md-primary-container); color: var(--md-on-primary-container); box-shadow: none; }
  .reg h2 { margin-top: 0; }
  .reg label { color: inherit; }
  .small { font-size: 13px; }
  .appts { padding: 16px 20px; border-radius: 32px; background: var(--md-secondary-container); color: var(--md-on-secondary-container); margin-bottom: 20px; }
  .appts h3 { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
  .appt { display: flex; align-items: center; gap: 14px; padding: 8px 0; }
  .appt .chip { margin: 0; }
  .when { display: flex; flex-direction: column; align-items: center; width: 64px; padding: 8px; border-radius: 18px; background: var(--md-on-secondary-container); color: var(--md-secondary-container); line-height: 1.1; }
  .when strong { font-family: var(--font-display); font-size: 20px; }
  .kinds { display: flex; gap: 12px; overflow-x: auto; padding: 4px 0 16px; }
  .kind { flex-direction: column; height: auto; padding: 0; border: none; gap: 6px; font-size: 13px; color: var(--md-on-surface); min-width: 84px; }
  .kind::after { display: none; }
  .k-icon { width: 68px; height: 68px; display: grid; place-items: center; background: var(--md-surface-container-high); color: var(--md-on-surface-variant); transition: transform 0.3s cubic-bezier(.2, .9, .3, 1.4); }
  .kind:hover .k-icon { transform: rotate(15deg) scale(1.05); }
  .kind.on .k-icon { background: var(--md-primary); color: var(--md-on-primary); }
  .kind.on { font-weight: 800; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; }
  .prov { display: flex; align-items: flex-start; gap: 16px; height: auto; padding: 20px; border: none; border-radius: 32px; background: var(--md-surface-container-low); color: var(--md-on-surface); text-align: left; white-space: normal; justify-content: flex-start; }
  .prov:hover { box-shadow: var(--md-elevation-2); }
  .p-icon { width: 72px; height: 72px; flex-shrink: 0; display: grid; place-items: center; background: var(--md-primary-container); color: var(--md-on-primary-container); }
  .p-icon.big { width: 96px; height: 96px; margin: 0 auto 8px; }
  .p-body { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .p-name { font-family: var(--font-display); font-size: 20px; line-height: 24px; display: flex; align-items: center; gap: 4px; }
  .p-name :global(.icon), .dialog h2 :global(.icon) { color: var(--md-primary); }
  .p-body small { color: var(--md-on-surface-variant); }
  .p-desc { font-size: 14px; line-height: 19px; margin-top: 4px; }
  .tags { margin-top: 6px; }
  .tags .chip { height: 28px; font-size: 12px; padding: 0 10px; margin: 0 6px 6px 0; }
  .scrim { position: fixed; inset: 0; background: rgb(0 0 0 / 0.32); z-index: 20; }
  .dialog { position: fixed; z-index: 21; top: 50%; left: 50%; transform: translate(-50%, -50%); width: min(600px, 94vw); max-height: 92vh; overflow-y: auto; background: var(--md-surface-container-high); border-radius: 28px; padding: 28px; box-shadow: var(--md-elevation-3); text-align: center; }
  .dialog h2 { margin: 0 0 4px; display: flex; align-items: center; justify-content: center; gap: 6px; }
  .dialog .row { justify-content: center; margin: 12px 0; }
  .book { text-align: left; margin-top: 8px; padding: 20px; border-radius: 24px; background: var(--md-surface); }
  .book h3 { display: flex; align-items: center; gap: 8px; }
  .end { justify-content: flex-end !important; }
</style>
