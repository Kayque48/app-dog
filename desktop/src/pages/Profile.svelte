<script>
  import { api, setToken } from '../lib/api.js';
  import { app, showError, toast, updateLocation } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let form = $state({ ...app.me });
  const coord = (v) => (v == null ? '' : Number(v.toFixed(5)));
  let lat = $state(coord(app.me.lat));
  let lng = $state(coord(app.me.lng));

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
      lat = coord(app.me.lat);
      lng = coord(app.me.lng);
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

<div class="page-header">
  <div class="avatar"><Icon name="person" filled /></div>
  <div class="grow">
    <h1>{app.me.name}</h1>
    <small class="muted">{app.me.email} · CPF {app.me.cpf ?? '—'}</small>
  </div>
</div>

<div class="card outlined row premium">
  <Icon name="workspace_premium" />
  <div class="grow">
    <div>All Love Premium</div>
    <small class="muted">Use o app sem anúncios</small>
  </div>
  <input type="checkbox" class="switch" checked={app.me.is_premium} onchange={setPremium} aria-label="Premium" />
</div>

<form class="card outlined" onsubmit={save}>
  <h3>Meus dados</h3>
  <div class="grid2">
    <label>Nome <input bind:value={form.name} required /></label>
    <label>Telefone <input bind:value={form.phone} required /></label>
    <label>CEP <input bind:value={form.cep} required /></label>
    <label>Cidade <input bind:value={form.city} required /></label>
  </div>
  <label>Endereço <input bind:value={form.address} required /></label>
  <div class="row end"><button class="primary">Salvar</button></div>
</form>

<form class="card outlined" onsubmit={saveLocation}>
  <h3>Minha localização</h3>
  <p class="muted small">
    Usada para achar cães e parques perto de você. Ninguém vê sua posição exata, só a distância aproximada.
    Se o computador não tiver GPS, copie as coordenadas do Google Maps (clique com o botão direito no mapa).
  </p>
  <div class="grid2">
    <label>Latitude <input bind:value={lat} placeholder="-23.5874" required /></label>
    <label>Longitude <input bind:value={lng} placeholder="-46.6576" required /></label>
  </div>
  <div class="row end">
    <button type="button" onclick={useGps}><Icon name="my_location" /> Usar localização do computador</button>
    <button class="primary">Salvar coordenadas</button>
  </div>
</form>

<div class="card outlined row">
  <Icon name="privacy_tip" />
  <div class="grow">
    <div>Privacidade</div>
    <small class="muted">Apaga seus dados pessoais (LGPD)</small>
  </div>
  <button class="danger" onclick={deleteAccount}>Excluir minha conta</button>
</div>

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
  .row > :global(.icon) { color: var(--md-on-surface-variant); }
  .small { font-size: 14px; line-height: 20px; }
  .end { justify-content: flex-end; }
</style>
