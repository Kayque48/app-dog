<script>
  // Formulário de cadastro/edição do cão.
  import { untrack } from 'svelte';
  import { api, sexes, temperaments, today, upload } from './api.js';
  import { showError } from './state.svelte.js';
  import DogAvatar from './DogAvatar.svelte';
  import Icon from './Icon.svelte';

  let { dog = null, onsaved, oncancel } = $props();

  // Cópia inicial do cão para edição (o formulário é recriado ao trocar de cão).
  let form = $state(
    untrack(() =>
      dog
        ? { ...dog }
        : { name: '', breed: '', birth_date: '', sex: 'macho', in_heat: false, temperament: 'calmo', bites: false, likes: '', dislikes: '', photo_url: null },
    ),
  );
  let saving = $state(false);
  let fileInput;

  async function pickPhoto(e) {
    const file = e.target.files[0];
    if (!file) return;
    try { form.photo_url = await upload(file); } catch (err) { showError(err); }
  }

  async function save(e) {
    e.preventDefault();
    saving = true;
    const body = {
      name: form.name, breed: form.breed, birth_date: form.birth_date, sex: form.sex,
      in_heat: form.sex === 'femea' && form.in_heat, temperament: form.temperament, bites: form.bites,
      likes: form.likes, dislikes: form.dislikes, photo_url: form.photo_url,
    };
    try {
      const saved = dog ? await api('PUT', `/dogs/${dog.id}`, body) : await api('POST', '/dogs', body);
      onsaved?.(saved);
    } catch (err) { showError(err); } finally { saving = false; }
  }
</script>

<form class="card outlined" onsubmit={save}>
  <h2>{dog ? `Editar ${dog.name}` : 'Cadastrar cão'}</h2>
  <div class="row photo">
    <DogAvatar photo={form.photo_url} size={80} />
    <input type="file" accept="image/*" bind:this={fileInput} onchange={pickPhoto} hidden />
    <button type="button" class="tonal" onclick={() => fileInput.click()}><Icon name="add_a_photo" /> Escolher foto</button>
  </div>
  <div class="grid2">
    <label>Nome <input bind:value={form.name} required /></label>
    <label>Raça (ou vira-lata) <input bind:value={form.breed} required /></label>
    <label>Nascimento (aproximado) <input type="date" max={today()} bind:value={form.birth_date} required /></label>
    <label>Temperamento
      <select bind:value={form.temperament}>
        {#each Object.entries(temperaments) as [k, v]}<option value={k}>{v}</option>{/each}
      </select>
    </label>
  </div>

  <div class="segmented" role="group" aria-label="Sexo">
    {#each Object.entries(sexes) as [k, v]}
      <button type="button" class:selected={form.sex === k} onclick={() => (form.sex = k)}>
        {#if form.sex === k}<Icon name="check" />{/if} {v}
      </button>
    {/each}
  </div>

  <label class="check"><input type="checkbox" class="switch" bind:checked={form.bites} /> Costuma morder</label>
  {#if form.sex === 'femea'}
    <label class="check"><input type="checkbox" class="switch" bind:checked={form.in_heat} /> Está no cio</label>
  {/if}

  <div class="grid2 likes">
    <label>Do que gosta <input bind:value={form.likes} placeholder="Ex.: morder bolinha" /></label>
    <label>Do que não gosta <input bind:value={form.dislikes} placeholder="Ex.: chinelo" /></label>
  </div>
  {#if !dog}
    <p class="muted hint">
      <Icon name="info" size={18} /> Depois de salvar, registre as vacinas no perfil do cão. Sem V8/V10 e antirrábica
      em dia ele não aparece no Descobrir.
    </p>
  {/if}
  <div class="row actions">
    <button type="button" class="text" onclick={() => oncancel?.()}>Cancelar</button>
    <button class="primary" disabled={saving}>{saving ? 'Salvando...' : 'Salvar'}</button>
  </div>
</form>

<style>
  form { padding: 24px; }
  h2 { margin-top: 0; }
  .photo { margin-bottom: 24px; gap: 16px; }
  .likes { margin-top: 16px; }
  .hint { font-size: 14px; }
  .actions { justify-content: flex-end; margin-top: 8px; }
</style>
