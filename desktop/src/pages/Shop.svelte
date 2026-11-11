<script>
  // Loja: catálogo dos pet shops parceiros. A compra é feita direto com o pet shop.
  import { onMount } from 'svelte';
  import { api, formatPrice, imageUrl, openExternal, productCategories, whatsapp } from '../lib/api.js';
  import { showError } from '../lib/state.svelte.js';
  import Icon from '../lib/Icon.svelte';

  let category = $state('');
  let products = $state(null);
  const load = async () => (products = await api('GET', `/products?category=${category}`).catch((e) => (showError(e), [])));
  onMount(load);

  function buy(p) {
    if (p.link) return openExternal(p.link);
    if (p.provider_phone) openExternal(whatsapp(p.provider_phone, `Oi! Quero o produto "${p.name}" que vi no All Love 🐾`));
  }
</script>

<div class="page-header"><h1>Loja</h1></div>
<p class="muted">Produtos dos pet shops parceiros. A compra é combinada direto com a loja.</p>

<div class="cats">
  <button class="cat" class:on={category === ''} onclick={() => { category = ''; load(); }}><Icon name="apps" filled /> Tudo</button>
  {#each Object.entries(productCategories) as [k, v]}
    <button class="cat" class:on={category === k} onclick={() => { category = k; load(); }}><Icon name={v.icon} filled={category === k} /> {v.label}</button>
  {/each}
</div>

<div class="grid">
  {#each products ?? [] as p, i (p.id)}
    <article class="prod rise" style="animation-delay:{i * 40}ms">
      <div class="ph r{i % 3}">
        <Icon name={productCategories[p.category].icon} filled size={64} />
        {#if p.photo_url}<img src={imageUrl(p.photo_url)} alt="" />{/if}
        <span class="price shape-cookie12">{formatPrice(p.price_cents)}</span>
      </div>
      <div class="body">
        <small class="muted">{productCategories[p.category].label} · {p.provider_name ?? 'All Love'}</small>
        <strong class="name">{p.name}</strong>
        <span class="desc">{p.description}</span>
        <button class="primary buy" onclick={() => buy(p)}><Icon name="shopping_bag" /> Quero!</button>
      </div>
    </article>
  {:else}
    {#if products}<div class="empty"><Icon name="inventory_2" />Nada nesta categoria ainda.</div>{/if}
  {/each}
</div>

<style>
  .cats { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 20px; }
  .cat { height: 44px; border-radius: 22px; border: 1px solid var(--md-outline-variant); color: var(--md-on-surface); }
  .cat.on { background: var(--md-secondary-container); color: var(--md-on-secondary-container); border-color: transparent; border-radius: 14px; }
  .cat :global(.icon) { margin-left: -6px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 20px; }
  .prod { background: var(--md-surface-container-low); border-radius: 32px; overflow: hidden; display: flex; flex-direction: column; }
  .ph { position: relative; aspect-ratio: 1; display: grid; place-items: center; background: var(--md-primary-container); color: var(--md-on-primary-container); }
  .ph.r0 { border-radius: 32px 32px 80px 8px; }
  .ph.r1 { border-radius: 32px 32px 8px 80px; }
  .ph.r2 { border-radius: 32px; }
  .ph img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; border-radius: inherit; }
  .price { position: absolute; right: 10px; bottom: 10px; min-width: 92px; height: 92px; display: grid; place-items: center; background: var(--like); color: #231b00; font-family: var(--font-display); font-weight: 800; font-size: 17px; padding: 0 8px; }
  .body { padding: 14px 18px 18px; display: flex; flex-direction: column; gap: 4px; flex: 1; }
  .name { font-family: var(--font-display); font-size: 20px; line-height: 23px; }
  .desc { font-size: 14px; line-height: 19px; color: var(--md-on-surface-variant); flex: 1; }
  .buy { margin-top: 10px; height: 48px; border-radius: 24px; }
</style>
