<script>
  import { onMount } from 'svelte';
  import { api, imageUrl, upload } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import AdBanner from '../lib/AdBanner.svelte';
  import DogAvatar from '../lib/DogAvatar.svelte';

  let posts = $state([]);
  let page = 0;
  let end = $state(false);
  let myDogs = $state([]);
  let newPost = $state({ dog_id: null, caption: '', file: null });
  let sending = $state(false);

  async function load(reset = false) {
    if (reset) { page = 0; end = false; posts = []; }
    try {
      const data = await api('GET', `/feed?page=${page}`);
      posts = [...posts, ...data];
      page++;
      end = data.length < 20;
    } catch (e) { showError(e); }
  }

  onMount(async () => {
    load();
    myDogs = (await api('GET', '/dogs/mine').catch(() => [])).filter((d) => !d.removed_at);
    newPost.dog_id = myDogs[0]?.id ?? null;
  });

  async function like(p) {
    try {
      const r = await api('POST', `/posts/${p.id}/like`);
      p.liked_by_me = r.liked;
      p.likes = r.likes;
    } catch (e) { showError(e); }
  }

  async function publish(e) {
    e.preventDefault();
    if (!newPost.file) return toast('Escolha uma foto');
    sending = true;
    try {
      const url = await upload(newPost.file);
      await api('POST', '/posts', { dog_id: newPost.dog_id, image_url: url, caption: newPost.caption });
      newPost.caption = '';
      newPost.file = null;
      e.target.reset();
      load(true);
    } catch (err) { showError(err); } finally { sending = false; }
  }
</script>

<h1>Feed</h1>
<AdBanner />

{#if myDogs.length}
  <form class="card row wrap" onsubmit={publish}>
    <select bind:value={newPost.dog_id} style="width:auto">
      {#each myDogs as d}<option value={d.id}>{d.name}</option>{/each}
    </select>
    <input type="file" accept="image/*" style="width:auto" onchange={(e) => (newPost.file = e.target.files[0])} />
    <input class="grow" placeholder="Legenda" bind:value={newPost.caption} style="width:auto" />
    <button class="primary" disabled={sending}>{sending ? 'Publicando...' : 'Publicar foto'}</button>
  </form>
{/if}

{#if posts.length === 0 && end}
  <p class="empty">Ainda não há fotos. Seja o primeiro a publicar!</p>
{/if}

<div class="posts">
  {#each posts as p (p.id)}
    <article class="card">
      <button class="author link" onclick={() => go('dog', p.dog_id)}>
        <DogAvatar photo={p.dog_photo_url} size={40} />
        <span><strong>{p.dog_name}</strong><br /><small class="muted">{p.dog_breed}</small></span>
      </button>
      <img src={imageUrl(p.image_url)} alt={p.caption} ondblclick={() => !p.liked_by_me && like(p)} />
      <div class="row">
        <button class="like" onclick={() => like(p)}>{p.liked_by_me ? '❤️' : '🤍'} {p.likes}</button>
        <span>{p.caption}</span>
      </div>
    </article>
  {/each}
</div>

{#if !end && posts.length}
  <button onclick={() => load()}>Carregar mais</button>
{/if}

<style>
  .posts { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; }
  article { margin: 0; }
  .author { display: flex; gap: 10px; align-items: center; text-decoration: none; color: inherit; text-align: left; margin-bottom: 8px; }
  img { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 12px; background: var(--blue-light); }
  .like { border: none; font-size: 1.1rem; padding: 6px 8px; }
</style>
