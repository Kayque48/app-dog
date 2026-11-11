<script>
  // Feed "cheio de vida": stories, post de destaque, grade com formas variadas,
  // blocos misturados (cães perto, parque do dia, anúncio), curtida animada,
  // rolagem infinita e aviso de fotos novas.
  import { onMount } from 'svelte';
  import { ageText, api, eventDate, eventKinds, formatDistance, imageUrl, upload } from '../lib/api.js';
  import { app, go, showError, toast } from '../lib/state.svelte.js';
  import AdBanner from '../lib/AdBanner.svelte';
  import Comments from '../lib/Comments.svelte';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import Icon from '../lib/Icon.svelte';

  let posts = $state([]);
  let page = 0;
  let end = $state(false);
  let loading = false;
  let myDogs = $state([]);
  let nearby = $state([]);
  let park = $state(null);
  let nextEvents = $state([]);
  let composer = $state(false);
  let newPost = $state({ dog_id: null, caption: '', file: null });
  let sending = $state(false);
  let fresh = $state(0); // fotos novas desde que a página abriu
  let hearts = $state({}); // coração gigante do toque duplo, por post
  let popped = $state(null);
  let openComments = $state({}); // id do post -> comentários abertos
  let sentinel;

  // "stories": um círculo por cão que postou recentemente
  const stories = $derived([...new Map(posts.map((p) => [p.dog_id, p])).values()].slice(0, 12));
  const shapes = ['shape-cookie9', 'shape-flower', 'shape-cookie12', 'shape-blob'];

  async function load(reset = false) {
    if (loading || (end && !reset)) return;
    loading = true;
    if (reset) { page = 0; end = false; }
    try {
      const data = await api('GET', `/feed?page=${page}`);
      posts = reset ? data : [...posts, ...data];
      page++;
      end = data.length < 20;
      if (reset) fresh = 0;
    } catch (e) { showError(e); } finally { loading = false; }
  }

  onMount(() => {
    load();
    (async () => {
      myDogs = (await api('GET', '/dogs/mine').catch(() => [])).filter((d) => !d.removed_at);
      newPost.dog_id = myDogs[0]?.id ?? null;
      if (myDogs[0]) nearby = (await api('GET', `/discover?dog_id=${myDogs[0].id}&radius_m=1000`).catch(() => [])).slice(0, 8);
      park = (await api('GET', '/places?limit=1').catch(() => []))[0] ?? null;
      nextEvents = (await api('GET', '/events').catch(() => [])).slice(0, 4);
    })();
    // rolagem infinita
    const io = new IntersectionObserver((entries) => entries[0].isIntersecting && load(), { rootMargin: '600px' });
    io.observe(sentinel);
    // conteúdo constante: verifica fotos novas a cada 20 s
    const timer = setInterval(async () => {
      const latest = await api('GET', '/feed?page=0').catch(() => null);
      if (latest && posts.length) fresh = latest.filter((p) => !posts.some((q) => q.id === p.id)).length;
    }, 20_000);
    return () => { io.disconnect(); clearInterval(timer); };
  });

  async function like(p) {
    popped = p.id;
    setTimeout(() => popped === p.id && (popped = null), 450);
    try {
      const r = await api('POST', `/posts/${p.id}/like`);
      p.liked_by_me = r.liked;
      p.likes = r.likes;
    } catch (e) { showError(e); }
  }

  function doubleTap(p) {
    hearts[p.id] = (hearts[p.id] ?? 0) + 1; // muda a chave e reinicia a animação
    if (!p.liked_by_me) like(p);
  }

  async function publish(e) {
    e.preventDefault();
    if (!newPost.file) return toast('Escolha uma foto ou um vídeo');
    sending = true;
    try {
      const url = await upload(newPost.file);
      await api('POST', '/posts', { dog_id: newPost.dog_id, image_url: url, caption: newPost.caption });
      newPost = { ...newPost, caption: '', file: null };
      composer = false;
      toast('Foto publicada! 🐾');
      load(true);
    } catch (err) { showError(err); } finally { sending = false; }
  }

  const ago = (iso) => {
    const min = Math.max(1, Math.round((Date.now() - new Date(iso.replace(' ', 'T') + 'Z')) / 60000));
    return min < 60 ? `${min} min` : min < 1440 ? `${Math.round(min / 60)} h` : `${Math.round(min / 1440)} d`;
  };
</script>

{#snippet postCard(p, i)}
  <article class="post rise" class:hero={i === 0} style="animation-delay: {Math.min(i, 6) * 40}ms">
    <div class="media r{i % 4}" ondblclick={() => doubleTap(p)} role="presentation">
      <Icon name="pets" filled size={i === 0 ? 140 : 80} />
      {#if p.media_type === 'video'}
        <!-- vídeos tocam sozinhos, sem som, em loop (como num feed de rede social) -->
        <video src={imageUrl(p.image_url)} autoplay muted loop playsinline></video>
        <span class="video-badge"><Icon name="play_circle" filled /></span>
      {:else}
        <img src={imageUrl(p.image_url)} alt="" loading="lazy" />
      {/if}
      {#key hearts[p.id]}
        {#if hearts[p.id]}<span class="big-heart"><Icon name="favorite" filled size={i === 0 ? 180 : 120} /></span>{/if}
      {/key}
      {#if i === 0}
        <div class="overlay">
          <span class="chip tonal hot"><Icon name="local_fire_department" filled /> Em alta</span>
          <p class="display hero-caption">{p.caption || p.dog_name}</p>
        </div>
      {/if}
    </div>
    <div class="meta">
      <button class="author text" onclick={() => go('dog', p.dog_id)}>
        <span class="shape-cookie12 mini"><DogAvatar photo={p.dog_photo_url} size={40} /></span>
        <span class="names"><span class="name">{p.dog_name}</span><small class="muted">{p.dog_breed} · {ago(p.created_at)}</small></span>
      </button>
      <button class="like-btn" class:open={openComments[p.id]} onclick={() => (openComments[p.id] = !openComments[p.id])} aria-label="Comentários">
        <Icon name="chat_bubble" filled={openComments[p.id]} /> <strong>{p.comments}</strong>
      </button>
      <button class="like-btn" class:liked={p.liked_by_me} onclick={() => like(p)} aria-label="Curtir">
        <span class:pop={popped === p.id}><Icon name="favorite" filled={p.liked_by_me} /></span>
        <strong>{p.likes}</strong>
      </button>
    </div>
    {#if p.caption && i !== 0}<p class="caption">{p.caption}</p>{/if}
    {#if openComments[p.id]}<Comments postId={p.id} oncount={(n) => (p.comments = n)} />{/if}
  </article>
{/snippet}

<div class="top">
  <h1 class="grow">Oi, {app.me.name.split(' ')[0]}! <span class="wave">👋</span></h1>
  {#if myDogs.length}
    <button class="primary big" onclick={() => (composer = !composer)}><Icon name={composer ? 'close' : 'add_a_photo'} /> {composer ? 'Fechar' : 'Postar'}</button>
  {/if}
</div>

<!-- stories -->
<div class="stories">
  {#if myDogs[0]}
    <button class="story me" onclick={() => (composer = true)}>
      <span class="ring shape-cookie9"><span class="inner shape-cookie9"><DogAvatar photo={myDogs[0].photo_url} size={72} /></span></span>
      <span class="plus"><Icon name="add" /></span>
      <small>Seu post</small>
    </button>
  {/if}
  {#each stories as s, i (s.dog_id)}
    <button class="story" onclick={() => go('dog', s.dog_id)}>
      <span class="ring {shapes[i % 4]}"><span class="inner {shapes[i % 4]}"><DogAvatar photo={s.dog_photo_url} size={72} /></span></span>
      <small>{s.dog_name}</small>
    </button>
  {/each}
</div>

{#if composer}
  <form class="card composer rise" onsubmit={publish}>
    <h2>O que {myDogs.find((d) => d.id === newPost.dog_id)?.name ?? 'seu cão'} aprontou hoje?</h2>
    <div class="row wrap">
      <label>Cão
        <select bind:value={newPost.dog_id}>{#each myDogs as d}<option value={d.id}>{d.name}</option>{/each}</select>
      </label>
      <label>Foto ou vídeo <input type="file" accept="image/*,video/mp4,video/webm,video/quicktime" onchange={(e) => (newPost.file = e.target.files[0])} /></label>
      <label class="grow">Legenda <input bind:value={newPost.caption} placeholder="Conta tudo!" /></label>
    </div>
    <button class="primary big" disabled={sending}><Icon name="send" /> {sending ? 'Publicando...' : 'Publicar'}</button>
  </form>
{/if}

{#if fresh}
  <button class="fresh primary" onclick={() => { load(true); window.scrollTo({ top: 0, behavior: 'smooth' }); }}>
    <Icon name="arrow_upward" /> {fresh} {fresh === 1 ? 'foto nova' : 'fotos novas'}
  </button>
{/if}

{#if posts.length === 0 && end}
  <div class="empty"><Icon name="photo_camera" />Ainda não há fotos. Seja o primeiro a publicar!</div>
{/if}

<div class="grid">
  {#each posts as p, i (p.id)}
    {@render postCard(p, i)}

    {#if i === 0 && nearby.length}
      <section class="module nearby rise">
        <div class="row">
          <h2 class="grow">Perto de você agora</h2>
          <button class="tonal" onclick={() => go('discover')}>Ver todos <Icon name="arrow_forward" /></button>
        </div>
        <div class="carousel">
          {#each nearby as d, j (d.id)}
            <button class="near" onclick={() => go('discover')}>
              <span class="near-photo {shapes[(j + 1) % 4]}"><Icon name="pets" filled size={48} />{#if d.photo_url}<img src={imageUrl(d.photo_url)} alt="" />{/if}</span>
              <strong>{d.name}</strong>
              <small class="muted">{ageText(d.age_years)} · {formatDistance(d.distance_m)}</small>
              {#if d.wants_to_meet_you}<span class="badge">quer te conhecer!</span>{/if}
            </button>
          {/each}
        </div>
      </section>
    {/if}

    {#if i === 2 && park}
      <section class="module park rise">
        <span class="park-shape shape-flower"><Icon name="park" filled size={56} /></span>
        <div class="grow">
          <small>Parque do dia</small>
          <p class="display park-name">{park.name}</p>
          <span>a {formatDistance(park.distance_m)} de você. Bora levar o {myDogs[0]?.name ?? 'seu cão'}?</span>
        </div>
        <button class="big dark" onclick={() => go('places')}>Ver parques</button>
      </section>
    {/if}

    {#if i === 3 && nextEvents.length}
      <section class="module events rise">
        <div class="row">
          <h2 class="grow">Rolês que vêm aí 🎉</h2>
          <button class="tonal" onclick={() => go('events')}>Todos os eventos <Icon name="arrow_forward" /></button>
        </div>
        <div class="ev-row">
          {#each nextEvents as ev (ev.id)}
            {@const dt = eventDate(ev.starts_at)}
            <button class="ev" onclick={() => go('event', ev.id)}>
              <span class="ev-cover"><Icon name={eventKinds[ev.kind].icon} filled size={48} />{#if ev.cover_url}<img src={imageUrl(ev.cover_url)} alt="" />{/if}
                <span class="ev-date"><strong>{dt.day}</strong>{dt.month}</span>
              </span>
              <strong class="ev-title">{ev.title}</strong>
              <small>{dt.countdown} · {ev.going} vão{ev.has_contest ? ' · 🏆' : ''}</small>
            </button>
          {/each}
        </div>
      </section>
    {/if}

    {#if i === 4}<div class="module"><AdBanner /></div>{/if}

    {#if i === 5 && app.counts.requests}
      <section class="module requests rise">
        <p class="display">{app.counts.requests} {app.counts.requests === 1 ? 'cão quer' : 'cães querem'} te conhecer 💙</p>
        <button class="primary big" onclick={() => go('matches')}>Responder agora</button>
      </section>
    {/if}
  {/each}
</div>

<div bind:this={sentinel} class="sentinel">
  {#if !end && posts.length}<span class="muted">Carregando mais fotos...</span>{/if}
  {#if end && posts.length}<span class="muted">Você viu tudo por hoje! 🐶</span>{/if}
</div>

<style>
  .top { display: flex; align-items: center; gap: 16px; margin: 8px 0 16px; }
  .top h1 { margin: 0; font-size: 56px; line-height: 60px; }
  .wave { display: inline-block; animation: wave 2.2s ease-in-out infinite; transform-origin: 70% 70%; }
  @keyframes wave { 0%, 60%, 100% { transform: rotate(0); } 10%, 30% { transform: rotate(16deg); } 20%, 40% { transform: rotate(-8deg); } }

  /* stories */
  .stories { display: flex; gap: 14px; overflow-x: auto; padding: 4px 2px 16px; scrollbar-width: none; }
  .story { flex-direction: column; height: auto; padding: 0; border: none; gap: 6px; color: var(--md-on-surface); position: relative; }
  .story::after { display: none; }
  .story:hover .ring { transform: scale(1.06) rotate(8deg); }
  .ring {
    width: 88px;
    height: 88px;
    display: grid;
    place-items: center;
    background: conic-gradient(from 200deg, var(--md-primary), var(--md-tertiary), var(--like), var(--md-primary));
    transition: transform 0.3s cubic-bezier(.2, .9, .3, 1.4);
  }
  .inner { width: 80px; height: 80px; display: grid; place-items: center; background: var(--md-surface); }
  .inner :global(.avatar) { width: 72px !important; height: 72px !important; }
  .story small { font-size: 12px; font-weight: 500; max-width: 88px; overflow: hidden; text-overflow: ellipsis; }
  .story.me .ring { background: var(--md-outline-variant); }
  .plus {
    position: absolute;
    right: 0;
    top: 60px;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--md-primary);
    color: var(--md-on-primary);
    display: grid;
    place-items: center;
    border: 3px solid var(--md-surface);
  }
  .plus :global(.icon) { font-size: 18px; margin: 0; }

  .composer { background: var(--md-primary-container); color: var(--md-on-primary-container); box-shadow: none; }
  .composer h2 { margin-top: 0; }
  .composer .row { align-items: flex-end; }
  .composer label { color: inherit; }

  .fresh {
    position: sticky;
    top: 12px;
    z-index: 4;
    display: flex;
    margin: 0 auto 12px;
    box-shadow: var(--md-elevation-3);
    animation: rise 0.3s ease-out;
  }

  /* grade de posts e blocos */
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); grid-auto-flow: dense; gap: 20px; }
  .post { margin: 0; }
  .post.hero, .module { grid-column: 1 / -1; }
  .media {
    position: relative;
    aspect-ratio: 1;
    display: grid;
    place-items: center;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
    overflow: hidden;
    cursor: pointer;
  }
  /* cantos assimétricos variados: cada foto com uma forma diferente */
  .media.r0 { border-radius: var(--radius-xxl); }
  .media.r1 { border-radius: 80px 24px 80px 24px; aspect-ratio: 4 / 5; }
  .media.r2 { border-radius: 24px 80px 24px 80px; }
  .media.r3 { border-radius: 50% 50% 28px 28px; aspect-ratio: 4 / 5; }
  .hero .media { aspect-ratio: 16 / 9; border-radius: 56px 56px 56px 12px; }
  .media video { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .video-badge { position: absolute; top: 14px; right: 14px; color: #fff; filter: drop-shadow(0 2px 6px rgb(0 0 0 / 0.5)); z-index: 1; }
  .like-btn.open { background: var(--md-primary-container); color: var(--md-on-primary-container); }
  .media img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; transition: transform 0.6s; }
  .media:hover img { transform: scale(1.04); }
  .big-heart { position: absolute; color: var(--like); filter: drop-shadow(0 6px 16px rgb(0 0 0 / 0.35)); animation: big-heart 0.9s ease-out forwards; z-index: 2; }
  .overlay {
    position: absolute;
    inset: auto 0 0 0;
    padding: 28px;
    background: linear-gradient(transparent, rgb(0 10 60 / 0.75));
    color: #fff;
    z-index: 1;
  }
  .hot { margin: 0 0 8px; }
  .hero-caption { font-size: 44px; line-height: 48px; margin: 0; text-wrap: balance; }

  .meta { display: flex; align-items: center; gap: 8px; padding: 8px 4px 0; }
  .author { flex: 1; height: 56px; justify-content: flex-start; gap: 12px; padding: 0 8px; color: var(--md-on-surface); border-radius: 28px; }
  .mini { width: 40px; height: 40px; display: grid; }
  .names { display: flex; flex-direction: column; align-items: flex-start; line-height: 18px; }
  .name { font-weight: 700; font-size: 15px; }
  .like-btn {
    height: 44px;
    padding: 0 16px;
    border: none;
    background: var(--md-surface-container-high);
    color: var(--md-on-surface);
    gap: 6px;
    border-radius: 22px;
  }
  .like-btn :global(.icon) { margin: 0; font-size: 22px; }
  .like-btn span { display: inline-flex; }
  .like-btn.liked { background: var(--md-secondary-container); color: var(--md-on-secondary-container); }
  .caption { padding: 4px 12px 0; margin: 0; font-size: 15px; }

  .module { margin: 4px 0; }
  .nearby { background: var(--md-surface-container); border-radius: var(--radius-xxl); padding: 20px 24px; }
  .nearby h2 { margin: 0; }
  .carousel { display: flex; gap: 16px; overflow-x: auto; padding: 16px 0 4px; scrollbar-width: thin; }
  .near { flex-direction: column; height: auto; padding: 0; border: none; gap: 4px; color: var(--md-on-surface); min-width: 128px; }
  .near::after { display: none; }
  .near-photo {
    width: 128px;
    height: 128px;
    position: relative;
    display: grid;
    place-items: center;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
    transition: transform 0.3s cubic-bezier(.2, .9, .3, 1.4);
  }
  .near:hover .near-photo { transform: rotate(-10deg) scale(1.05); }
  .near-photo img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }

  .park {
    display: flex;
    align-items: center;
    gap: 24px;
    padding: 28px;
    border-radius: 80px 28px 80px 28px;
    background: var(--md-secondary-container);
    color: var(--md-on-secondary-container);
  }
  .park-shape { width: 104px; height: 104px; display: grid; place-items: center; background: var(--md-primary); color: var(--md-on-primary); flex-shrink: 0; animation: spin 24s linear infinite; }
  .park-shape :global(.icon) { animation: spin 24s linear infinite reverse; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .park small { font-weight: 700; text-transform: uppercase; letter-spacing: 0.1em; }
  .park-name { font-size: 36px; line-height: 40px; margin: 4px 0; }
  button.dark { background: var(--md-on-secondary-container); color: var(--md-secondary-container); border: none; }

  .requests {
    display: flex;
    align-items: center;
    gap: 24px;
    padding: 28px 32px;
    border-radius: var(--radius-xxl);
    background: var(--md-tertiary-container);
    color: var(--md-on-tertiary-container);
  }
  .requests p { flex: 1; margin: 0; font-size: 34px; line-height: 38px; }

  .events { background: var(--md-tertiary-container); color: var(--md-on-tertiary-container); border-radius: var(--radius-xxl); padding: 20px 24px; }
  .events h2 { margin: 0; }
  .ev-row { display: flex; gap: 16px; overflow-x: auto; padding-top: 16px; }
  .ev { flex-direction: column; align-items: flex-start; height: auto; padding: 0; border: none; gap: 4px; color: inherit; width: 220px; flex-shrink: 0; white-space: normal; text-align: left; }
  .ev::after { display: none; }
  .ev-cover { position: relative; width: 220px; height: 140px; border-radius: 32px 32px 32px 8px; overflow: hidden; display: grid; place-items: center; background: var(--md-primary-container); color: var(--md-on-primary-container); }
  .ev-cover img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .ev-date { position: absolute; top: 10px; left: 10px; display: flex; flex-direction: column; align-items: center; padding: 6px 10px; border-radius: 16px; background: var(--like); color: #231b00; font-size: 11px; font-weight: 800; line-height: 1; }
  .ev-date strong { font-family: var(--font-display); font-size: 22px; }
  .ev-title { font-family: var(--font-display); font-size: 18px; line-height: 21px; }
  .sentinel { text-align: center; padding: 32px; min-height: 40px; }
  @media (max-width: 760px) {
    .top h1, .hero-caption { font-size: 36px; line-height: 40px; }
    .park, .requests { flex-direction: column; text-align: center; }
  }
</style>
