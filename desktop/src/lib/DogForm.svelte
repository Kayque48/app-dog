<script>
  // Formulário de cadastro/edição do cão.
  import { untrack } from 'svelte';
  import { activityLevels, api, lookingFor, sexes, temperaments, today, upload } from './api.js';
  import { showError } from './state.svelte.js';
  import DogAvatar from './DogAvatar.svelte';
  import Icon from './Icon.svelte';

  let { dog = null, onsaved, oncancel } = $props();

  // Cópia inicial do cão para edição (o formulário é recriado ao trocar de cão).
  let form = $state(
    untrack(() =>
      dog
        ? { ...dog }
        : {
            name: '', breed: '', birth_date: '', sex: 'macho', in_heat: false, temperament: 'calmo', bites: false,
            likes: '', dislikes: '', photo_url: null, weight_kg: null, color: '', bio: '', activity_level: 'medio',
            looking_for: 'amizade', microchip: '', neutered: false, allergies: '', health_notes: '',
          },
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
      weight_kg: form.weight_kg === '' || form.weight_kg == null ? null : Number(form.weight_kg),
      color: form.color, bio: form.bio, activity_level: form.activity_level,
      looking_for: form.neutered ? 'amizade' : form.looking_for,
      microchip: form.microchip, neutered: form.neutered, allergies: form.allergies, health_notes: form.health_notes,
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
    <label>Peso (kg) <input type="number" step="0.1" min="0.3" max="120" bind:value={form.weight_kg} /></label>
    <label>Cor <input bind:value={form.color} placeholder="Ex.: caramelo" /></label>
  </div>
  <label>Descrição (temperamento, comportamento, manias) <textarea rows="2" bind:value={form.bio}></textarea></label>

  <p class="section">Nível de atividade</p>
  <div class="segmented" role="group" aria-label="Atividade">
    {#each Object.entries(activityLevels) as [k, v]}
      <button type="button" class:selected={form.activity_level === k} onclick={() => (form.activity_level = k)}>
        {#if form.activity_level === k}<Icon name="check" />{/if} {v}
      </button>
    {/each}
  </div>

  <p class="section">Procura</p>
  <div class="segmented" role="group" aria-label="Procura">
    {#each Object.entries(lookingFor) as [k, v]}
      <button type="button" disabled={form.neutered && k !== 'amizade'} class:selected={(form.neutered ? 'amizade' : form.looking_for) === k} onclick={() => (form.looking_for = k)}>
        {#if (form.neutered ? 'amizade' : form.looking_for) === k}<Icon name="check" />{/if} {v}
      </button>
    {/each}
  </div>

  <h3 class="wallet"><Icon name="badge" /> Carteira digital</h3>
  <label class="check"><input type="checkbox" class="switch" bind:checked={form.neutered} /> Castrado</label>
  <div class="grid2">
    <label>Microchip <input bind:value={form.microchip} placeholder="15 dígitos" /></label>
    <label>Alergias <input bind:value={form.allergies} placeholder="Ex.: frango" /></label>
  </div>
  <label>Observações de saúde <textarea rows="2" bind:value={form.health_notes}></textarea></label>
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
  .section { font-size: 12px; color: var(--md-on-surface-variant); margin: 4px 0; }
  .wallet { display: flex; align-items: center; gap: 8px; margin-top: 12px; }
  .hint { font-size: 14px; }
  .actions { justify-content: flex-end; margin-top: 8px; }
</style>
