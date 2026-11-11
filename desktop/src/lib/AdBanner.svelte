<script>
  // Anúncio de patrocinador. Usuários premium não recebem anúncios.
  import { onMount } from 'svelte';
  import { api } from './api.js';

  let ad = $state(null);
  onMount(async () => {
    ad = (await api('GET', '/ads/random').catch(() => ({ ad: null }))).ad;
  });
</script>

{#if ad}
  <div class="ad">
    <span>🏪 <strong>{ad.sponsor}</strong> — {ad.message}</span>
    <small>Anúncio</small>
  </div>
{/if}

<style>
  .ad {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    background: var(--ad);
    border-radius: 12px;
    padding: 12px 16px;
    margin-bottom: 16px;
  }
  small { color: var(--muted); }
</style>
