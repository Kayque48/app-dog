<script>
  // Descobrir: estilo Tinder. Arraste o cartão (ou use ← e →) para passar ou pedir um encontro.
  import { onMount } from 'svelte';
  import { ageText, api, formatDistance, imageUrl, sexes, temperaments } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';

  let myDogs = $state([]);
  let dogId = $state(null);
  let radius = $state(500);
  let cards = $state([]);
  let blocked = $state(null);
  let loading = $state(true);
  let dragX = $state(0);
  let dragStart = null;

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
      cards = await api('GET', `/discover?dog_id=${dogId}&radius_m=${radius}`);
    } catch (e) {
      if (e.status === 400 || e.status === 403) { blocked = e.message; cards = []; } else showError(e);
    } finally { loading = false; }
  }

  async function swipe(liked) {
    const other = cards[0];
    if (!other) return;
    cards = cards.slice(1);
    dragX = 0;
    try {
      const r = await api('POST', '/swipes', { from_dog_id: dogId, to_dog_id: other.id, liked });
      if (r.matched) toast(`Encontro combinado com ${other.name}! Veja o contato em Encontros. 🐾`);
      else if (liked) toast(`Pedido enviado! Aguarde o dono de ${other.name} aceitar.`);
    } catch (e) { showError(e); }
  }

  function onKey(e) {
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

<h1>Descobrir</h1>
<div class="row wrap">
  {#if myDogs.length > 1}
    <label>Procurar amigos para
      <select bind:value={dogId} onchange={load}>
        {#each myDogs as d}<option value={d.id}>{d.name}</option>{/each}
      </select>
    </label>
  {/if}
  {#each [500, 1000, 3000] as r}
    <button class:primary={radius === r} onclick={() => { radius = r; load(); }}>Até {formatDistance(r)}</button>
  {/each}
</div>

{#if loading}
  <p class="empty">Procurando cães por perto...</p>
{:else if !dogId}
  <p class="empty">Cadastre seu cão em <button class="link" onclick={() => go('dogs')}>Meus cães</button> para encontrar amigos.</p>
{:else if blocked}
  <div class="empty">
    <p class="bad">💉 {blocked}</p>
    {#if blocked.includes('localização')}
      <button onclick={() => go('profile')}>Definir localização no Perfil</button>
    {:else}
      <button class="primary" onclick={() => go('dog', dogId)}>Abrir carteira de vacinação</button>
    {/if}
  </div>
{:else if cards.length === 0}
  <div class="empty"><p>Nenhum cão novo por perto agora. Tente aumentar a distância.</p><button onclick={load}>Atualizar</button></div>
{:else}
  {@const d = cards[0]}
  <div class="stage">
    <div
      class="swipe card"
      role="button"
      tabindex="0"
      style="transform: translateX({dragX}px) rotate({dragX / 25}deg)"
      onpointerdown={down}
    >
      {#if dragX > 40}<div class="stamp yes">QUERO CONHECER</div>{/if}
      {#if dragX < -40}<div class="stamp no">PASSAR</div>{/if}
      <div class="photo">{#if d.photo_url}<img src={imageUrl(d.photo_url)} alt="" draggable="false" />{:else}🐶{/if}</div>
      {#if d.wants_to_meet_you}<span class="chip">❤️ Quer conhecer o seu cão!</span>{/if}
      <h2>{d.name}, {ageText(d.age_years)}</h2>
      <p>{d.breed} • {sexes[d.sex]} • a {formatDistance(d.distance_m)} • dono(a): {d.owner_first_name}</p>
      <div>
        <span class="chip">{temperaments[d.temperament]}</span>
        <span class="chip">{d.bites ? '⚠️ Pode morder' : '✅ Não morde'}</span>
        {#if d.in_heat}<span class="chip">No cio</span>{/if}
        <span class="chip">💉 Vacinas em dia</span>
      </div>
      {#if d.likes}<p>Gosta de: {d.likes}</p>{/if}
      {#if d.dislikes}<p>Não gosta de: {d.dislikes}</p>{/if}
      <button class="link" onclick={() => go('dog', d.id)}>Ver perfil completo</button>
    </div>
    <div class="row actions">
      <button class="big danger" onclick={() => swipe(false)}>✖ Passar</button>
      <button class="big primary" onclick={() => swipe(true)}>❤ Quero conhecer</button>
    </div>
    <p class="muted">Dica: arraste o cartão ou use as setas ← e → do teclado.</p>
  </div>
{/if}

<style>
  .stage { max-width: 440px; margin: 16px auto; text-align: center; }
  .swipe { position: relative; text-align: left; user-select: none; cursor: grab; touch-action: none; }
  .photo { height: 280px; border-radius: 12px; background: var(--blue-light); display: grid; place-items: center; font-size: 5rem; overflow: hidden; margin-bottom: 12px; }
  .photo img { width: 100%; height: 100%; object-fit: cover; }
  .stamp { position: absolute; top: 24px; padding: 6px 12px; border: 3px solid; border-radius: 8px; font-weight: bold; background: white; }
  .stamp.yes { left: 24px; color: var(--green); }
  .stamp.no { right: 24px; color: var(--red); }
  .actions { justify-content: center; }
  .big { font-size: 1.1rem; padding: 14px 24px; }
</style>
