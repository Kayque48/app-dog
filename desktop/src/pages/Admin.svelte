<script>
  // Moderação: analisar denúncias e bloquear contas permanentemente.
  import { onMount } from 'svelte';
  import { api, formatDate, imageUrl, providerKinds, reportReasons } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let tab = $state('reports');
  let status = $state('aberta');
  let reports = $state([]);
  let users = $state([]);
  let q = $state('');
  let pedigrees = $state([]);
  let pendingProviders = $state([]);
  const loadPending = async () => {
    pedigrees = await api('GET', '/admin/pedigrees').catch(() => []);
    pendingProviders = await api('GET', '/admin/providers').catch(() => []);
  };

  async function review(x, approved) {
    try { await api('POST', `/admin/pedigrees/${x.id}/review`, { approved }); toast(approved ? 'Pedigree verificado' : 'Pedigree recusado'); loadPending(); } catch (e) { showError(e); }
  }
  async function verifyProvider(p) {
    try { await api('POST', `/admin/providers/${p.id}/verify`); toast(`${p.name} verificado`); loadPending(); } catch (e) { showError(e); }
  }

  const loadReports = async () => (reports = await api('GET', `/admin/reports?status=${status}`).catch((e) => (showError(e), [])));
  const searchUsers = async () => (users = await api('GET', `/admin/users?q=${encodeURIComponent(q)}`).catch((e) => (showError(e), [])));
  onMount(() => { loadReports(); searchUsers(); loadPending(); });

  async function resolve(r, procedente, ban) {
    const what = !procedente ? 'arquivar esta denúncia' : ban ? `confirmar e BLOQUEAR ${r.target_name} permanentemente` : 'confirmar a denúncia sem bloquear';
    if (!confirm(`Deseja ${what}?`)) return;
    try {
      await api('POST', `/admin/reports/${r.id}/resolve`, { procedente, ban });
      toast('Denúncia analisada');
      loadReports();
    } catch (e) { showError(e); }
  }

  async function ban(u) {
    const reason = prompt(`Motivo do bloqueio permanente de ${u.name} (ex.: processo judicial envolvendo animais):`);
    if (!reason) return;
    try {
      await api('POST', `/admin/users/${u.id}/ban`, { reason });
      toast('Conta bloqueada');
      searchUsers();
    } catch (e) { showError(e); }
  }
</script>

<div class="page-header"><h1>Moderação</h1></div>

<!-- Abas primárias do M3 -->
<div class="tabs" role="tablist">
  <button role="tab" class:active={tab === 'reports'} onclick={() => (tab = 'reports')}><Icon name="flag" /> Denúncias</button>
  <button role="tab" class:active={tab === 'users'} onclick={() => (tab = 'users')}><Icon name="group" /> Donos</button>
  <button role="tab" class:active={tab === 'pedigrees'} onclick={() => (tab = 'pedigrees')}><Icon name="workspace_premium" /> Pedigrees {#if pedigrees.length}<span class="badge">{pedigrees.length}</span>{/if}</button>
  <button role="tab" class:active={tab === 'providers'} onclick={() => (tab = 'providers')}><Icon name="storefront" /> Profissionais {#if pendingProviders.length}<span class="badge">{pendingProviders.length}</span>{/if}</button>
</div>

{#if tab === 'pedigrees'}
  {#each pedigrees as x (x.id)}
    <div class="card outlined row wrap">
      <Icon name="workspace_premium" size={36} />
      <div class="grow">
        <strong>{x.title}</strong><br />
        <small class="muted">{x.dog_name} ({x.dog_breed}) · dono(a) {x.owner_name} · {formatDate(x.created_at)}</small>
      </div>
      <button class="text" onclick={() => window.open(imageUrl(x.file_url), '_blank')}><Icon name="open_in_new" /> Ver documento</button>
      <button class="danger" onclick={() => review(x, false)}>Recusar</button>
      <button class="primary" onclick={() => review(x, true)}><Icon name="verified" /> Verificar</button>
    </div>
  {:else}
    <div class="empty"><Icon name="task_alt" />Nenhum pedigree esperando análise.</div>
  {/each}
{:else if tab === 'providers'}
  {#each pendingProviders as p (p.id)}
    <div class="card outlined row wrap">
      <Icon name={providerKinds[p.kind]?.icon ?? 'store'} size={36} />
      <div class="grow">
        <strong>{p.name}</strong> <span class="chip tonal">{providerKinds[p.kind]?.label}</span><br />
        <small class="muted">Tel. {p.phone} · {p.address} · cadastrado por {p.owner_name ?? 'sistema'}</small><br />
        <small>{p.services}</small>
      </div>
      <button class="primary" onclick={() => verifyProvider(p)}><Icon name="verified" /> Dar selo de verificado</button>
    </div>
  {:else}
    <div class="empty"><Icon name="task_alt" />Nenhum profissional esperando verificação.</div>
  {/each}
{:else if tab === 'reports'}
  <div class="segmented" role="group" aria-label="Situação">
    {#each [['aberta', 'Em aberto'], ['procedente', 'Procedentes'], ['improcedente', 'Improcedentes']] as [k, v]}
      <button class:selected={status === k} onclick={() => { status = k; loadReports(); }}>
        {#if status === k}<Icon name="check" />{/if} {v}
      </button>
    {/each}
  </div>
  {#if reports.length === 0}<div class="empty"><Icon name="task_alt" />Nenhuma denúncia aqui.</div>{/if}
  {#each reports as r (r.id)}
    <div class="card outlined">
      <div class="row">
        <span class="chip error"><Icon name="flag" /> {reportReasons[r.reason] ?? r.reason}</span>
        <span class="grow"></span>
        <small class="muted">#{r.id} · {formatDate(r.created_at)}</small>
      </div>
      <p>{r.details || 'Sem detalhes.'}</p>
      <p class="muted small">Denunciado por {r.reporter_name}</p>
      <div class="grid2 people">
        <div class="card filled">
          <h3>Dono denunciado {#if r.target_banned}<span class="chip error">bloqueado</span>{/if}</h3>
          <div>{r.target_name}</div>
          <div class="muted small">
            CPF {r.target_cpf ?? '—'} · Tel. {r.target_phone}<br />{r.target_email}<br />{r.target_address}<br />
            Total de denúncias contra este dono: {r.target_total_reports}
          </div>
        </div>
        {#if r.target_dog_id}
          <div class="card filled">
            <h3>Cão</h3>
            <button class="link" onclick={() => go('dog', r.target_dog_id)}>{r.target_dog_name}</button>
          </div>
        {/if}
      </div>
      {#if r.status === 'aberta'}
        <div class="row wrap end">
          <button class="text" onclick={() => resolve(r, false, false)}>Improcedente</button>
          <button onclick={() => resolve(r, true, false)}>Procedente (registrar incidente)</button>
          <button class="danger primary" onclick={() => resolve(r, true, true)}><Icon name="block" /> Procedente + bloquear conta</button>
        </div>
      {/if}
    </div>
  {/each}
{:else}
  <form class="search" onsubmit={(e) => { e.preventDefault(); searchUsers(); }}>
    <Icon name="search" />
    <input placeholder="Buscar por nome, e-mail ou CPF" bind:value={q} />
  </form>
  <div class="card outlined table">
    <table>
      <thead><tr><th>Nome</th><th>CPF</th><th>Telefone</th><th>Endereço</th><th>Cães</th><th>Denúncias</th><th></th></tr></thead>
      <tbody>
        {#each users as u (u.id)}
          <tr>
            <td><button class="link" onclick={() => go('owner', u.id)}>{u.name}</button><br /><small class="muted">{u.email}</small></td>
            <td>{u.cpf ?? '—'}</td>
            <td>{u.phone}</td>
            <td>{u.address}, {u.city} - {u.cep}</td>
            <td>{u.dogs}</td>
            <td>{u.reports}</td>
            <td>
              {#if u.banned_at}<span class="chip error" title={u.ban_reason}>Bloqueado</span>
              {:else if !u.is_admin}<button class="danger" onclick={() => ban(u)}>Bloquear</button>{/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}

<style>
  .tabs { display: flex; border-bottom: 1px solid var(--md-outline-variant); margin-bottom: 16px; }
  .tabs button {
    height: 48px;
    border: none;
    border-radius: 0;
    color: var(--md-on-surface-variant);
    border-bottom: 3px solid transparent;
    padding: 0 24px;
  }
  .tabs button.active { color: var(--md-primary); border-bottom-color: var(--md-primary); }
  .tabs .badge { margin-left: 4px; }
  .small { font-size: 14px; line-height: 20px; }
  .people { margin: 12px 0; gap: 12px; }
  .people .card { margin: 0; }
  .end { justify-content: flex-end; }
  .search {
    display: flex;
    align-items: center;
    gap: 16px;
    height: 56px;
    border-radius: 28px;
    background: var(--md-surface-container-high);
    padding: 0 16px;
    margin-bottom: 16px;
    color: var(--md-on-surface-variant);
  }
  .search input { border: none; min-height: 0; padding: 0; height: 100%; }
  .search input:focus { border: none; padding: 0; }
  .table { padding: 0; overflow-x: auto; }
  td .chip { margin: 0; }
</style>
