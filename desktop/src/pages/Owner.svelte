<script>
  // Perfil público do dono: cães que tem e já teve, e incidentes confirmados.
  import { onMount } from 'svelte';
  import { api, formatDate } from '../lib/api.js';
  import { go, showError } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';

  let { id } = $props();
  let u = $state(null);
  onMount(async () => (u = await api('GET', `/users/${id}`).catch(showError)));
</script>

{#if u}
  <h1>👤 {u.first_name}</h1>
  <p class="muted">{u.city} • no All Love desde {formatDate(u.member_since)}</p>
  {#if u.banned}<p class="card bad">⛔ Conta bloqueada</p>{/if}
  <p class={u.confirmed_incidents ? 'bad' : 'ok'}>
    {u.confirmed_incidents ? `⚠️ ${u.confirmed_incidents} incidente(s) confirmado(s)` : '✅ Nenhum incidente confirmado'}
  </p>
  <h3>Cães deste dono</h3>
  {#each u.dogs as d (d.id)}
    <div class="card row">
      <DogAvatar photo={d.photo_url} />
      <div class="grow">
        <button class="link" onclick={() => go('dog', d.id)}><strong>{d.name}</strong></button> ({d.breed})<br />
        <small class="muted">
          {d.current ? `Desde ${formatDate(d.since)}` : `De ${formatDate(d.since)} até ${formatDate(d.until)}`}
        </small>
      </div>
    </div>
  {/each}
{/if}
