<script>
  // Perfil público do dono: cães que tem e já teve, e incidentes confirmados.
  import { onMount } from 'svelte';
  import { api, formatDate } from '../lib/api.js';
  import { go, showError } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import Icon from '../lib/Icon.svelte';

  let { id } = $props();
  let u = $state(null);
  onMount(async () => (u = await api('GET', `/users/${id}`).catch(showError)));
</script>

{#if u}
  <div class="page-header">
    <div class="avatar"><Icon name="person" filled /></div>
    <div class="grow">
      <h1>{u.first_name}</h1>
      <small class="muted">{u.city} · no All Love desde {formatDate(u.member_since)}</small>
    </div>
  </div>
  {#if u.banned}<div class="card error row"><Icon name="block" /> Conta bloqueada</div>{/if}
  {#if u.confirmed_incidents}
    <span class="chip error"><Icon name="warning" /> {u.confirmed_incidents} incidente(s) confirmado(s)</span>
  {:else}
    <span class="chip success"><Icon name="verified_user" /> Nenhum incidente confirmado</span>
  {/if}

  <h2>Cães deste dono</h2>
  <div class="card outlined">
    {#each u.dogs as d (d.id)}
      <div class="list-item">
        <DogAvatar photo={d.photo_url} />
        <div class="grow">
          <button class="link" onclick={() => go('dog', d.id)}>{d.name}</button> <span class="muted">· {d.breed}</span><br />
          <small class="muted">
            {d.current ? `Desde ${formatDate(d.since)}` : `De ${formatDate(d.since)} até ${formatDate(d.until)}`}
          </small>
        </div>
        {#if d.current}<span class="chip tonal">Atual</span>{/if}
      </div>
    {/each}
  </div>
{/if}

<style>
  .page-header h1 { flex: none; }
  .avatar {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
    display: grid;
    place-items: center;
  }
  .list-item .chip { margin: 0; }
</style>
