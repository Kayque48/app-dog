<script>
  import { onMount } from 'svelte';
  import { api, isLoggedIn, setToken } from './lib/api.js';
  import { app, go, loadMe, updateLocation } from './lib/state.svelte.js';
  import Login from './pages/Login.svelte';
  import Feed from './pages/Feed.svelte';
  import Discover from './pages/Discover.svelte';
  import Matches from './pages/Matches.svelte';
  import Places from './pages/Places.svelte';
  import MyDogs from './pages/MyDogs.svelte';
  import DogDetail from './pages/DogDetail.svelte';
  import Owner from './pages/Owner.svelte';
  import Profile from './pages/Profile.svelte';
  import Admin from './pages/Admin.svelte';

  const menu = [
    ['feed', '📷 Feed'],
    ['discover', '🐾 Descobrir'],
    ['matches', '❤️ Encontros'],
    ['places', '🌳 Parques'],
    ['dogs', '🐶 Meus cães'],
    ['profile', '👤 Perfil'],
  ];

  onMount(async () => {
    if (isLoggedIn()) {
      await loadMe();
      updateLocation();
    }
  });

  async function logout() {
    await api('POST', '/auth/logout').catch(() => {});
    setToken(null);
    app.me = null;
    go('feed');
  }
</script>

{#if !app.me}
  <Login />
{:else}
  <div class="layout">
    <nav>
      <div class="brand">🐾 All Love</div>
      {#each menu as [page, label]}
        <button class:active={app.page === page} onclick={() => go(page)}>{label}</button>
      {/each}
      {#if app.me.is_admin}
        <button class:active={app.page === 'admin'} onclick={() => go('admin')}>🛡️ Moderação</button>
      {/if}
      <div class="grow"></div>
      <div class="who">{app.me.name}</div>
      <button onclick={logout}>Sair</button>
    </nav>
    <main>
      {#key app.page + app.param}
        {#if app.page === 'feed'}<Feed />
        {:else if app.page === 'discover'}<Discover />
        {:else if app.page === 'matches'}<Matches />
        {:else if app.page === 'places'}<Places />
        {:else if app.page === 'dogs'}<MyDogs />
        {:else if app.page === 'dog'}<DogDetail id={app.param} />
        {:else if app.page === 'owner'}<Owner id={app.param} />
        {:else if app.page === 'profile'}<Profile />
        {:else if app.page === 'admin'}<Admin />
        {/if}
      {/key}
    </main>
  </div>
{/if}

{#if app.toast}
  <div class="toast">{app.toast}</div>
{/if}

<style>
  .layout { display: flex; min-height: 100vh; }
  nav {
    width: 220px;
    flex-shrink: 0;
    background: var(--blue);
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 16px 12px;
    position: sticky;
    top: 0;
    height: 100vh;
  }
  nav button { border: none; background: transparent; color: var(--white); text-align: left; font-size: 1.05rem; }
  nav button.active, nav button:hover { background: rgba(255, 255, 255, 0.25); }
  .brand { color: var(--white); font-size: 1.5rem; font-weight: bold; padding: 8px 12px 20px; }
  .who { color: var(--white); padding: 0 12px; font-size: 0.9rem; }
  main { flex: 1; padding: 24px 32px; max-width: 980px; }
  .toast {
    position: fixed;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    background: var(--text);
    color: var(--white);
    padding: 12px 20px;
    border-radius: 12px;
    max-width: 90vw;
  }
  @media (max-width: 700px) {
    .layout { flex-direction: column; }
    nav { width: auto; height: auto; position: static; flex-direction: row; flex-wrap: wrap; }
    .brand, .who, .grow { display: none; }
    main { padding: 16px; }
  }
</style>
