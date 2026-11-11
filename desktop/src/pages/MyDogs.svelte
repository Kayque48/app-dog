<script>
  import { onMount } from 'svelte';
  import { ageText, api, vaccineText } from '../lib/api.js';
  import { go, showError } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import DogForm from '../lib/DogForm.svelte';
  import Icon from '../lib/Icon.svelte';

  let dogs = $state([]);
  let editing = $state(null); // null = fechado, 'new' = novo, ou o cão
  const load = async () => (dogs = await api('GET', '/dogs/mine').catch((e) => (showError(e), [])));
  onMount(load);

  const current = $derived(dogs.filter((d) => !d.removed_at));
  const past = $derived(dogs.filter((d) => d.removed_at));

  async function remove(d) {
    if (!confirm(`Remover ${d.name}? Ele sai do seu perfil mas continua no histórico.`)) return;
    try { await api('DELETE', `/dogs/${d.id}`); load(); } catch (e) { showError(e); }
  }
</script>

<div class="page-header">
  <h1>Meus cães</h1>
  {#if !editing}<button class="primary" onclick={() => (editing = 'new')}><Icon name="add" /> Cadastrar cão</button>{/if}
</div>

{#if editing}
  {#key editing}
    <DogForm
      dog={editing === 'new' ? null : editing}
      onsaved={(d) => { editing = null; load(); go('dog', d.id); }}
      oncancel={() => (editing = null)}
    />
  {/key}
{/if}

{#if current.length === 0 && !editing}
  <div class="empty"><Icon name="pets" />Você ainda não cadastrou nenhum cão.</div>
{/if}

{#each current as d (d.id)}
  <div class="card outlined row">
    <DogAvatar photo={d.photo_url} size={56} />
    <div class="grow">
      <button class="link" onclick={() => go('dog', d.id)}>{d.name}</button>
      <span class="muted">· {d.breed} · {ageText(d.age_years)}</span><br />
      <span class="chip {d.vaccine_status.up_to_date ? 'success' : 'error'} status">
        <Icon name={d.vaccine_status.up_to_date ? 'verified' : 'block'} /> {vaccineText(d.vaccine_status)}
      </span>
    </div>
    <button class="icon-btn" onclick={() => (editing = d)} aria-label="Editar"><Icon name="edit" /></button>
    <button class="icon-btn" onclick={() => remove(d)} aria-label="Remover"><Icon name="delete" /></button>
  </div>
{/each}

{#if past.length}
  <h2>Cães que já tive</h2>
  <div class="card outlined">
    {#each past as d (d.id)}
      <div class="list-item">
        <DogAvatar photo={d.photo_url} />
        <button class="link grow" style="text-align:left" onclick={() => go('dog', d.id)}>{d.name}</button>
        <span class="muted">{d.breed}</span>
      </div>
    {/each}
  </div>
{/if}

<style>
  .status { margin: 8px 0 0; }
</style>
