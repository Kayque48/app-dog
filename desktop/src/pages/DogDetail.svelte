<script>
  // Perfil do cão: dados, carteira de vacinação, histórico e denúncia.
  import { onMount } from 'svelte';
  import { ageText, api, formatDate, imageUrl, reportReasons, sexes, temperaments, today, vaccineNames, vaccineText } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let { id } = $props();
  let data = $state(null);
  let vaccines = $state([]);
  let vaccine = $state({ name: 'V10', applied_on: today(), next_due: '' });
  let report = $state(null);

  const eventIcon = { cadastro: 'pets', vacina: 'vaccines', encontro: 'favorite', incidente: 'warning', perfil: 'edit', removido: 'logout' };

  async function load() {
    try {
      data = await api('GET', `/dogs/${id}`);
      vaccines = await api('GET', `/dogs/${id}/vaccines`);
    } catch (e) { showError(e); }
  }
  onMount(load);

  async function addVaccine(e) {
    e.preventDefault();
    try {
      await api('POST', `/dogs/${id}/vaccines`, { ...vaccine, next_due: vaccine.next_due || null });
      vaccine = { name: 'V10', applied_on: today(), next_due: '' };
      load();
    } catch (err) { showError(err); }
  }

  async function removeVaccine(v) {
    if (!confirm(`Apagar o registro da vacina ${v.name}?`)) return;
    try { await api('DELETE', `/vaccines/${v.id}`); load(); } catch (e) { showError(e); }
  }

  async function sendReport(e) {
    e.preventDefault();
    try {
      const r = await api('POST', '/reports', { target_dog_id: id, ...report });
      toast(r.message);
      report = null;
    } catch (err) { showError(err); }
  }
</script>

{#if data}
  {@const d = data.dog}
  {@const editable = data.is_mine && !d.removed_at}
  <div class="page-header">
    <button class="icon-btn" onclick={() => go(data.is_mine ? 'dogs' : 'discover')} aria-label="Voltar"><Icon name="arrow_back" /></button>
    <h1>{d.name}</h1>
    {#if !data.is_mine}
      <button class="danger" onclick={() => (report = { reason: 'agressividade', details: '' })}><Icon name="flag" /> Denunciar</button>
    {/if}
  </div>

  <div class="card top">
    <div class="photo shape-blob"><Icon name="pets" filled size={96} />{#if d.photo_url}<img src={imageUrl(d.photo_url)} alt="" />{/if}</div>
    <div class="grow info">
      <p class="display big-name">{d.name}</p>
      <h2>{ageText(d.age_years)}</h2>
      <p class="muted">{d.breed} · {sexes[d.sex]}{d.in_heat ? ' · no cio' : ''}</p>
      <button class="tonal owner" onclick={() => go('owner', data.owner.id)}><Icon name="person" /> Dono(a): {data.owner.first_name}</button>
      <div>
        <span class="chip"><Icon name="mood" /> {temperaments[d.temperament]}</span>
        {#if d.bites}<span class="chip error"><Icon name="warning" /> Pode morder</span>
        {:else}<span class="chip"><Icon name="check_circle" /> Não morde</span>{/if}
      </div>
      {#if d.likes}<p><strong>Gosta de:</strong> {d.likes}</p>{/if}
      {#if d.dislikes}<p><strong>Não gosta de:</strong> {d.dislikes}</p>{/if}
      {#if d.removed_at}<p class="muted">Este cão não está mais no perfil do dono.</p>{/if}
    </div>
  </div>

  {#if report}
    <!-- Diálogo do M3 -->
    <div class="scrim" role="presentation" onclick={() => (report = null)}></div>
    <form class="dialog" onsubmit={sendReport}>
      <Icon name="flag" />
      <h2>Denunciar {d.name}</h2>
      {#each Object.entries(reportReasons) as [k, v]}
        <label class="check"><input type="radio" bind:group={report.reason} value={k} /> {v}</label>
      {/each}
      <label>O que aconteceu? <textarea rows="3" bind:value={report.details}></textarea></label>
      <div class="row actions">
        <button type="button" class="text" onclick={() => (report = null)}>Cancelar</button>
        <button class="text">Enviar denúncia</button>
      </div>
    </form>
  {/if}

  <h2>Carteira de vacinação</h2>
  <div class="card {d.vaccine_status.up_to_date ? 'success' : 'error'} row">
    <Icon name={d.vaccine_status.up_to_date ? 'verified' : 'block'} />
    <div>
      {vaccineText(d.vaccine_status)}
      {#if !d.vaccine_status.up_to_date}
        <br /><small>Com vacina atrasada ou faltando, o cão fica bloqueado no Descobrir.</small>
      {/if}
    </div>
  </div>
  <div class="card outlined table">
    <table>
      <thead><tr><th>Vacina</th><th>Aplicada em</th><th>Próximo reforço</th>{#if editable}<th></th>{/if}</tr></thead>
      <tbody>
        {#each vaccines as v (v.id)}
          <tr>
            <td>{v.name}</td>
            <td>{formatDate(v.applied_on)}</td>
            <td>{v.next_due ? formatDate(v.next_due) : '—'}</td>
            {#if editable}
              <td class="end"><button class="icon-btn" onclick={() => removeVaccine(v)} aria-label="Apagar"><Icon name="delete" /></button></td>
            {/if}
          </tr>
        {:else}
          <tr><td colspan="4" class="muted">Nenhuma vacina registrada.</td></tr>
        {/each}
      </tbody>
    </table>
    {#if editable}
      <form class="row wrap add" onsubmit={addVaccine}>
        <label>Vacina
          <select bind:value={vaccine.name}>{#each vaccineNames as n}<option>{n}</option>{/each}</select>
        </label>
        <label>Aplicada em <input type="date" max={today()} bind:value={vaccine.applied_on} required /></label>
        <label>Próximo reforço <input type="date" bind:value={vaccine.next_due} /></label>
        <button class="primary"><Icon name="add" /> Registrar vacina</button>
      </form>
    {/if}
  </div>

  <h2>Histórico</h2>
  <div class="card outlined">
    {#each data.history as h}
      <div class="list-item">
        <span class="event" class:incident={h.kind === 'incidente'}><Icon name={eventIcon[h.kind] ?? 'history'} /></span>
        <div class="grow">{h.description}<br /><small class="muted">{formatDate(h.created_at)}</small></div>
      </div>
    {/each}
  </div>
{/if}

<style>
  .top { display: flex; gap: 24px; align-items: flex-start; padding: 16px; }
  .photo {
    position: relative;
    width: 280px;
    height: 280px;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
    display: grid;
    place-items: center;
    overflow: hidden;
    flex-shrink: 0;
  }
  .photo img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .info h2 { margin-top: 0; }
  .big-name { font-size: 72px; line-height: 72px; margin: 0; color: var(--md-primary); }
  .top { border-radius: 48px; }
  .owner { margin: 4px 0 16px; }
  strong { font-weight: 500; }
  .table { padding: 0; overflow: hidden; }
  .end { text-align: right; padding: 4px 8px; }
  .add { align-items: flex-end; padding: 16px; }
  .add label { margin: 0; }
  .event {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: var(--md-secondary-container);
    color: var(--md-on-secondary-container);
    flex-shrink: 0;
  }
  .event.incident { background: var(--md-error-container); color: var(--md-on-error-container); }
  .scrim { position: fixed; inset: 0; background: rgb(0 0 0 / 0.32); z-index: 20; }
  .dialog {
    position: fixed;
    z-index: 21;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: min(560px, 92vw);
    max-height: 90vh;
    overflow-y: auto;
    background: var(--md-surface-container-high);
    border-radius: 28px;
    padding: 24px;
    box-shadow: var(--md-elevation-3);
    text-align: left;
  }
  .dialog > :global(.icon) { color: var(--md-secondary); display: block; text-align: center; margin-bottom: 16px; }
  .dialog h2 { text-align: center; margin-top: 0; font-size: 24px; line-height: 32px; }
  .dialog label.check { min-height: 40px; font-size: 14px; }
  .dialog label:not(.check) { margin-top: 16px; }
  .actions { justify-content: flex-end; gap: 8px; }
  @media (max-width: 760px) {
    .top { flex-direction: column; }
    .photo { width: 100%; }
  }
</style>
