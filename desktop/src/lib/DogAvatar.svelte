<script>
  import { imageUrl } from './api.js';
  import Icon from './Icon.svelte';
  let { photo, size = 40 } = $props();
  let failed = $state(false); // sem internet ou foto removida: mostra a pata
</script>

<div class="avatar" style="width:{size}px;height:{size}px">
  {#if photo && !failed}<img src={imageUrl(photo)} alt="" onerror={() => (failed = true)} />{:else}<Icon name="pets" filled size={size * 0.55} />{/if}
</div>

<style>
  .avatar {
    border-radius: 50%;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
    display: grid;
    place-items: center;
    overflow: hidden;
    flex-shrink: 0;
  }
  img { width: 100%; height: 100%; object-fit: cover; }
</style>
