<script>
  import { imageUrl } from './api.js';
  let { photo, size = 48 } = $props();
</script>

<div class="avatar" style="width:{size}px;height:{size}px;font-size:{size / 2}px">
  {#if photo}<img src={imageUrl(photo)} alt="" />{:else}🐶{/if}
</div>

<style>
  .avatar {
    border-radius: 50%;
    background: var(--blue-light);
    display: grid;
    place-items: center;
    overflow: hidden;
    flex-shrink: 0;
  }
  img { width: 100%; height: 100%; object-fit: cover; }
</style>
