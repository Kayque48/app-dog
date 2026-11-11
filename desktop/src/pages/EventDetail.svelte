<script>
  // Evento: capa, presença, concurso com pódio e votação, inscrição do meu cão e quem vai.
  import { onMount } from 'svelte';
  import { api, eventDate, eventKinds, formatDistance, imageUrl, openExternal } from '../lib/api.js';
  import { go, showError, toast } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import Icon from '../lib/Icon.svelte';

  let { id } = $props();
  let data = $state(null);
  let myDogs = $state([]);
  let entryDog = $state(null);
  let votedPop = $state(null);

  async function load() {
    try { data = await api('GET', `/events/${id}`); } catch (e) { showError(e); }
  }
  onMount(async () => {
    load();
    myDogs = (await api('GET', '/dogs/mine').catch(() => [])).filter((d) => !d.removed_at);
    entryDog = myDogs[0]?.id ?? null;
  });

  const e = $derived(data?.event);
  const d = $derived(e ? eventDate(e.starts_at) : null);
  const totalVotes = $derived(data ? data.entries.reduce((s, x) => s + x.votes, 0) : 0);
  const podium = $derived(data ? data.entries.slice(0, 3) : []);
  const mine = $derived(new Set(myDogs.map((x) => x.id)));

  async function rsvp(status) {
    try {
      await api('POST', `/events/${id}/rsvp`, { status: e.my_rsvp === status ? null : status });
      if (status === 'going' && e.my_rsvp !== 'going') toast('Bora! Presença confirmada 🎉');
      load();
    } catch (err) { showError(err); }
  }

  async function vote(entry) {
    try {
      await api('POST', `/events/${id}/vote`, { entry_id: entry.id });
      votedPop = entry.id;
      toast(`Voto em ${entry.dog_name}! 🗳️`);
      load();
    } catch (err) { showError(err); }
  }

  async function enter() {
    try {
      await api('POST', `/events/${id}/entries`, { dog_id: entryDog });
      toast('Inscrição feita! Agora é pedir voto pra galera 📣');
      load();
    } catch (err) { showError(err); }
  }

  const medal = ['🥇', '🥈', '🥉'];
</script>

{#if e}
  <button class="text back" onclick={() => go('events')}><Icon name="arrow_back" /> Eventos</button>

  <section class="hero">
    <div class="cover shape-wide">
      <span class="fallback"><Icon name={eventKinds[e.kind].icon} filled size={120} /></span>
      {#if e.cover_url}<img src={imageUrl(e.cover_url)} alt="" />{/if}
      <div class="overlay">
        <span class="chip kind"><Icon name={eventKinds[e.kind].icon} /> {eventKinds[e.kind].label}</span>
        <h1 class="title">{e.title}</h1>
      </div>
      <span class="date shape-cookie12"><small>{d.week}</small><strong>{d.day}</strong><small>{d.month}</small></span>
    </div>
  </section>

  <div class="layout">
    <div class="main">
      <div class="facts">
        <div class="fact"><Icon name="schedule" /><div><strong>{d.time}</strong><small>{d.countdown}</small></div></div>
        <div class="fact"><Icon name="location_on" /><div><strong>{e.place_name}</strong><small>{e.address}{e.distance_m != null ? ` · ${formatDistance(e.distance_m)}` : ''}</small></div></div>
        <div class="fact"><Icon name="groups" /><div><strong>{e.going} vão</strong><small>{e.maybe} talvez</small></div></div>
      </div>
      {#if e.description}<p class="desc">{e.description}</p>{/if}
      <div class="rsvp">
        <button class="pill" class:on={e.my_rsvp === 'going'} onclick={() => rsvp('going')}><Icon name="music_note" filled /> Vou</button>
        <button class="pill" class:on={e.my_rsvp === 'maybe'} onclick={() => rsvp('maybe')}><Icon name="help" /> Talvez</button>
        <button class="pill ghost" onclick={() => openExternal(`https://www.google.com/maps/search/?api=1&query=${e.lat},${e.lng}`)}><Icon name="map" /> Mapa</button>
      </div>

      {#if e.has_contest}
        <h2><Icon name="emoji_events" filled size={32} /> Concurso</h2>
        <p class="muted">
          {e.entry_sex === 'femea' ? 'Só fêmeas. ' : e.entry_sex === 'macho' ? 'Só machos. ' : ''}{e.entry_breed ? `Só ${e.entry_breed}. ` : ''}Um voto por pessoa e não vale votar no próprio cão. {totalVotes} votos até agora.
        </p>

        {#if podium.length}
          <div class="podium">
            {#each [podium[1], podium[0], podium[2]] as p, k}
              {#if p}
                {@const place = k === 1 ? 0 : k === 0 ? 1 : 2}
                <div class="step s{place}">
                  <span class="medal">{medal[place]}</span>
                  <span class="shape-{place === 0 ? 'cookie9' : 'flower'} pav"><DogAvatar photo={p.dog_photo_url} size={place === 0 ? 120 : 92} /></span>
                  <strong>{p.dog_name}</strong>
                  <small>{p.votes} voto{p.votes === 1 ? '' : 's'}</small>
                  <div class="block">{place + 1}º</div>
                </div>
              {/if}
            {/each}
          </div>
        {/if}

        <div class="entries">
          {#each data.entries as x, i (x.id)}
            {@const pct = totalVotes ? Math.round((x.votes / totalVotes) * 100) : 0}
            <div class="entry" class:voted={data.my_vote === x.id}>
              <span class="pos">{i + 1}</span>
              <span class="shape-cookie12 av"><DogAvatar photo={x.dog_photo_url} size={56} /></span>
              <div class="grow">
                <button class="link" onclick={() => go('dog', x.dog_id)}>{x.dog_name}</button>
                <small class="muted"> · {x.dog_breed} · dono(a) {x.owner_name}</small>
                <div class="bar"><span style="width:{pct}%"></span></div>
                <small>{x.votes} voto{x.votes === 1 ? '' : 's'} · {pct}%</small>
              </div>
              {#if mine.has(x.dog_id)}
                <span class="chip tonal">Seu cão</span>
              {:else}
                <button class="vote" class:on={data.my_vote === x.id} onclick={() => vote(x)}>
                  <span class:pop={votedPop === x.id}><Icon name="how_to_vote" filled={data.my_vote === x.id} /></span>
                  {data.my_vote === x.id ? 'Seu voto' : 'Votar'}
                </button>
              {/if}
            </div>
          {:else}
            <p class="empty">Ninguém inscrito ainda. Seja o primeiro!</p>
          {/each}
        </div>

        {#if myDogs.length}
          <div class="enter">
            <p class="display">Bota seu cão na disputa!</p>
            <div class="row wrap">
              <select bind:value={entryDog} style="width:auto">{#each myDogs as x}<option value={x.id}>{x.name}</option>{/each}</select>
              <button class="big dark" onclick={enter}><Icon name="add_circle" filled /> Inscrever</button>
            </div>
          </div>
        {/if}
      {/if}
    </div>

    <aside class="side">
      <h3>Quem vai ({data.attendees.length})</h3>
      <div class="faces">
        {#each data.attendees as a, i (a.id + '-' + i)}
          <button class="face" title={a.name} onclick={() => go('dog', a.id)}>
            <span class="shape-{['cookie9', 'flower', 'cookie12', 'blob'][i % 4]} fav"><DogAvatar photo={a.photo_url} size={64} /></span>
            <small>{a.name}</small>
          </button>
        {:else}
          <p class="muted">Ninguém confirmou ainda.</p>
        {/each}
      </div>
    </aside>
  </div>
{/if}

<style>
  .back { margin: 0 0 8px -12px; }
  .hero { margin-bottom: 24px; }
  .cover {
    position: relative;
    height: 380px;
    border-radius: 56px 56px 120px 24px;
    overflow: hidden;
    display: grid;
    place-items: center;
    background: var(--md-primary-container);
    color: var(--md-on-primary-container);
  }
  .cover img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  .overlay { position: absolute; inset: auto 0 0 0; padding: 32px 40px; background: linear-gradient(transparent, rgb(0 10 60 / 0.8)); color: #fff; }
  .kind { background: var(--like); color: #231b00; border: none; }
  .kind :global(.icon) { color: inherit; }
  .title { font-size: 60px; line-height: 60px; margin: 8px 0 0; color: #fff; text-wrap: balance; }
  .date { position: absolute; top: 24px; right: 28px; width: 110px; height: 110px; background: var(--like); color: #231b00; display: flex; flex-direction: column; align-items: center; justify-content: center; line-height: 1; animation: spin 30s linear infinite; }
  .date > * { animation: spin 30s linear infinite reverse; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .date strong { font-family: var(--font-display); font-size: 40px; font-weight: 800; }
  .date small { font-size: 12px; font-weight: 800; letter-spacing: 0.08em; }

  .layout { display: grid; grid-template-columns: 1fr 280px; gap: 32px; align-items: start; }
  .facts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 16px; }
  .fact { display: flex; gap: 12px; align-items: center; padding: 16px; border-radius: 28px; background: var(--md-surface-container); }
  .fact > :global(.icon) { color: var(--md-primary); font-size: 32px; }
  .fact div { display: flex; flex-direction: column; line-height: 1.2; }
  .fact small { color: var(--md-on-surface-variant); font-size: 13px; }
  .desc { font-size: 18px; line-height: 28px; }
  .rsvp { display: flex; gap: 10px; margin: 16px 0 8px; }
  .pill { flex: 1; height: 60px; border-radius: 30px; border: none; background: var(--md-surface-container-highest); color: var(--md-on-surface); font-size: 18px; font-weight: 700; transition: border-radius 0.25s; }
  .pill.on { background: var(--md-primary); color: var(--md-on-primary); border-radius: 18px; }
  .pill.ghost { flex: 0 0 auto; padding: 0 24px; background: transparent; border: 1px solid var(--md-outline); }
  .pill :global(.icon) { margin: 0; }

  h2 { display: flex; align-items: center; gap: 8px; }
  h2 :global(.icon) { color: var(--like); }

  .podium { display: flex; justify-content: center; align-items: flex-end; gap: 16px; margin: 24px 0; }
  .step { display: flex; flex-direction: column; align-items: center; gap: 4px; width: 150px; animation: rise 0.5s both; }
  .step.s0 { animation-delay: 0.2s; }
  .step.s2 { animation-delay: 0.1s; }
  .medal { font-size: 36px; }
  .pav { display: grid; }
  .step strong { font-family: var(--font-display); font-size: 20px; }
  .block { width: 100%; margin-top: 8px; display: grid; place-items: center; font-family: var(--font-display); font-weight: 800; font-size: 32px; border-radius: 24px 24px 8px 8px; }
  .s0 .block { height: 120px; background: var(--like); color: #231b00; }
  .s1 .block { height: 84px; background: var(--md-primary); color: var(--md-on-primary); }
  .s2 .block { height: 60px; background: var(--md-tertiary); color: #fff; }

  .entries { display: flex; flex-direction: column; gap: 8px; }
  .entry { display: flex; align-items: center; gap: 14px; padding: 12px 16px; border-radius: 28px; background: var(--md-surface-container-low); }
  .entry.voted { background: var(--md-secondary-container); color: var(--md-on-secondary-container); }
  .entry.voted .muted { color: inherit; }
  .pos { font-family: var(--font-display); font-weight: 800; font-size: 24px; width: 28px; text-align: center; }
  .av { display: grid; }
  .bar { height: 10px; border-radius: 5px; background: var(--md-surface-container-highest); margin: 6px 0 2px; overflow: hidden; }
  .bar span { display: block; height: 100%; border-radius: 5px; background: linear-gradient(90deg, var(--md-primary), var(--md-tertiary)); transition: width 0.6s cubic-bezier(.2, .9, .3, 1.2); }
  .vote { height: 48px; border-radius: 24px; border: none; background: var(--md-primary); color: var(--md-on-primary); padding: 0 20px; }
  .vote.on { background: var(--md-on-secondary-container); color: var(--md-secondary-container); }
  .vote :global(.icon) { margin: 0; }
  .vote span { display: inline-flex; }

  .enter { margin-top: 20px; padding: 24px 28px; border-radius: 28px 80px 28px 80px; background: var(--md-secondary-container); color: var(--md-on-secondary-container); }
  .enter p { font-size: 30px; line-height: 34px; margin-bottom: 12px; }
  button.dark { background: var(--md-on-secondary-container); color: var(--md-secondary-container); border: none; }

  .side { position: sticky; top: 16px; padding: 20px; border-radius: 32px; background: var(--md-surface-container); }
  .faces { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
  .face { flex-direction: column; height: auto; padding: 0; border: none; gap: 4px; color: var(--md-on-surface); }
  .face::after { display: none; }
  .fav { display: grid; }
  .face small { font-size: 12px; }
  @media (max-width: 900px) {
    .layout { grid-template-columns: 1fr; }
    .facts { grid-template-columns: 1fr; }
    .title { font-size: 40px; line-height: 42px; }
  }
</style>
