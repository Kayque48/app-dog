<script>
  import { api, lookupCep, setToken } from '../lib/api.js';
  import { app, showError, toast, updateLocation } from '../lib/state.svelte.js';

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
  <form class="card" onsubmit={submit}>
    <div class="logo">🐾</div>
    <h1>All Love</h1>
    <p class="muted">A rede social dos cachorros</p>

    {#if mode === 'register'}
      <p class="muted small">
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
    <button type="button" class="link" onclick={() => (mode = mode === 'login' ? 'register' : 'login')}>
      {mode === 'login' ? 'Não tem conta? Cadastre-se' : 'Já tenho conta'}
    </button>
  </form>
</div>

<style>
  .wrap { min-height: 100vh; display: grid; place-items: center; background: var(--blue-light); padding: 16px; }
  form { width: 100%; max-width: 480px; text-align: center; }
  form label { text-align: left; }
  .logo { font-size: 3rem; }
  h1 { color: var(--blue-dark); }
  .small { font-size: 0.9rem; }
  .full { width: 100%; margin: 8px 0; }
</style>
