<script>
  import { onMount } from 'svelte';
  import { api, openExternal } from '../lib/api.js';
  import { go, showError } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';
  import Icon from '../lib/Icon.svelte';

  let items = $state(null);
  const load = async () => (items = await api('GET', '/matches').catch((e) => (showError(e), [])));
  onMount(load);

  async function respond(m, accept) {
    try {
      await api('POST', `/matches/${m.id}/respond`, { accept });
      load();
    } catch (e) { showError(e); }
  }

  const sections = $derived(
    items
      ? [
          ['Pedidos para você', items.filter((m) => m.status === 'pending' && m.direction === 'incoming')],
          ['Encontros combinados', items.filter((m) => m.status === 'accepted')],
          ['Aguardando resposta', items.filter((m) => m.status === 'pending' && m.direction === 'outgoing')],
        ]
      : [],
  );
</script>

<div class="page-header"><h1>Encontros</h1></div>
{#if items && items.length === 0}
  <div class="empty">
    <Icon name="favorite" />
    <p>Nenhum encontro ainda.</p>
    <button class="primary" onclick={() => go('discover')}>Ir para Descobrir</button>
  </div>
{/if}

{#each sections as [title, list]}
  {#if list.length}
    <h2>{title}</h2>
    {#each list as m (m.id)}
      <div class="card row wrap rise" class:incoming={m.status === 'pending' && m.direction === 'incoming'} class:matched={m.status === 'accepted'}>
        <span class="shape-cookie9 av"><DogAvatar photo={m.other_dog.photo_url} size={72} /></span>
        <div class="grow">
          <button class="link" onclick={() => go('dog', m.other_dog.id)}>{m.other_dog.name}</button>
          <span class="muted">· {m.other_dog.breed}</span><br />
          <small class="muted">Com {m.my_dog.name} · dono(a) {m.other_owner.first_name}</small>
        </div>
        {#if m.status === 'pending' && m.direction === 'incoming'}
          <button class="text" onclick={() => respond(m, false)}>Recusar</button>
          <button class="primary" onclick={() => respond(m, true)}><Icon name="check" /> Aceitar</button>
        {:else if m.status === 'pending'}
          <span class="chip"><Icon name="schedule" /> Aguardando</span>
        {/if}
        {#if m.other_owner.phone}
          <span class="chip"><Icon name="call" /> {m.other_owner.phone}</span>
          <button class="tonal" onclick={() => openExternal(`https://wa.me/55${m.other_owner.phone}`)}>
            <Icon name="chat" /> WhatsApp
          </button>
        {/if}
      </div>
    {/each}
  {/if}
{/each}

<style>
  .row .chip { margin: 0; }
  .card { box-shadow: none; background: var(--md-surface-container-low); }
  .av { display: grid; width: 72px; height: 72px; }
  .incoming { background: var(--md-secondary-container); color: var(--md-on-secondary-container); border-radius: 48px 48px 48px 12px; }
  .incoming .muted { color: inherit; }
  .matched { background: var(--md-primary-container); color: var(--md-on-primary-container); border-radius: 12px 48px 48px 48px; }
  .matched .muted { color: inherit; }
</style>
