<script>
  // Ícone do Material Symbols: <Icon name="pets" /> (lista em fonts.google.com/icons)
  let { name, filled = false, size = null } = $props();
</script>

<span class="icon" class:filled style={size ? `font-size:${size}px` : ''} aria-hidden="true">{name}</span>
