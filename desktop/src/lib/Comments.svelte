<script>
  // Comentários de uma publicação do feed.
  import { onMount } from 'svelte';
  import { api } from './api.js';
  import { app, showError } from './state.svelte.js';
  import DogAvatar from './DogAvatar.svelte';
  import Icon from './Icon.svelte';

  let { postId, oncount } = $props();
  let items = $state([]);
  let text = $state('');

  async function load() {
    items = await api('GET', `/posts/${postId}/comments`).catch((e) => (showError(e), []));
    oncount?.(items.length);
  }
  onMount(load);

  async function send(e) {
    e.preventDefault();
    if (!text.trim()) return;
    try {
      await api('POST', `/posts/${postId}/comments`, { text });
      text = '';
      load();
    } catch (err) { showError(err); }
  }

  async function remove(c) {
    try { await api('DELETE', `/comments/${c.id}`); load(); } catch (err) { showError(err); }
  }
</script>

<div class="comments rise">
  {#each items as c (c.id)}
    <div class="c">
      <span class="shape-cookie12 av"><DogAvatar photo={c.author_photo} size={32} /></span>
      <div class="bubble"><strong>{c.author}</strong> {c.text}</div>
      {#if c.user_id === app.me.id || app.me.is_admin}
        <button class="icon-btn" onclick={() => remove(c)} aria-label="Apagar"><Icon name="close" /></button>
      {/if}
    </div>
  {:else}
    <p class="muted">Seja o primeiro a comentar!</p>
  {/each}
  <form class="row" onsubmit={send}>
    <input bind:value={text} placeholder="Escreva um comentário..." maxlength="500" />
    <button class="primary icon-only" aria-label="Enviar"><Icon name="send" /></button>
  </form>
</div>

<style>
  .comments { padding: 8px 8px 4px; display: flex; flex-direction: column; gap: 8px; }
  .c { display: flex; align-items: flex-start; gap: 8px; }
  .av { display: grid; flex-shrink: 0; }
  .bubble { background: var(--md-surface-container-high); padding: 8px 14px; border-radius: 18px 18px 18px 4px; font-size: 14px; line-height: 19px; flex: 1; }
  .bubble strong { font-weight: 700; margin-right: 4px; }
  .c .icon-btn { width: 32px; height: 32px; }
  form input { min-height: 44px; padding: 10px 16px; border-radius: 22px; }
  form input:focus { padding: 9px 15px; }
  .icon-only { width: 44px; height: 44px; padding: 0; flex-shrink: 0; }
  .icon-only :global(.icon) { margin: 0; }
</style>
