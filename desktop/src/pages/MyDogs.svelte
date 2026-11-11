<script>
  import { onMount } from 'svelte';
  import { ageText, api, vaccineText } from '../lib/api.js';
  import { go, showError } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import DogForm from '../lib/DogForm.svelte';

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

<div class="row">
  <h1 class="grow">Meus cães</h1>
  {#if !editing}<button class="primary" onclick={() => (editing = 'new')}>+ Cadastrar cão</button>{/if}
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
  <p class="empty">Você ainda não cadastrou nenhum cão.</p>
{/if}

{#each current as d (d.id)}
  <div class="card row">
    <DogAvatar photo={d.photo_url} />
    <div class="grow">
      <button class="link" onclick={() => go('dog', d.id)}><strong>{d.name}</strong></button> • {d.breed} • {ageText(d.age_years)}<br />
      <small class={d.vaccine_status.up_to_date ? 'ok' : 'bad'}>{vaccineText(d.vaccine_status)}</small>
    </div>
    <button onclick={() => (editing = d)}>Editar</button>
    <button class="danger" onclick={() => remove(d)}>Remover</button>
  </div>
{/each}

{#if past.length}
  <h3>Cães que já tive</h3>
  {#each past as d (d.id)}
    <div class="card row">
      <DogAvatar photo={d.photo_url} size={36} />
      <button class="link grow" style="text-align:left" onclick={() => go('dog', d.id)}>{d.name} ({d.breed})</button>
    </div>
  {/each}
{/if}
