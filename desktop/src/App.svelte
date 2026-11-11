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
  import Icon from './lib/Icon.svelte';

  const menu = [
    ['feed', 'photo_library', 'Feed'],
    ['discover', 'swipe', 'Descobrir'],
    ['matches', 'favorite', 'Encontros'],
    ['places', 'park', 'Parques'],
    ['dogs', 'pets', 'Meus cães'],
    ['profile', 'person', 'Perfil'],
  ];
  // páginas de detalhe deixam o item de origem marcado
  const section = $derived(app.page === 'dog' ? 'dogs' : app.page === 'owner' ? 'matches' : app.page);

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
      <div class="brand"><Icon name="pets" filled size={28} /> All Love</div>
      {#each menu as [page, icon, label]}
        <button class="item" class:active={section === page} onclick={() => go(page)}>
          <Icon name={icon} filled={section === page} /> <span>{label}</span>
        </button>
      {/each}
      {#if app.me.is_admin}
        <hr />
        <button class="item" class:active={section === 'admin'} onclick={() => go('admin')}>
          <Icon name="shield_person" filled={section === 'admin'} /> <span>Moderação</span>
        </button>
      {/if}
      <div class="grow"></div>
      <div class="who">{app.me.name}</div>
      <button class="item" onclick={logout}><Icon name="logout" /> <span>Sair</span></button>
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
  <div class="snackbar" role="status">{app.toast}</div>
{/if}

<style>
  .layout { display: flex; min-height: 100vh; }
  /* Navigation drawer padrão do Material 3 */
  nav {
    width: 280px;
    flex-shrink: 0;
    background: var(--md-surface-container-low);
    display: flex;
    flex-direction: column;
    padding: 12px;
    position: sticky;
    top: 0;
    height: 100vh;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 12px;
    color: var(--md-primary);
    font-size: 22px;
    line-height: 28px;
    padding: 16px 16px 20px;
  }
  .item {
    height: 56px;
    border: none;
    border-radius: 28px;
    justify-content: flex-start;
    gap: 12px;
    padding: 0 24px 0 16px;
    color: var(--md-on-surface-variant);
  }
  .item :global(.icon) { font-size: 24px; margin: 0; }
  .item.active { background: var(--md-secondary-container); color: var(--md-on-secondary-container); }
  nav hr { margin: 8px 16px; }
  .who { color: var(--md-on-surface-variant); padding: 0 16px 8px; font-size: 14px; }
  main { flex: 1; padding: 16px 32px 32px; max-width: 1040px; min-width: 0; }
  .snackbar {
    position: fixed;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    background: var(--md-inverse-surface);
    color: var(--md-inverse-on-surface);
    padding: 14px 16px;
    border-radius: 4px;
    box-shadow: var(--md-elevation-3);
    font-size: 14px;
    line-height: 20px;
    max-width: min(560px, 90vw);
    z-index: 10;
  }
  /* telas estreitas: barra de navegação embaixo */
  @media (max-width: 760px) {
    .layout { flex-direction: column; }
    main { padding: 16px 16px 96px; }
    nav {
      position: fixed;
      top: auto;
      bottom: 0;
      left: 0;
      right: 0;
      width: auto;
      height: 80px;
      flex-direction: row;
      padding: 12px 4px 16px;
      background: var(--md-surface-container);
      z-index: 5;
      overflow-x: auto;
    }
    .brand, .who, .grow, nav hr { display: none; }
    .item { flex: 1; flex-direction: column; height: 52px; padding: 0 4px; gap: 4px; font-size: 12px; border-radius: 16px; min-width: 64px; }
    .item.active { background: transparent; }
    .item.active :global(.icon) { background: var(--md-secondary-container); border-radius: 16px; padding: 4px 20px; }
  }
</style>
