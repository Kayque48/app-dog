<script>
  // Formulário de cadastro/edição do cão.
  import { untrack } from 'svelte';
  import { api, sexes, temperaments, today, upload } from './api.js';
  import { showError } from './state.svelte.js';
  import DogAvatar from './DogAvatar.svelte';

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

<form class="card" onsubmit={save}>
  <h3>{dog ? `Editar ${dog.name}` : 'Cadastrar cão'}</h3>
  <div class="row">
    <DogAvatar photo={form.photo_url} size={72} />
    <label class="grow">Foto <input type="file" accept="image/*" onchange={pickPhoto} /></label>
  </div>
  <div class="grid2">
    <label>Nome <input bind:value={form.name} required /></label>
    <label>Raça (ou vira-lata) <input bind:value={form.breed} required /></label>
    <label>Nascimento (aproximado) <input type="date" max={today()} bind:value={form.birth_date} required /></label>
    <label>Sexo
      <select bind:value={form.sex}>{#each Object.entries(sexes) as [k, v]}<option value={k}>{v}</option>{/each}</select>
    </label>
    <label>Temperamento
      <select bind:value={form.temperament}>
        {#each Object.entries(temperaments) as [k, v]}<option value={k}>{v}</option>{/each}
      </select>
    </label>
    <div>
      <label class="check"><input type="checkbox" bind:checked={form.bites} /> Costuma morder</label>
      {#if form.sex === 'femea'}
        <label class="check"><input type="checkbox" bind:checked={form.in_heat} /> Está no cio</label>
      {/if}
    </div>
  </div>
  <label>Do que gosta <input bind:value={form.likes} placeholder="Ex.: morder bolinha" /></label>
  <label>Do que não gosta <input bind:value={form.dislikes} placeholder="Ex.: chinelo" /></label>
  {#if !dog}
    <p class="muted">Depois de salvar, registre as vacinas no perfil do cão. Sem V8/V10 e antirrábica em dia ele não aparece no Descobrir.</p>
  {/if}
  <div class="row">
    <button class="primary" disabled={saving}>{saving ? 'Salvando...' : 'Salvar'}</button>
    <button type="button" onclick={() => oncancel?.()}>Cancelar</button>
  </div>
</form>
