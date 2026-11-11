<script>
  // Perfil do cão: dados, carteira de vacinação, histórico e denúncia.
  import { onMount } from 'svelte';
  import { activityLevels, ageText, api, docKinds, formatDate, imageUrl, lookingFor, reportReasons, sexes, temperaments, today, upload, vaccineNames, vaccineText } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let { id } = $props();
  let data = $state(null);
  let vaccines = $state([]);
  let vaccine = $state({ name: 'V10', applied_on: today(), next_due: '' });
  let report = $state(null);
  let documents = $state([]);
  let doc = $state({ kind: 'pedigree', title: '', file: null });

  const eventIcon = { cadastro: 'pets', vacina: 'vaccines', encontro: 'favorite', incidente: 'warning', perfil: 'edit', removido: 'logout' };

  async function load() {
    try {
      data = await api('GET', `/dogs/${id}`);
      vaccines = await api('GET', `/dogs/${id}/vaccines`);
      documents = await api('GET', `/dogs/${id}/documents`).catch(() => []);
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

  async function addDocument(e) {
    e.preventDefault();
    if (!doc.file) return toast('Escolha o arquivo (PDF ou foto)');
    try {
      const url = await upload(doc.file);
      await api('POST', `/dogs/${id}/documents`, { kind: doc.kind, title: doc.title || docKinds[doc.kind], file_url: url });
      toast(doc.kind === 'pedigree' ? 'Pedigree enviado! A moderação vai verificar.' : 'Documento guardado na carteira');
      doc = { kind: 'pedigree', title: '', file: null };
      e.target.reset();
      load();
    } catch (err) { showError(err); }
  }

  async function removeDocument(x) {
    if (!confirm(`Apagar "${x.title}"?`)) return;
    try { await api('DELETE', `/documents/${x.id}`); load(); } catch (err) { showError(err); }
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
      <div>
        <span class="chip"><Icon name="bolt" /> {activityLevels[d.activity_level]}</span>
        <span class="chip tonal"><Icon name={d.looking_for === 'amizade' ? 'diversity_1' : 'favorite'} /> {lookingFor[d.looking_for]}</span>
        {#if d.pedigree_verified}<span class="chip pedigree"><Icon name="verified" filled /> Pedigree verificado</span>{/if}
        {#if d.weight_kg}<span class="chip"><Icon name="scale" /> {d.weight_kg} kg</span>{/if}
        {#if d.color}<span class="chip"><Icon name="palette" /> {d.color}</span>{/if}
      </div>
      {#if d.bio}<p class="bio">“{d.bio}”</p>{/if}
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

  <h2 class="wallet-title"><Icon name="badge" filled size={32} /> Carteira digital</h2>
  <div class="wallet">
    <div class="id-card">
      <small>IDENTIDADE PET</small>
      <p class="display id-name">{d.name}</p>
      <div class="id-grid">
        <div><small>Raça</small>{d.breed}</div>
        <div><small>Nascimento</small>{formatDate(d.birth_date)}</div>
        <div><small>Sexo</small>{sexes[d.sex]}</div>
        <div><small>Castrado</small>{d.neutered ? 'Sim' : 'Não'}</div>
        <div><small>Peso</small>{d.weight_kg ? `${d.weight_kg} kg` : '—'}</div>
        <div><small>Cor</small>{d.color || '—'}</div>
        <div class="wide"><small>Microchip</small>{d.microchip || 'Não informado'}</div>
        {#if data.is_mine}
          <div class="wide"><small>Alergias</small>{d.allergies || 'Nenhuma informada'}</div>
          {#if d.health_notes}<div class="wide"><small>Saúde</small>{d.health_notes}</div>{/if}
        {/if}
      </div>
      <span class="id-paw shape-cookie9"><Icon name="pets" filled size={40} /></span>
    </div>

    {#if data.is_mine}
      <div class="docs">
        <h3>Documentos</h3>
        {#each documents as x (x.id)}
          <div class="doc">
            <Icon name={x.kind === 'pedigree' ? 'workspace_premium' : 'description'} />
            <div class="grow">
              <button class="link" onclick={() => window.open(imageUrl(x.file_url), '_blank')}>{x.title}</button><br />
              <small class="muted">{docKinds[x.kind]} · {formatDate(x.created_at)}</small>
            </div>
            {#if x.kind === 'pedigree'}
              <span class="chip {x.status === 'verificado' ? 'success' : x.status === 'recusado' ? 'error' : 'tonal'}">
                {x.status === 'verificado' ? 'Verificado' : x.status === 'recusado' ? 'Recusado' : 'Em análise'}
              </span>
            {/if}
            <button class="icon-btn" onclick={() => removeDocument(x)} aria-label="Apagar"><Icon name="delete" /></button>
          </div>
        {:else}
          <p class="muted">Nenhum documento ainda.</p>
        {/each}
        <form class="row wrap add" onsubmit={addDocument}>
          <label>Tipo
            <select bind:value={doc.kind}>{#each Object.entries(docKinds) as [k, v]}<option value={k}>{v}</option>{/each}</select>
          </label>
          <label class="grow">Título <input bind:value={doc.title} placeholder="Ex.: Pedigree CBKC" /></label>
          <label>Arquivo <input type="file" accept="application/pdf,image/*" onchange={(e) => (doc.file = e.target.files[0])} /></label>
          <button class="primary"><Icon name="upload_file" /> Guardar</button>
        </form>
        <p class="muted small">Os documentos só aparecem para você. O pedigree é verificado pela moderação e ganha um selo no perfil.</p>
      </div>
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
  .bio { font-size: 18px; font-style: italic; margin: 8px 0; }
  .pedigree { background: var(--like); color: #231b00; border: none; }
  .pedigree :global(.icon) { color: inherit; }
  .wallet-title { display: flex; align-items: center; gap: 8px; }
  .wallet-title :global(.icon) { color: var(--md-primary); }
  .wallet { display: grid; grid-template-columns: minmax(280px, 380px) 1fr; gap: 20px; align-items: start; }
  .id-card {
    position: relative;
    padding: 24px;
    border-radius: 32px 32px 32px 8px;
    background: linear-gradient(135deg, var(--md-primary), var(--md-tertiary));
    color: #fff;
    overflow: hidden;
    box-shadow: var(--md-elevation-2);
  }
  .id-card > small { font-weight: 800; letter-spacing: 0.15em; opacity: 0.85; }
  .id-name { font-size: 40px; line-height: 42px; margin: 4px 0 12px; }
  .id-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px 16px; font-size: 15px; }
  .id-grid small { display: block; font-size: 11px; opacity: 0.75; letter-spacing: 0.06em; text-transform: uppercase; }
  .id-grid .wide { grid-column: 1 / -1; }
  .id-paw { position: absolute; right: -10px; top: -10px; width: 96px; height: 96px; background: var(--like); color: #231b00; display: grid; place-items: center; }
  .docs { padding: 20px; border-radius: 28px; background: var(--md-surface-container-low); }
  .docs h3 { margin-top: 0; }
  .doc { display: flex; align-items: center; gap: 12px; padding: 8px 0; border-bottom: 1px solid var(--md-outline-variant); }
  .doc .chip { margin: 0; }
  .small { font-size: 13px; }
  @media (max-width: 900px) { .wallet { grid-template-columns: 1fr; } }
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
