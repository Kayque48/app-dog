<script>
  // Perfil do cão: dados, carteira de vacinação, histórico e denúncia.
  import { onMount } from 'svelte';
  import { ageText, api, formatDate, imageUrl, reportReasons, sexes, temperaments, today, vaccineNames, vaccineText } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';

  let { id } = $props();
  let data = $state(null);
  let vaccines = $state([]);
  let vaccine = $state({ name: 'V10', applied_on: today(), next_due: '' });
  let report = $state(null);

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
  <div class="row top">
    <div class="photo">{#if d.photo_url}<img src={imageUrl(d.photo_url)} alt="" />{:else}🐶{/if}</div>
    <div class="grow">
      <h1>{d.name}, {ageText(d.age_years)}</h1>
      <p>{d.breed} • {sexes[d.sex]}{d.in_heat ? ' • no cio' : ''}</p>
      <p>Dono(a): <button class="link" onclick={() => go('owner', data.owner.id)}>{data.owner.first_name}</button></p>
      <span class="chip">{temperaments[d.temperament]}</span>
      <span class="chip">{d.bites ? '⚠️ Pode morder' : '✅ Não morde'}</span>
      {#if d.likes}<p>Gosta de: {d.likes}</p>{/if}
      {#if d.dislikes}<p>Não gosta de: {d.dislikes}</p>{/if}
      {#if d.removed_at}<p class="muted">Este cão não está mais no perfil do dono.</p>{/if}
      {#if !data.is_mine}<button class="danger" onclick={() => (report = { reason: 'agressividade', details: '' })}>🚩 Denunciar</button>{/if}
    </div>
  </div>

  {#if report}
    <form class="card" onsubmit={sendReport}>
      <h3>Denunciar</h3>
      {#each Object.entries(reportReasons) as [k, v]}
        <label class="check"><input type="radio" bind:group={report.reason} value={k} /> {v}</label>
      {/each}
      <label>O que aconteceu? <textarea rows="3" bind:value={report.details}></textarea></label>
      <div class="row">
        <button class="primary">Enviar denúncia</button>
        <button type="button" onclick={() => (report = null)}>Cancelar</button>
      </div>
    </form>
  {/if}

  <h2>Carteira de vacinação</h2>
  <div class="card status" class:okbg={d.vaccine_status.up_to_date} class:badbg={!d.vaccine_status.up_to_date}>
    {d.vaccine_status.up_to_date ? '✅' : '⛔'} {vaccineText(d.vaccine_status)}
    {#if !d.vaccine_status.up_to_date}
      <br /><small>Com vacina atrasada ou faltando, o cão fica bloqueado no Descobrir.</small>
    {/if}
  </div>
  <table>
    <thead><tr><th>Vacina</th><th>Aplicada em</th><th>Próximo reforço</th>{#if editable}<th></th>{/if}</tr></thead>
    <tbody>
      {#each vaccines as v (v.id)}
        <tr>
          <td>{v.name}</td>
          <td>{formatDate(v.applied_on)}</td>
          <td>{v.next_due ? formatDate(v.next_due) : '—'}</td>
          {#if editable}<td><button class="link" onclick={() => removeVaccine(v)}>apagar</button></td>{/if}
        </tr>
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
      <button class="primary">Registrar vacina</button>
    </form>
  {/if}

  <h2>Histórico</h2>
  {#each data.history as h}
    <p class:bad={h.kind === 'incidente'}>{h.kind === 'incidente' ? '⚠️' : '•'} {formatDate(h.created_at)} — {h.description}</p>
  {/each}
{/if}

<style>
  .top { align-items: flex-start; margin-bottom: 24px; }
  .photo { width: 240px; height: 240px; border-radius: 16px; background: var(--blue-light); display: grid; place-items: center; font-size: 5rem; overflow: hidden; flex-shrink: 0; }
  .photo img { width: 100%; height: 100%; object-fit: cover; }
  h2 { margin-top: 24px; }
  .okbg { background: #e8f5e9; }
  .badbg { background: #ffebee; }
  .add { align-items: flex-end; margin-top: 12px; }
  .add label { margin: 0; }
</style>
