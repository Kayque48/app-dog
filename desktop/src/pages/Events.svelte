<script>
  // Eventos: desfile de cadelas, corrida de salsichas, festas... com "Vou" / "Talvez".
  import { onMount } from 'svelte';
  import { api, eventDate, eventKinds, formatDistance, imageUrl } from '../lib/api.js';
  import { app, go, showError, toast } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let events = $state(null);
  let filter = $state('todos');
  let creating = $state(false);
  let form = $state({ title: '', description: '', kind: 'festa', place_name: '', address: '', starts_at: '', has_contest: false, entry_sex: '', entry_breed: '' });

  const load = async () => (events = await api('GET', '/events').catch((e) => (showError(e), [])));
  onMount(load);

  const shown = $derived(
    (events ?? []).filter((e) => filter === 'todos' || (filter === 'concursos' ? e.has_contest : e.my_rsvp)),
  );

  async function rsvp(e, status) {
    const next = e.my_rsvp === status ? null : status;
    // atualiza na hora (otimista) e confirma no servidor
    if (e.my_rsvp === 'going') e.going--;
    if (e.my_rsvp === 'maybe') e.maybe--;
    if (next === 'going') e.going++;
    if (next === 'maybe') e.maybe++;
    e.my_rsvp = next;
    if (next === 'going') toast(`Bora! Você vai no ${e.title} 🎉`);
    try { await api('POST', `/events/${e.id}/rsvp`, { status: next }); } catch (err) { showError(err); load(); }
  }

  async function create(ev) {
    ev.preventDefault();
    const me = app.me;
    if (me.lat == null) return toast('Defina sua localização no Perfil: o evento será marcado nela.');
    try {
      const r = await api('POST', '/events', {
        ...form,
        starts_at: form.starts_at.replace('T', ' '),
        lat: me.lat,
        lng: me.lng,
        entry_sex: form.has_contest && form.entry_sex ? form.entry_sex : null,
        entry_breed: form.has_contest && form.entry_breed ? form.entry_breed : null,
      });
      creating = false;
      toast('Evento criado! 🎉');
      go('event', r.id);
    } catch (err) { showError(err); }
  }
</script>

<div class="page-header">
  <h1>Eventos</h1>
  <button class="primary big" onclick={() => (creating = !creating)}>
    <Icon name={creating ? 'close' : 'add'} /> {creating ? 'Fechar' : 'Criar evento'}
  </button>
</div>

<div class="segmented" role="group" aria-label="Filtro">
  {#each [['todos', 'Todos'], ['concursos', 'Com concurso'], ['meus', 'Vou / talvez']] as [k, v]}
    <button class:selected={filter === k} onclick={() => (filter = k)}>{#if filter === k}<Icon name="check" />{/if} {v}</button>
  {/each}
</div>

{#if creating}
  <form class="card create rise" onsubmit={create}>
    <h2>Novo evento</h2>
    <div class="grid2">
      <label>Nome do evento <input bind:value={form.title} required placeholder="Ex.: Desfile de Cadelas" /></label>
      <label>Tipo
        <select bind:value={form.kind}>{#each Object.entries(eventKinds) as [k, v]}<option value={k}>{v.label}</option>{/each}</select>
      </label>
      <label>Local <input bind:value={form.place_name} required placeholder="Ex.: Parque Ibirapuera" /></label>
      <label>Quando <input type="datetime-local" bind:value={form.starts_at} required /></label>
    </div>
    <label>Endereço / referência <input bind:value={form.address} /></label>
    <label>Descrição <textarea rows="2" bind:value={form.description}></textarea></label>
    <label class="check"><input type="checkbox" class="switch" bind:checked={form.has_contest} /> Tem concurso com votação</label>
    {#if form.has_contest}
      <div class="grid2">
        <label>Só para
          <select bind:value={form.entry_sex}><option value="">Todos</option><option value="femea">Fêmeas</option><option value="macho">Machos</option></select>
        </label>
        <label>Só a raça (opcional) <input bind:value={form.entry_breed} placeholder="Ex.: Dachshund" /></label>
      </div>
    {/if}
    <p class="muted small">O evento é marcado na sua localização atual.</p>
    <button class="primary big"><Icon name="celebration" /> Criar</button>
  </form>
{/if}

{#if events && shown.length === 0}
  <div class="empty"><Icon name="event_busy" />Nenhum evento aqui. Que tal criar um?</div>
{/if}

<div class="list">
  {#each shown as e, i (e.id)}
    {@const d = eventDate(e.starts_at)}
    <article class="event rise" class:wide={i === 0} style="animation-delay:{i * 50}ms">
      <button class="cover r{i % 3}" onclick={() => go('event', e.id)} aria-label={e.title}>
        <span class="fallback"><Icon name={eventKinds[e.kind].icon} filled size={72} /></span>
        {#if e.cover_url}<img src={imageUrl(e.cover_url)} alt="" />{/if}
        <span class="date shape-cookie12">
          <small>{d.week}</small><strong>{d.day}</strong><small>{d.month}</small>
        </span>
        {#if d.soon}<span class="soon chip">🔥 {d.countdown}</span>{/if}
      </button>
      <div class="body">
        <div class="tags">
          <span class="chip tonal"><Icon name={eventKinds[e.kind].icon} /> {eventKinds[e.kind].label}</span>
          {#if e.has_contest}<span class="chip contest"><Icon name="emoji_events" filled /> Concurso{e.entry_sex === 'femea' ? ' · só fêmeas' : e.entry_sex === 'macho' ? ' · só machos' : ''}{e.entry_breed ? ` · só ${e.entry_breed}` : ''}</span>{/if}
        </div>
        <button class="title display" onclick={() => go('event', e.id)}>{e.title}</button>
        <p class="muted info">
          <Icon name="schedule" size={18} /> {d.time} · {d.countdown}
          <Icon name="location_on" size={18} /> {e.place_name}{e.distance_m != null ? ` · ${formatDistance(e.distance_m)}` : ''}
        </p>
        <p class="counts"><strong>{e.going}</strong> vão · <strong>{e.maybe}</strong> talvez{e.has_contest ? ` · ${e.entries} na disputa` : ''}</p>
        <div class="rsvp">
          <button class="pill" class:on={e.my_rsvp === 'going'} onclick={() => rsvp(e, 'going')}><Icon name="music_note" filled /> Vou</button>
          <button class="pill" class:on={e.my_rsvp === 'maybe'} onclick={() => rsvp(e, 'maybe')}><Icon name="help" /> Talvez</button>
        </div>
      </div>
    </article>
  {/each}
</div>

<style>
  .create { background: var(--md-primary-container); color: var(--md-on-primary-container); box-shadow: none; }
  .create h2 { margin-top: 0; }
  .create label { color: inherit; }
  .small { font-size: 14px; }
  .list { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 24px; }
  .event { background: var(--md-surface-container-low); border-radius: 40px; overflow: hidden; display: flex; flex-direction: column; }
  .event.wide { grid-column: 1 / -1; flex-direction: row; }
  .event.wide .cover { width: 55%; aspect-ratio: auto; min-height: 340px; }
  .event.wide .title { font-size: 44px; line-height: 46px; }
  .cover {
    position: relative;
    aspect-ratio: 16 / 10;
    height: auto;
    padding: 0;
    border: none;
    display: grid;
    place-items: center;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
    flex-shrink: 0;
  }
  .cover::after { display: none; }
  .cover.r0 { border-radius: 40px 40px 80px 12px; }
  .cover.r1 { border-radius: 40px 40px 12px 80px; }
  .cover.r2 { border-radius: 40px 40px 40px 40px; }
  .cover img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; transition: transform 0.5s; }
  .cover:hover img { transform: scale(1.05); }
  .date {
    position: absolute;
    top: 16px;
    left: 16px;
    width: 84px;
    height: 84px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    background: var(--like);
    color: #231b00;
    line-height: 1;
    z-index: 1;
  }
  .date strong { font-family: var(--font-display); font-size: 30px; font-weight: 800; }
  .date small { font-size: 11px; font-weight: 800; letter-spacing: 0.08em; }
  .soon { position: absolute; top: 20px; right: 16px; background: var(--md-inverse-surface); color: var(--md-inverse-on-surface); border: none; z-index: 1; }
  .body { padding: 20px 24px 24px; display: flex; flex-direction: column; flex: 1; }
  .tags .chip { margin-bottom: 4px; }
  .contest { background: var(--md-secondary-container); color: var(--md-on-secondary-container); border: none; }
  .contest :global(.icon) { color: inherit; }
  .title {
    height: auto;
    padding: 0;
    border: none;
    justify-content: flex-start;
    text-align: left;
    white-space: normal;
    font-size: 28px;
    line-height: 32px;
    color: var(--md-on-surface);
    margin: 8px 0;
  }
  .title::after { display: none; }
  .title:hover { color: var(--md-primary); }
  .info { font-size: 14px; display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
  .counts { font-size: 14px; }
  .rsvp { display: flex; gap: 10px; margin-top: auto; padding-top: 8px; }
  /* "Vou" / "Talvez" em pílula, como no Material 3 Expressive */
  .pill { flex: 1; height: 52px; border-radius: 26px; border: none; background: var(--md-surface-container-highest); color: var(--md-on-surface); font-size: 16px; font-weight: 700; }
  .pill.on { background: var(--md-primary); color: var(--md-on-primary); border-radius: 16px; }
  .pill :global(.icon) { margin: 0; }
  @media (max-width: 900px) {
    .event.wide { flex-direction: column; }
    .event.wide .cover { width: 100%; min-height: 0; aspect-ratio: 16 / 10; }
  }
</style>
