<script>
  import { onMount } from 'svelte';
  import { api, formatDistance, openExternal, placeKinds } from '../lib/api.js';
  import { showError, toast } from '../lib/state.svelte.js';
  import AdBanner from '../lib/AdBanner.svelte';

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
      load();
    } catch (err) { showError(err); }
  }
</script>

<h1>Parques e pontos de encontro</h1>
<p class="muted">Os 5 locais mais perto de você.</p>

{#if error}
  <p class="empty bad">{error}</p>
{:else if places}
  {#each places as p (p.id)}
    <div class="card row">
      <span style="font-size:2rem">{p.kind === 'parque' ? '🌳' : '📍'}</span>
      <div class="grow">
        <strong>{p.name}</strong> <span class="chip">{placeKinds[p.kind]}</span><br />
        <small class="muted">{formatDistance(p.distance_m)} • {p.address}</small>
      </div>
      <button onclick={() => openExternal(`https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}`)}>Abrir no mapa</button>
    </div>
  {/each}
{/if}

<AdBanner />

<form class="card" onsubmit={add}>
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
  <button class="primary">Salvar</button>
</form>
