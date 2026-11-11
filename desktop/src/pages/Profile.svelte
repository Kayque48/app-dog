<script>
  import { api, setToken } from '../lib/api.js';
  import { app, showError, toast, updateLocation } from '../lib/state.svelte.js';

  let form = $state({ ...app.me });
  let lat = $state(app.me.lat ?? '');
  let lng = $state(app.me.lng ?? '');

  async function save(e) {
    e.preventDefault();
    try {
      app.me = await api('PUT', '/me', { name: form.name, phone: form.phone, cep: form.cep, city: form.city, address: form.address });
      toast('Dados atualizados');
    } catch (err) { showError(err); }
  }

  async function setPremium(e) {
    try { app.me = await api('PUT', '/me/premium', { premium: e.target.checked }); } catch (err) { showError(err); }
  }

  async function useGps() {
    if (await updateLocation()) {
      app.me = await api('GET', '/me');
      lat = app.me.lat;
      lng = app.me.lng;
      toast('Localização atualizada');
    } else toast('Não foi possível ler a localização deste computador. Informe manualmente.');
  }

  async function saveLocation(e) {
    e.preventDefault();
    try {
      await api('PUT', '/me/location', { lat: Number(lat), lng: Number(lng) });
      app.me = await api('GET', '/me');
      toast('Localização salva');
    } catch (err) { showError(err); }
  }

  async function deleteAccount() {
    if (!confirm('Excluir sua conta? Seus dados pessoais serão apagados (LGPD). Essa ação não pode ser desfeita.')) return;
    try {
      await api('DELETE', '/me');
      setToken(null);
      app.me = null;
    } catch (err) { showError(err); }
  }
</script>

<h1>Perfil</h1>

<form class="card" onsubmit={save}>
  <h3>Meus dados</h3>
  <p class="muted">E-mail: {app.me.email} • CPF: {app.me.cpf ?? '—'}</p>
  <div class="grid2">
    <label>Nome <input bind:value={form.name} required /></label>
    <label>Telefone <input bind:value={form.phone} required /></label>
    <label>CEP <input bind:value={form.cep} required /></label>
    <label>Cidade <input bind:value={form.city} required /></label>
  </div>
  <label>Endereço <input bind:value={form.address} required /></label>
  <button class="primary">Salvar</button>
</form>

<form class="card" onsubmit={saveLocation}>
  <h3>Minha localização</h3>
  <p class="muted">
    Usada para achar cães e parques perto de você. Ninguém vê sua posição exata, só a distância aproximada.
    Se o computador não tiver GPS, copie as coordenadas do Google Maps (clique com o botão direito no mapa).
  </p>
  <div class="row wrap">
    <label>Latitude <input bind:value={lat} placeholder="-23.5874" required /></label>
    <label>Longitude <input bind:value={lng} placeholder="-46.6576" required /></label>
  </div>
  <div class="row">
    <button type="button" onclick={useGps}>📍 Usar localização do computador</button>
    <button class="primary">Salvar coordenadas</button>
  </div>
</form>

<div class="card">
  <h3>All Love Premium</h3>
  <label class="check"><input type="checkbox" checked={app.me.is_premium} onchange={setPremium} /> Premium (sem anúncios)</label>
</div>

<div class="card">
  <h3>Privacidade</h3>
  <button class="danger" onclick={deleteAccount}>Excluir minha conta</button>
</div>
