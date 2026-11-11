<script>
  import { onMount } from 'svelte';
  import { api, openExternal } from '../lib/api.js';
  import { go, showError } from '../lib/state.svelte.js';
  import DogAvatar from '../lib/DogAvatar.svelte';

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

<h1>Encontros</h1>
{#if items && items.length === 0}
  <p class="empty">Nenhum encontro ainda. Vá em Descobrir!</p>
{/if}

{#each sections as [title, list]}
  {#if list.length}
    <h3>{title}</h3>
    {#each list as m (m.id)}
      <div class="card row wrap">
        <DogAvatar photo={m.other_dog.photo_url} />
        <div class="grow">
          <button class="link" onclick={() => go('dog', m.other_dog.id)}><strong>{m.other_dog.name}</strong></button>
          ({m.other_dog.breed}) com {m.my_dog.name}<br />
          <small class="muted">Dono(a): {m.other_owner.first_name}</small>
        </div>
        {#if m.status === 'pending' && m.direction === 'incoming'}
          <button class="danger" onclick={() => respond(m, false)}>Recusar</button>
          <button class="primary" onclick={() => respond(m, true)}>Aceitar</button>
        {/if}
        {#if m.other_owner.phone}
          <span>📞 {m.other_owner.phone}</span>
          <button class="link" onclick={() => openExternal(`https://wa.me/55${m.other_owner.phone}`)}>WhatsApp</button>
        {/if}
      </div>
    {/each}
  {/if}
{/each}
