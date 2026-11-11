<script>
  import { onMount } from 'svelte';
  import { api, imageUrl, upload } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import AdBanner from '../lib/AdBanner.svelte';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import Icon from '../lib/Icon.svelte';

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

<div class="page-header"><h1>Feed</h1></div>
<AdBanner />

{#if myDogs.length}
  <form class="card outlined publish" onsubmit={publish}>
    <h3>Publicar foto</h3>
    <div class="row wrap">
      <label>Cão
        <select bind:value={newPost.dog_id}>
          {#each myDogs as d}<option value={d.id}>{d.name}</option>{/each}
        </select>
      </label>
      <label>Foto <input type="file" accept="image/*" onchange={(e) => (newPost.file = e.target.files[0])} /></label>
      <label class="grow">Legenda <input bind:value={newPost.caption} /></label>
    </div>
    <button class="primary" disabled={sending}><Icon name="add_a_photo" /> {sending ? 'Publicando...' : 'Publicar'}</button>
  </form>
{/if}

{#if posts.length === 0 && end}
  <div class="empty"><Icon name="photo_camera" />Ainda não há fotos. Seja o primeiro a publicar!</div>
{/if}

<div class="posts">
  {#each posts as p (p.id)}
    <article class="card">
      <button class="author text" onclick={() => go('dog', p.dog_id)}>
        <DogAvatar photo={p.dog_photo_url} />
        <span class="names"><span class="name">{p.dog_name}</span><small class="muted">{p.dog_breed}</small></span>
      </button>
      <!-- a pata fica atrás da foto e aparece se ela não carregar -->
      <div class="media" ondblclick={() => !p.liked_by_me && like(p)} role="presentation">
        <Icon name="pets" filled size={96} />
        <img src={imageUrl(p.image_url)} alt="" />
      </div>
      <div class="row">
        <button class="icon-btn" class:liked={p.liked_by_me} onclick={() => like(p)} aria-label="Curtir">
          <Icon name="favorite" filled={p.liked_by_me} />
        </button>
        <span class="muted">{p.likes} curtida(s)</span>
      </div>
      {#if p.caption}<p class="caption">{p.caption}</p>{/if}
    </article>
  {/each}
</div>

{#if !end && posts.length}
  <div class="more"><button onclick={() => load()}>Carregar mais</button></div>
{/if}

<style>
  .publish .row { align-items: flex-end; }
  .publish label { margin-bottom: 12px; }
  .posts { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; }
  article { margin: 0; padding: 0; overflow: hidden; }
  .author { height: 72px; width: 100%; justify-content: flex-start; gap: 16px; padding: 0 16px; border-radius: 0; color: var(--md-on-surface); }
  .names { display: flex; flex-direction: column; align-items: flex-start; }
  .name { font-size: 16px; }
  .media {
    position: relative;
    aspect-ratio: 1;
    display: grid;
    place-items: center;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
  }
  .media img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  article .row { padding: 4px 8px 0; gap: 4px; }
  .liked { color: var(--md-error); }
  .caption { padding: 0 16px 16px; }
  .more { text-align: center; margin-top: 16px; }
</style>
