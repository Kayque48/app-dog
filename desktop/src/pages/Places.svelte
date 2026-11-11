<script>
  import { onMount } from 'svelte';
  import { api, formatDistance, openExternal, placeKinds } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import AdBanner from '../lib/AdBanner.svelte';
  import Icon from '../lib/Icon.svelte';

  const kindIcon = { parque: 'park', praca: 'nature_people', ponto_encontro: 'location_on' };
  let places = $state(null);
  let error = $state(null);
  let form = $state({ name: '', kind: 'ponto_encontro', address: '' });

  async function load() {
    try {
      places = await api('GET', '/places');
      error = null;
    } catch (e) { error = e.message; }
  }
  onMount(load);

  async function add(e) {
    e.preventDefault();
    const me = await api('GET', '/me');
    if (me.lat == null) return toast('Defina sua localização no Perfil: o ponto será salvo nela.');
    try {
      await api('POST', '/places', { ...form, lat: me.lat, lng: me.lng });
      form = { name: '', kind: 'ponto_encontro', address: '' };
      toast('Ponto de encontro salvo');
      load();
    } catch (err) { showError(err); }
  }
</script>

<div class="page-header"><h1>Parques e pontos de encontro</h1></div>
<p class="muted">Os 5 locais mais perto de você.</p>

{#if error}
  <div class="empty">
    <Icon name="location_off" />
    <p>{error}</p>
    <button class="primary" onclick={() => go('profile')}>Definir localização</button>
  </div>
{:else if places}
  <div class="card outlined list">
    {#each places as p (p.id)}
      <div class="list-item">
        <div class="leading"><Icon name={kindIcon[p.kind]} /></div>
        <div class="grow">
          <div>{p.name}</div>
          <small class="muted">{placeKinds[p.kind]} · {formatDistance(p.distance_m)} · {p.address}</small>
        </div>
        <button class="text" onclick={() => openExternal(`https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}`)}>
          <Icon name="map" /> Mapa
        </button>
      </div>
    {/each}
  </div>
{/if}

<AdBanner />

<form class="card outlined" onsubmit={add}>
  <h3>Sugerir ponto de encontro</h3>
  <p class="muted">Será marcado na sua localização atual.</p>
  <div class="grid2">
    <label>Nome <input bind:value={form.name} required /></label>
    <label>Tipo
      <select bind:value={form.kind}>
        {#each Object.entries(placeKinds) as [k, v]}<option value={k}>{v}</option>{/each}
      </select>
    </label>
  </div>
  <label>Endereço / referência <input bind:value={form.address} /></label>
  <button class="primary"><Icon name="add_location_alt" /> Salvar</button>
</form>

<style>
  .list { padding: 8px 16px; }
  .list-item + .list-item { border-top: 1px solid var(--md-outline-variant); }
  .leading {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
    display: grid;
    place-items: center;
    flex-shrink: 0;
  }
</style>
