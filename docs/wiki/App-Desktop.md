---
tags: [all-love, tecnico, svelte, tauri]
---
# App desktop (Tauri + Svelte)

Tem as mesmas funcionalidades do mobile, com o menu lateral (navigation drawer) e mais o painel de [[Moderacao]] para administradores.

## Menu
Feed · Descobrir · Eventos · Encontros · Parques · Serviços · Loja · Meus cães · Perfil · Moderação

## Arquivos
- `src/App.svelte`: layout, menu e badges.
- `src/lib/api.js`: cliente HTTP, rótulos, formatação, `openExternal` e `playBark` (o "au au" sintetizado).
- `src/lib/state.svelte.js`: estado global (usuário, página, avisos, contadores).
- `src/lib/`: componentes `Icon`, `DogAvatar`, `DogForm`, `AdBanner` e `Comments`.
- `src/pages/`: uma página por tela.
- `src/app.css` e `src/shapes.css`: tema M3 Expressive e formas.
- `src-tauri/`: casca nativa (Rust), com o plugin `opener` para abrir links no navegador.

## Comandos
```bash
npm run dev          # só a interface, no navegador
npm run tauri dev    # app nativo
npm run tauri build  # instalador
```
