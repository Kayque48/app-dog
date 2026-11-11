---
tags: [all-love, guia]
---
# Como rodar

> [!TIP]
> Suba primeiro a **API**. Os dois apps dependem dela.

## 1. API (`backend/`)
Precisa do [Rust](https://rustup.rs).
```bash
cd backend
cargo run
```
- Sobe em `http://localhost:3000` e cria `alllove.db` com os dados de [[Contas-de-Exemplo]].
- Testes das regras de negócio: `cargo test`.

| Variável | Para que serve |
|---|---|
| `PORT` | Porta da API |
| `DATABASE_URL` | Arquivo do banco (ex.: `sqlite://alllove.db`) |
| `UPLOAD_DIR` | Pasta das fotos, vídeos e PDFs |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Conta da moderação |
| `SEED_DEMO=0` | Não criar os dados de exemplo |

> [!NOTE]
> As migrações rodam sozinhas ao iniciar. Bancos antigos recebem os eventos, profissionais e produtos de exemplo se ainda não tiverem nenhum.

## 2. App mobile (`mobile/`)
Precisa do [Flutter](https://docs.flutter.dev/get-started/install).
```bash
cd mobile
flutter pub get
flutter run
```
- No emulador Android, a API é acessada em `10.0.2.2:3000`.
- Em um celular de verdade: `flutter run --dart-define=API_URL=http://IP-DO-COMPUTADOR:3000`.

## 3. App desktop (`desktop/`)
Precisa de Node 18+, Rust e as [dependências do Tauri](https://v2.tauri.app/start/prerequisites/). No Linux são as bibliotecas `webkit2gtk-4.1` e `gtk3`.
```bash
cd desktop
npm install
npm run tauri dev
```
- Instalador: `npm run tauri build`.
- Só a interface, no navegador: `npm run dev` e abra `http://localhost:1420`.
- Outra API: crie `desktop/.env` com `VITE_API_URL=http://endereco:3000`.

Veja também [[App-Mobile]] e [[App-Desktop]].

## Atualizar a wiki do GitHub
A wiki é gerada a partir desta pasta (`docs/wiki`). Depois de editar no Obsidian:
```bash
bash docs/publicar-wiki.sh
```
> [!IMPORTANT]
> Na primeira vez, crie uma página qualquer na aba **Wiki** do GitHub ("Create the first page"). Só depois disso o GitHub cria o repositório da wiki.
