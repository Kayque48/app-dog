# All Love 🐾

Rede social para cachorros, feita a partir da entrevista com o cliente. Os donos cadastram seus cães, publicam fotos, encontram cães por perto no estilo Tinder e marcam encontros em parques próximos.

> Projeto de ensino. Não vai a público.

## Estrutura

| Pasta      | O que é                     | Tecnologia                                   |
|------------|-----------------------------|----------------------------------------------|
| `backend/` | API usada pelos dois apps   | Rust ([axum](https://github.com/tokio-rs/axum)) + SQLite ([sqlx](https://github.com/launchbadge/sqlx)) |
| `mobile/`  | App para celular e tablet   | Flutter                                      |
| `desktop/` | App para computador         | Tauri 2 (Rust) + Svelte 5                    |

Os dois apps falam com a mesma API, então quem usa o celular encontra quem usa o computador.

O desktop também tem o painel de **Moderação**, que aparece só para administradores.

Os dois apps seguem o **Material 3**. As cores são geradas a partir do azul fraquinho pedido pelo cliente (`#7EB6E6`), com tema claro e escuro. No Flutter isso vem do `ColorScheme.fromSeed`; no desktop, de tokens CSS gerados com o `@material/material-color-utilities`, com ícones Material Symbols e a fonte Roboto empacotados no app.

## Do pedido do cliente para o app

| O cliente pediu                                                      | Onde está                                                                                    |
|----------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
| Donos cadastram seus pets                                            | Perfil → Cadastrar cão                                                                       |
| Cadastro simples, mas seguro: telefone, CPF, onde mora               | Cadastro com CPF (dígitos verificadores conferidos), telefone, CEP (endereço puxado do ViaCEP) |
| Scrollar fotos e dar like                                            | Aba Feed (curtir com botão ou dois toques na foto)                                           |
| Cães a 500 metros, arrastar para o lado, o outro aceita ou não       | Aba Descobrir (500 m por padrão) → pedido de encontro → o outro dono aceita ou recusa na aba Encontros |
| Informações do cão: raça, idade, cio, gostos, se morde, se é agressivo | Perfil do cão (temperamento, morde, gosta e não gosta, cio)                                |
| Parques e pontos de encontro próximos (5)                            | Aba Parques: os 5 mais perto, abre no mapa, e o dono pode sugerir novos pontos               |
| Vacinas em dia, senão bloqueia                                       | Carteira de vacinação. Sem V8/V10 e antirrábica, ou com reforço atrasado, o cão some do Descobrir e aparece o aviso para vacinar |
| Denúncia e bloqueio permanente (obscenidade, perfil falso, pedir localização, mordida, processo judicial) | Botão 🚩 no perfil do cão. A moderação analisa e pode bloquear a conta e o CPF para sempre |
| Histórico do cão e de quais cães o dono já teve                      | Histórico no perfil do cão (cadastro, vacinas, encontros, incidentes) e perfil do dono com cães atuais e antigos |
| Grátis com anúncios de pet shops / premium sem anúncios              | Banner de patrocinador. O interruptor "Premium" no Perfil tira os anúncios (pagamento ainda não definido pelo cliente) |
| Mobile e tablet                                                      | Flutter com layout de tablet (menu lateral)                                                  |
| Cores azul fraquinho e branco                                        | Material 3 com a cor semente `#7EB6E6` (cães enxergam bem o azul 😉)                        |
| LGPD                                                                 | Aceite dos termos no cadastro, exclusão de conta, CPF e telefone visíveis só para a moderação, localização exata nunca mostrada (só a distância) |

## Como rodar

### 1. API (`backend/`)

Precisa do [Rust](https://rustup.rs).

```bash
cd backend
cargo run
```

A API sobe em `http://localhost:3000` e cria o banco `alllove.db` com dados de exemplo.

O administrador é `admin@alllove.local`, senha `admin123`.

### Dados de exemplo

Para dar uma noção do app funcionando, a API cria 8 donos com cães perto do Parque Ibirapuera, todos a menos de 500 m uns dos outros. A senha de todos é `demo1234`.

| E-mail               | Cão                          | O que dá para ver com essa conta                                                     |
|----------------------|------------------------------|--------------------------------------------------------------------------------------|
| `joao@demo.local`    | Thor (Golden Retriever)      | Encontro já combinado com a Mel, pedido do Bento esperando resposta e 2 fotos no feed |
| `maria@demo.local`   | Mel (Shih Tzu)               | Pedido da Pipoca para responder e a Nina em "cães que já tive"                       |
| `ana@demo.local`     | Luna (vira-lata, no cio)     | Pedido enviado para o Bento                                                          |
| `pedro@demo.local`   | Bento (Border Collie)        | Pedido enviado para o Thor e o da Luna para responder                                |
| `beatriz@demo.local` | Pipoca (Pug)                 | Pedido enviado para a Mel                                                            |
| `lucas@demo.local`   | Salsicha (Dachshund)         | Foto no feed                                                                         |
| `rafaela@demo.local` | Bidu (Buldogue Francês)      | **Vacinas atrasadas**: o Bidu fica bloqueado no Descobrir                            |
| `carlos@demo.local`  | Rex (vira-lata, agressivo)   | Incidente confirmado no histórico e uma denúncia aberta na moderação                 |

O feed vem com 7 fotos e curtidas. Os parques de exemplo ficam em São Paulo e os anúncios são de pet shops fictícios.

Variáveis opcionais:

| Variável                         | Para que serve                                        |
|----------------------------------|-------------------------------------------------------|
| `PORT`                           | Porta da API                                          |
| `DATABASE_URL`                   | Arquivo do banco                                      |
| `UPLOAD_DIR`                     | Pasta das fotos                                       |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Conta de administrador                                |
| `SEED_DEMO=0`                    | Não criar os donos de exemplo                         |

Para rodar os testes das regras de negócio (CPF, distância, vacinas):

```bash
cargo test
```

### 2. App mobile (`mobile/`)

Precisa do [Flutter](https://docs.flutter.dev/get-started/install).

```bash
cd mobile
flutter pub get
flutter run
```

No emulador Android a API é acessada em `10.0.2.2:3000`. Em um celular de verdade, use o IP do computador:

```bash
flutter run --dart-define=API_URL=http://192.168.0.10:3000
```

### 3. App desktop (`desktop/`)

Precisa de Node 18+, Rust e as [dependências do Tauri para o seu sistema](https://v2.tauri.app/start/prerequisites/). No Linux elas são as bibliotecas `webkit2gtk-4.1` e `gtk3`.

```bash
cd desktop
npm install
npm run tauri dev
```

Para gerar o instalador:

```bash
npm run tauri build
```

Se quiser só olhar a interface no navegador, sem Tauri, rode `npm run dev` e abra `http://localhost:1420`. Para apontar para outra API, crie `desktop/.env` com `VITE_API_URL=http://endereco:3000`.

## Regras de negócio

- **CPF** precisa ser válido e é único. CPF de conta bloqueada não pode criar outra conta.
- **Descobrir** só funciona se o seu cão estiver com a vacinação em dia. Só aparecem cães também em dia, de donos não bloqueados, dentro do raio escolhido (500 m, 1 km ou 3 km).
- **Vacinação em dia** quer dizer ter V8 ou V10 e antirrábica registradas, e nenhuma vacina com a data de reforço vencida. Vale sempre o registro mais recente de cada vacina.
- **Encontro**: arrastar para a direita envia um pedido. Se o outro cão já tinha pedido, o encontro é combinado na hora. O telefone do outro dono só aparece depois do aceite.
- **Denúncia procedente** entra no histórico do cão como incidente e pode bloquear o dono permanentemente. A moderação também pode bloquear direto, por exemplo em caso de processo judicial.
- **Remover um cão** não apaga o histórico: ele continua na lista de "cães que já tive".
- **Excluir conta** apaga os dados pessoais. Ela fica bloqueada enquanto houver denúncia em análise contra a conta.

## Fora do escopo desta versão

Estes pontos foram citados na entrevista, mas ainda estão em aberto com o cliente:

- **Pagamento do premium.** Por enquanto é só um interruptor.
- **Integração com uma carteira de vacinação oficial.** Hoje o dono registra as vacinas à mão.
- **Capacidade de 20 a 50 mil acessos.** O SQLite atende bem uma turma. Para produção, a troca natural é PostgreSQL (o sqlx também suporta) e um servidor com vários núcleos.

## Créditos das fotos

As fotos dos dados de exemplo são do [Unsplash](https://unsplash.com) e são carregadas direto de lá, como pedem as [regras de uso do Unsplash](https://help.unsplash.com/en/articles/2511245-unsplash-api-guidelines).

| Foto | Autor |
|---|---|
| Mel | [Adam Grabek](https://unsplash.com/@agmakonts) |
| Thor | [Nick van der Vegt](https://unsplash.com/@nick_vandervegt) |
| Luna | [Rafael Forseck](https://unsplash.com/@jpeg_therapy) |
| Bento | [Anna Stampfli](https://unsplash.com/@annastampfli) |
| Pipoca | [James Tiono](https://unsplash.com/@jamestiono) |
| Salsicha | [Valdrin Maksutaj](https://unsplash.com/@volliem) |
| Bidu | [Mikhail Mamaev](https://unsplash.com/@mikhail_mamaev) |
| Rex | [Random Thinking](https://unsplash.com/@randomthinking) |
| Nina | [Meagan Barr](https://unsplash.com/@megz_barr) |
| Fotos do feed | [keila Paludo](https://unsplash.com/@keilapaludo), [Jackie Best](https://unsplash.com/@bugsandslugs), [Denis Bayer](https://unsplash.com/@denisbayer), [Mikhail Mamaev](https://unsplash.com/@mikhail_mamaev), [David Valentine](https://unsplash.com/@thephotochad), [Gosia Jamrozik](https://unsplash.com/@gosiaj), [yu wang](https://unsplash.com/@boboguai2) |
