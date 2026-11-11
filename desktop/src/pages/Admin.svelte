<script>
  // Moderação: analisar denúncias e bloquear contas permanentemente.
  import { onMount } from 'svelte';
  import { api, formatDate, reportReasons } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';

  let tab = $state('reports');
  let status = $state('aberta');
  let reports = $state([]);
  let users = $state([]);
  let q = $state('');

  const loadReports = async () => (reports = await api('GET', `/admin/reports?status=${status}`).catch((e) => (showError(e), [])));
  const searchUsers = async () => (users = await api('GET', `/admin/users?q=${encodeURIComponent(q)}`).catch((e) => (showError(e), [])));
  onMount(() => { loadReports(); searchUsers(); });

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

<h1>🛡️ Moderação</h1>
<div class="row">
  <button class:primary={tab === 'reports'} onclick={() => (tab = 'reports')}>Denúncias</button>
  <button class:primary={tab === 'users'} onclick={() => (tab = 'users')}>Donos</button>
</div>
<br />

{#if tab === 'reports'}
  <label style="max-width:240px">Situação
    <select bind:value={status} onchange={loadReports}>
      <option value="aberta">Em aberto</option>
      <option value="procedente">Procedentes</option>
      <option value="improcedente">Improcedentes</option>
    </select>
  </label>
  {#if reports.length === 0}<p class="empty">Nenhuma denúncia aqui.</p>{/if}
  {#each reports as r (r.id)}
    <div class="card">
      <div class="row">
        <strong class="grow">#{r.id} — {reportReasons[r.reason] ?? r.reason}</strong>
        <small class="muted">{formatDate(r.created_at)}</small>
      </div>
      <p>{r.details || 'Sem detalhes.'}</p>
      <p class="muted">Denunciado por {r.reporter_name}</p>
      <div class="grid2">
        <div>
          <strong>Dono denunciado</strong> {#if r.target_banned}<span class="chip bad">bloqueado</span>{/if}<br />
          {r.target_name}<br />CPF: {r.target_cpf ?? '—'}<br />Tel.: {r.target_phone}<br />{r.target_email}<br />{r.target_address}<br />
          <small>Total de denúncias contra este dono: {r.target_total_reports}</small>
        </div>
        <div>
          {#if r.target_dog_id}
            <strong>Cão</strong><br /><button class="link" onclick={() => go('dog', r.target_dog_id)}>{r.target_dog_name}</button>
          {/if}
        </div>
      </div>
      {#if r.status === 'aberta'}
        <div class="row wrap" style="margin-top:12px">
          <button onclick={() => resolve(r, false, false)}>Improcedente</button>
          <button onclick={() => resolve(r, true, false)}>Procedente (registrar incidente)</button>
          <button class="danger" onclick={() => resolve(r, true, true)}>Procedente + bloquear conta</button>
        </div>
      {/if}
    </div>
  {/each}
{:else}
  <form class="row" onsubmit={(e) => { e.preventDefault(); searchUsers(); }}>
    <input placeholder="Buscar por nome, e-mail ou CPF" bind:value={q} />
    <button class="primary">Buscar</button>
  </form>
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
            {#if u.banned_at}<span class="bad" title={u.ban_reason}>Bloqueado</span>
            {:else if !u.is_admin}<button class="danger" onclick={() => ban(u)}>Bloquear</button>{/if}
          </td>
        </tr>
      {/each}
    </tbody>
  </table>
{/if}
