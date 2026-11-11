<script>
  // Anúncio de patrocinador. Usuários premium não recebem anúncios.
  import { onMount } from 'svelte';
  import { api } from './api.js';
  import Icon from './Icon.svelte';

  let ad = $state(null);
  onMount(async () => {
    ad = (await api('GET', '/ads/random').catch(() => ({ ad: null }))).ad;
  });
</script>

{#if ad}
  <div class="ad">
    <Icon name="storefront" />
    <div class="grow">
      <strong>{ad.sponsor}</strong><br />
      <span>{ad.message}</span>
    </div>
    <small>Anúncio</small>
  </div>
{/if}

<style>
  .ad {
    display: flex;
    align-items: center;
    gap: 16px;
    background: var(--md-tertiary-container);
    color: var(--md-on-tertiary-container);
    border-radius: 12px;
    padding: 12px 16px;
    margin-bottom: 16px;
    font-size: 14px;
    line-height: 20px;
  }
  strong { font-weight: 500; }
</style>
