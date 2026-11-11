<script>
  // Descobrir: estilo Tinder. Arraste o cartão (ou use as setas do teclado) para passar ou pedir um encontro.
  import { onMount } from 'svelte';
  import { ageText, api, formatDistance, imageUrl, sexes, temperaments } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

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
      if (r.matched) toast(`Encontro combinado com ${other.name}! Veja o contato em Encontros.`);
      else if (liked) toast(`Pedido enviado! Aguarde o dono de ${other.name} aceitar.`);
    } catch (e) { showError(e); }
  }

  function onKey(e) {
    if (e.target.closest?.('input, select, textarea')) return;
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

<div class="page-header"><h1>Descobrir</h1></div>
<div class="row wrap filters">
  {#if myDogs.length > 1}
    <label>Procurar amigos para
      <select bind:value={dogId} onchange={load}>
        {#each myDogs as d}<option value={d.id}>{d.name}</option>{/each}
      </select>
    </label>
  {/if}
  <div class="segmented" role="group" aria-label="Distância">
    {#each [500, 1000, 3000] as r}
      <button class:selected={radius === r} onclick={() => { radius = r; load(); }}>
        {#if radius === r}<Icon name="check" />{/if} Até {formatDistance(r)}
      </button>
    {/each}
  </div>
</div>

{#if loading}
  <div class="empty"><Icon name="travel_explore" />Procurando cães por perto...</div>
{:else if !dogId}
  <div class="empty">
    <Icon name="pets" />
    <p>Cadastre seu cão para encontrar amigos.</p>
    <button class="primary" onclick={() => go('dogs')}>Ir para Meus cães</button>
  </div>
{:else if blocked}
  <div class="empty">
    <Icon name={blocked.includes('localização') ? 'location_off' : 'vaccines'} />
    <div class="card error blocked">{blocked}</div>
    {#if blocked.includes('localização')}
      <button class="primary" onclick={() => go('profile')}>Definir localização no Perfil</button>
    {:else}
      <button class="primary" onclick={() => go('dog', dogId)}>Abrir carteira de vacinação</button>
    {/if}
  </div>
{:else if cards.length === 0}
  <div class="empty">
    <Icon name="search_off" />
    <p>Nenhum cão novo por perto agora. Tente aumentar a distância.</p>
    <button onclick={load}><Icon name="refresh" /> Atualizar</button>
  </div>
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
      {#if dragX > 40}<div class="stamp yes"><Icon name="favorite" filled /> Quero conhecer</div>{/if}
      {#if dragX < -40}<div class="stamp no"><Icon name="close" /> Passar</div>{/if}
      <div class="photo">
        <Icon name="pets" filled size={96} />
        {#if d.photo_url}<img src={imageUrl(d.photo_url)} alt="" draggable="false" />{/if}
      </div>
      <div class="body">
        {#if d.wants_to_meet_you}<span class="chip tonal"><Icon name="favorite" filled /> Quer conhecer o seu cão!</span>{/if}
        <h2>{d.name}, {ageText(d.age_years)}</h2>
        <p class="muted">{d.breed} · {sexes[d.sex]} · a {formatDistance(d.distance_m)} · dono(a) {d.owner_first_name}</p>
        <div class="chips">
          <span class="chip"><Icon name="mood" /> {temperaments[d.temperament]}</span>
          {#if d.bites}
            <span class="chip error"><Icon name="warning" /> Pode morder</span>
          {:else}
            <span class="chip"><Icon name="check_circle" /> Não morde</span>
          {/if}
          {#if d.in_heat}<span class="chip"><Icon name="info" /> No cio</span>{/if}
          <span class="chip success"><Icon name="vaccines" /> Vacinas em dia</span>
        </div>
        {#if d.likes}<p><strong>Gosta de:</strong> {d.likes}</p>{/if}
        {#if d.dislikes}<p><strong>Não gosta de:</strong> {d.dislikes}</p>{/if}
        <button class="text profile" onclick={() => go('dog', d.id)}>Ver perfil completo</button>
      </div>
    </div>
    <div class="row actions">
      <button class="fab pass" onclick={() => swipe(false)} aria-label="Passar"><Icon name="close" size={36} /></button>
      <button class="fab like" onclick={() => swipe(true)} aria-label="Quero conhecer"><Icon name="favorite" filled size={36} /></button>
    </div>
    <p class="muted hint">Arraste o cartão ou use as setas ← e → do teclado.</p>
  </div>
{/if}

<style>
  .filters { align-items: flex-end; }
  .filters label { margin-bottom: 16px; }
  .blocked { max-width: 520px; margin: 0 auto 16px; }
  .stage { max-width: 440px; margin: 8px auto; text-align: center; }
  .swipe { position: relative; text-align: left; user-select: none; cursor: grab; touch-action: none; padding: 0; overflow: hidden; border-radius: 28px; box-shadow: var(--md-elevation-2); }
  .photo { position: relative; height: 300px; background: var(--md-primary-container); color: var(--md-on-primary-container); display: grid; place-items: center; overflow: hidden; }
  .photo img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .body { padding: 16px 20px 8px; }
  .body h2 { margin: 4px 0; }
  .chips { margin: 12px 0 4px; }
  strong { font-weight: 500; }
  .profile { margin-left: -12px; }
  .stamp {
    position: absolute;
    top: 24px;
    z-index: 1;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    border-radius: 8px;
    font-weight: 500;
    box-shadow: var(--md-elevation-2);
  }
  .stamp.yes { left: 24px; background: var(--md-success-container); color: var(--md-on-success-container); }
  .stamp.no { right: 24px; background: var(--md-error-container); color: var(--md-on-error-container); }
  .actions { justify-content: center; gap: 32px; margin: 24px 0 8px; }
  /* FABs grandes do M3 */
  .fab { width: 96px; height: 96px; border-radius: 28px; border: none; box-shadow: var(--md-elevation-3); padding: 0; }
  .fab :global(.icon) { margin: 0; }
  .fab.pass { background: var(--md-error-container); color: var(--md-on-error-container); }
  .fab.like { background: var(--md-primary-container); color: var(--md-on-primary-container); }
  .hint { font-size: 14px; }
</style>
