<script>
  // Descobrir: estilo Tinder. Arraste o cartão (ou use as setas do teclado) para passar ou pedir um encontro.
  import { onMount } from 'svelte';
  import { activityLevels, ageText, api, formatDistance, imageUrl, lookingFor, playBark, sexes, temperaments } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import Icon from '../lib/Icon.svelte';

  let myDogs = $state([]);
  let dogId = $state(null);
  let radius = $state(500);
  let goal = $state('amizade'); // amizade | cruzamento
  let cards = $state([]);
  let blocked = $state(null);
  let loading = $state(true);
  let dragX = $state(0);
  let dragStart = null;
  let match = $state(null); // cão com quem acabou de combinar (tela de comemoração)
  let seen = $state(0);

  const myDog = $derived(myDogs.find((d) => d.id === dogId));
  const shapes = ['shape-blob', 'shape-cookie12', 'shape-flower', 'shape-cookie9'];
  // confete nas cores que o cachorro enxerga
  const confetti = Array.from({ length: 36 }, (_, i) => ({
    left: (i * 37) % 100,
    delay: (i % 9) * 0.08,
    color: ['var(--md-primary)', 'var(--like)', 'var(--md-tertiary)', 'var(--md-primary-container)'][i % 4],
    rot: (i * 47) % 360,
  }));

  onMount(async () => {
    myDogs = (await api('GET', '/dogs/mine').catch(() => [])).filter((d) => !d.removed_at);
    dogId = myDogs[0]?.id ?? null;
    load();
  });

  async function load() {
    loading = true;
    blocked = null;
    if (!dogId) return (loading = false);
    try {
      cards = await api('GET', `/discover?dog_id=${dogId}&radius_m=${radius}&goal=${goal}`);
    } catch (e) {
      if (e.status === 400 || e.status === 403) { blocked = e.message; cards = []; } else showError(e);
    } finally { loading = false; }
  }

  async function swipe(liked) {
    const other = cards[0];
    if (!other) return;
    dragX = liked ? 700 : -700; // o cartão "voa" para o lado
    setTimeout(() => { cards = cards.slice(1); dragX = 0; seen++; }, 220);
    try {
      const r = await api('POST', '/swipes', { from_dog_id: dogId, to_dog_id: other.id, liked });
      if (r.matched) {
        match = other;
        playBark(); // "au au!"
      }
      else if (liked) toast(`Pedido enviado! Aguarde o dono de ${other.name} aceitar.`);
    } catch (e) { showError(e); }
  }

  function onKey(e) {
    if (match || e.target.closest?.('input, select, textarea')) return;
    if (e.key === 'ArrowLeft') swipe(false);
    if (e.key === 'ArrowRight') swipe(true);
  }
  const down = (e) => (dragStart = e.clientX);
  const move = (e) => dragStart !== null && (dragX = e.clientX - dragStart);
  function up() {
    if (dragStart === null) return;
    dragStart = null;
    if (Math.abs(dragX) > 120) swipe(dragX > 0);
    else dragX = 0;
  }
</script>

<svelte:window onkeydown={onKey} onpointermove={move} onpointerup={up} />

<div class="page-header">
  <h1>Descobrir</h1>
  {#if cards.length}<span class="chip tonal"><Icon name="pets" filled /> {cards.length} por perto</span>{/if}
</div>
<div class="row wrap filters">
  {#if myDogs.length > 1}
    <label>Procurar amigos para
      <select bind:value={dogId} onchange={load}>
        {#each myDogs as d}<option value={d.id}>{d.name}</option>{/each}
      </select>
    </label>
  {/if}
  <div class="segmented goal" role="group" aria-label="Objetivo">
    {#each [['amizade', 'diversity_1', 'Amizade'], ['cruzamento', 'favorite', 'Cruzamento']] as [k, icon, v]}
      <button class:selected={goal === k} onclick={() => { goal = k; load(); }}><Icon name={icon} filled={goal === k} /> {v}</button>
    {/each}
  </div>
  <div class="segmented" role="group" aria-label="Distância">
    {#each [500, 1000, 3000] as r}
      <button class:selected={radius === r} onclick={() => { radius = r; load(); }}>
        {#if radius === r}<Icon name="check" />{/if} Até {formatDistance(r)}
      </button>
    {/each}
  </div>
</div>

{#if loading}
  <div class="empty"><span class="spinner shape-cookie9"></span>Farejando cães por perto...</div>
{:else if !dogId}
  <div class="empty">
    <Icon name="pets" />
    <p>Cadastre seu cão para encontrar amigos.</p>
    <button class="primary big" onclick={() => go('dogs')}>Ir para Meus cães</button>
  </div>
{:else if blocked}
  <div class="empty">
    <Icon name={blocked.includes('localização') ? 'location_off' : 'vaccines'} />
    <div class="card error blocked">{blocked}</div>
    {#if blocked.includes('localização')}
      <button class="primary big" onclick={() => go('profile')}>Definir localização no Perfil</button>
    {:else}
      <button class="primary big" onclick={() => go('dog', dogId)}>Abrir carteira de vacinação</button>
    {/if}
  </div>
{:else if cards.length === 0}
  <div class="empty">
    <Icon name="search_off" />
    <p class="display done">{seen ? `Você viu ${seen} ${seen === 1 ? 'cão' : 'cães'}!` : 'Ninguém novo por aqui.'}</p>
    <p>Tente aumentar a distância ou volte mais tarde.</p>
    <button class="primary big" onclick={() => { radius = 3000; load(); }}><Icon name="travel_explore" /> Procurar até 3 km</button>
  </div>
{:else}
  {@const d = cards[0]}
  <div class="stage">
    <!-- próximo cartão aparecendo atrás -->
    {#if cards[1]}<div class="swipe back"></div>{/if}
    <div
      class="swipe"
      class:dragging={dragStart !== null}
      role="button"
      tabindex="0"
      style="transform: translateX({dragX}px) rotate({dragX / 22}deg)"
      onpointerdown={down}
    >
      {#if dragX > 40}<div class="stamp yes"><Icon name="favorite" filled /> QUERO!</div>{/if}
      {#if dragX < -40}<div class="stamp no"><Icon name="close" /> PASSA</div>{/if}
      <div class="photo-wrap">
        <div class="photo {shapes[seen % 4]}">
          <Icon name="pets" filled size={110} />
          {#if d.photo_url}<img src={imageUrl(d.photo_url)} alt="" draggable="false" />{/if}
        </div>
        <span class="dist chip tonal"><Icon name="near_me" filled /> {formatDistance(d.distance_m)}</span>
        {#if d.wants_to_meet_you}<span class="wants"><Icon name="favorite" filled /> Quer te conhecer!</span>{/if}
      </div>
      <p class="display name">{d.name}</p>
      <p class="sub">{ageText(d.age_years)} · {d.breed} · {sexes[d.sex]} · dono(a) {d.owner_first_name}</p>
      <div class="chips">
        <span class="chip"><Icon name="mood" /> {temperaments[d.temperament]}</span>
        {#if d.bites}
          <span class="chip error"><Icon name="warning" /> Pode morder</span>
        {:else}
          <span class="chip"><Icon name="check_circle" /> Não morde</span>
        {/if}
        {#if d.in_heat}<span class="chip"><Icon name="info" /> No cio</span>{/if}
        <span class="chip success"><Icon name="vaccines" /> Vacinas em dia</span>
        <span class="chip"><Icon name="bolt" /> {activityLevels[d.activity_level]}</span>
        <span class="chip tonal"><Icon name={d.looking_for === 'amizade' ? 'diversity_1' : 'favorite'} /> {lookingFor[d.looking_for]}</span>
        {#if d.pedigree_verified}<span class="chip ped"><Icon name="verified" filled /> Pedigree</span>{/if}
        {#if d.weight_kg}<span class="chip"><Icon name="scale" /> {d.weight_kg} kg</span>{/if}
      </div>
      {#if d.bio}<p class="bio">“{d.bio}”</p>{/if}
      <div class="likes">
        {#if d.likes}<div class="like-box"><small>AMA</small><span>{d.likes}</span></div>{/if}
        {#if d.dislikes}<div class="like-box no"><small>ODEIA</small><span>{d.dislikes}</span></div>{/if}
      </div>
      <button class="text profile" onclick={() => go('dog', d.id)}>Ver perfil completo <Icon name="arrow_forward" /></button>
    </div>
    <div class="row actions">
      <button class="pill pass" onclick={() => swipe(false)}><Icon name="close" size={32} /> Passa</button>
      <button class="pill like" onclick={() => swipe(true)}><Icon name="favorite" filled size={32} /> Quero!</button>
    </div>
    <p class="muted hint">Arraste o cartão ou use as setas ← e → do teclado.</p>
  </div>
{/if}

{#if match}
  <div class="match" role="dialog" aria-label="Encontro combinado">
    {#each confetti as c}
      <span class="confetti" style="left:{c.left}%; background:{c.color}; animation-delay:{c.delay}s; rotate:{c.rot}deg"></span>
    {/each}
    <p class="display match-title">Deu match!</p>
    <p class="bark display">AU AU! 🐶</p>
    <div class="pair">
      <span class="shape-cookie9 pair-a"><DogAvatar photo={myDog?.photo_url} size={160} /></span>
      <span class="heart"><Icon name="favorite" filled size={56} /></span>
      <span class="shape-flower pair-b"><DogAvatar photo={match.photo_url} size={160} /></span>
    </div>
    <p class="match-sub">{myDog?.name} e {match.name} querem se conhecer.</p>
    <div class="row">
      <button class="pill like" onclick={() => go('matches')}><Icon name="chat" /> Ver contato</button>
      <button class="pill ghost" onclick={() => (match = null)}>Continuar</button>
    </div>
  </div>
{/if}

<style>
  .page-header .chip { margin: 0; }
  .goal { margin-right: 8px; }
  .bio { font-style: italic; margin: 8px 0; }
  .ped { background: var(--like); color: #231b00; border: none; }
  .ped :global(.icon) { color: inherit; }
  .bark { font-size: 36px; margin: -8px 0 0; color: #fff; animation: pop 0.5s 0.3s both; }
  .filters { align-items: flex-end; }
  .filters label { margin-bottom: 16px; }
  .blocked { max-width: 520px; margin: 0 auto 16px; }
  .done { font-size: 40px; line-height: 44px; color: var(--md-on-surface); }
  .spinner { display: block; width: 72px; height: 72px; margin: 0 auto 16px; background: var(--md-primary); animation: spin 1.2s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }

  .stage { max-width: 480px; margin: 0 auto; text-align: center; position: relative; }
  .swipe {
    position: relative;
    z-index: 1;
    text-align: left;
    user-select: none;
    cursor: grab;
    touch-action: none;
    padding: 20px 24px 12px;
    border-radius: 48px;
    background: var(--md-surface-container-low);
    box-shadow: var(--md-elevation-2);
    transition: transform 0.22s ease-out;
  }
  .swipe.dragging { transition: none; cursor: grabbing; }
  .swipe.back { position: absolute; inset: 16px -12px auto; height: 200px; z-index: 0; transform: rotate(-3deg); background: var(--md-secondary-container); box-shadow: none; }
  .photo-wrap { position: relative; }
  .photo {
    height: 280px;
    position: relative;
    display: grid;
    place-items: center;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
  }
  .photo img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .dist { position: absolute; left: 8px; bottom: 8px; margin: 0; box-shadow: var(--md-elevation-1); }
  .wants {
    position: absolute;
    right: -6px;
    top: 12px;
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 10px 16px;
    border-radius: 24px 24px 4px 24px;
    background: var(--like);
    color: #231b00;
    font-weight: 700;
    rotate: 6deg;
    box-shadow: var(--md-elevation-2);
    animation: pop 0.6s 0.2s both;
  }
  .name { font-size: 64px; line-height: 64px; margin: 8px 0 4px; color: var(--md-primary); }
  .sub { color: var(--md-on-surface-variant); margin-bottom: 12px; }
  .chips { margin-bottom: 8px; }
  .likes { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .like-box { background: var(--md-primary-container); color: var(--md-on-primary-container); border-radius: 20px 20px 20px 6px; padding: 10px 14px; font-size: 14px; line-height: 18px; }
  .like-box.no { background: var(--md-surface-container-highest); color: var(--md-on-surface); border-radius: 20px 20px 6px 20px; }
  .like-box small { display: block; font-weight: 800; letter-spacing: 0.12em; font-size: 11px; margin-bottom: 2px; }
  .profile { margin: 8px 0 0 -12px; }
  .stamp {
    position: absolute;
    top: 40px;
    z-index: 2;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 20px;
    border-radius: 16px;
    font-family: var(--font-display);
    font-size: 28px;
    font-weight: 800;
    box-shadow: var(--md-elevation-3);
  }
  .stamp.yes { left: 32px; rotate: -12deg; background: var(--like); color: #231b00; }
  .stamp.no { right: 32px; rotate: 12deg; background: var(--md-inverse-surface); color: var(--md-inverse-on-surface); }

  .actions { justify-content: center; gap: 16px; margin: 24px 0 8px; }
  .pill { height: 72px; padding: 0 36px; border-radius: 36px; border: none; font-family: var(--font-display); font-size: 24px; font-weight: 800; box-shadow: var(--md-elevation-2); transition: transform 0.15s; }
  .pill:hover { transform: translateY(-3px) scale(1.03); }
  .pill:active { transform: scale(0.95); }
  .pill :global(.icon) { margin: 0; }
  .pill.pass { background: var(--md-inverse-surface); color: var(--md-inverse-on-surface); }
  .pill.like { background: var(--like); color: #231b00; }
  .pill.ghost { background: transparent; color: #fff; border: 2px solid #fff; box-shadow: none; }
  .hint { font-size: 14px; }

  /* comemoração do match */
  .match {
    position: fixed;
    inset: 0;
    z-index: 30;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
    background: radial-gradient(circle at 50% 40%, var(--md-tertiary), #0b1a7a 70%);
    color: #fff;
    overflow: hidden;
    animation: rise 0.3s ease-out;
  }
  .match-title { font-size: 120px; line-height: 110px; margin: 0; color: var(--like); animation: pop 0.7s both; text-shadow: 0 8px 32px rgb(0 0 0 / 0.4); }
  .match-sub { font-size: 20px; }
  .pair { display: flex; align-items: center; gap: 8px; }
  .pair-a, .pair-b { display: grid; width: 160px; height: 160px; }
  .pair-a { animation: slide-l 0.6s cubic-bezier(.2, .9, .3, 1.3) both; }
  .pair-b { animation: slide-r 0.6s cubic-bezier(.2, .9, .3, 1.3) both; }
  .heart { color: var(--like); animation: pop 0.6s 0.5s both; z-index: 1; margin: 0 -24px; }
  @keyframes slide-l { from { transform: translateX(-120vw) rotate(-90deg); } }
  @keyframes slide-r { from { transform: translateX(120vw) rotate(90deg); } }
  .confetti { position: absolute; top: -20px; width: 12px; height: 20px; border-radius: 3px; animation: fall 2.4s linear infinite; }
  @keyframes fall { to { transform: translateY(110vh) rotate(720deg); } }
</style>
