<script>
  import { api, lookupCep, setToken } from '../lib/api.js';
  import { app, showError, toast, updateLocation } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let mode = $state('login');
  let loading = $state(false);
  let form = $state({
    name: '', email: '', password: '', phone: '', cpf: '', cep: '', city: '', address: '', accepted_terms: false,
  });

  async function fillCep() {
    const data = await lookupCep(form.cep);
    if (data) {
      form.city = `${data.localidade} - ${data.uf}`;
      form.address = `${data.logradouro}, nº , ${data.bairro}`;
    }
  }

  async function submit(e) {
    e.preventDefault();
    if (mode === 'register' && !form.accepted_terms) return toast('Aceite os termos de uso e a política de privacidade');
    loading = true;
    try {
      const data =
        mode === 'login'
          ? await api('POST', '/auth/login', { email: form.email, password: form.password })
          : await api('POST', '/auth/register', form);
      setToken(data.token);
      app.me = data.user;
      updateLocation();
    } catch (err) {
      showError(err);
    } finally {
      loading = false;
    }
  }
</script>

<div class="wrap">
  <span class="deco d1 shape-cookie9"></span>
  <span class="deco d2 shape-flower"></span>
  <span class="deco d3 shape-blob"></span>
  <span class="deco d4 shape-cookie12"></span>
  <form class="card" onsubmit={submit}>
    <div class="logo shape-cookie9"><Icon name="pets" filled size={44} /></div>
    <h1>All Love</h1>
    <p class="muted">A rede social dos cachorros</p>

    {#if mode === 'register'}
      <p class="muted info">
        <Icon name="shield" size={18} />
        CPF, telefone e endereço são pedidos para a segurança de todos e só a moderação tem acesso a eles.
      </p>
      <label>Nome completo <input bind:value={form.name} required /></label>
    {/if}
    <label>E-mail <input type="email" bind:value={form.email} required /></label>
    <label>Senha <input type="password" bind:value={form.password} required minlength="6" /></label>
    {#if mode === 'register'}
      <div class="grid2">
        <label>Telefone com DDD <input bind:value={form.phone} placeholder="(11) 91234-5678" required /></label>
        <label>CPF <input bind:value={form.cpf} placeholder="000.000.000-00" required /></label>
        <label>CEP <input bind:value={form.cep} onblur={fillCep} required /></label>
        <label>Cidade <input bind:value={form.city} required /></label>
      </div>
      <label>Endereço <input bind:value={form.address} required /></label>
      <label class="check">
        <input type="checkbox" bind:checked={form.accepted_terms} />
        Li e aceito os termos de uso e a política de privacidade (LGPD)
      </label>
    {/if}

    <button class="primary full" disabled={loading}>
      {loading ? 'Aguarde...' : mode === 'login' ? 'Entrar' : 'Criar conta'}
    </button>
    <button type="button" class="text full" onclick={() => (mode = mode === 'login' ? 'register' : 'login')}>
      {mode === 'login' ? 'Não tem conta? Cadastre-se' : 'Já tenho conta'}
    </button>
  </form>
</div>

<style>
  .wrap { min-height: 100vh; display: grid; place-items: center; background: var(--md-primary-container); padding: 16px; position: relative; overflow: hidden; }
  form { width: 100%; max-width: 480px; text-align: center; padding: 32px 28px 16px; border-radius: 48px; position: relative; z-index: 1; background: var(--md-surface); }
  .deco { position: absolute; animation: float 9s ease-in-out infinite; }
  .d1 { width: 320px; height: 320px; background: var(--like); top: -60px; left: -80px; }
  .d2 { width: 240px; height: 240px; background: var(--md-primary); bottom: -40px; right: 8%; animation-delay: -3s; }
  .d3 { width: 180px; height: 180px; background: var(--md-tertiary); top: 18%; right: -40px; animation-delay: -6s; }
  .d4 { width: 120px; height: 120px; background: var(--md-on-primary-container); bottom: 14%; left: 10%; animation-delay: -1.5s; }
  @keyframes float { 50% { transform: translateY(-24px) rotate(25deg); } }
  form label { text-align: left; }
  .logo {
    width: 88px;
    height: 88px;
    margin: 0 auto 12px;
    background: var(--like);
    color: #231b00;
    display: grid;
    place-items: center;
  }
  h1 { color: var(--md-primary); margin-bottom: 4px; font-size: 64px; line-height: 64px; }
  .info { text-align: left; font-size: 14px; line-height: 20px; margin: 16px 0; }
  .full { width: 100%; margin-top: 8px; }
</style>
