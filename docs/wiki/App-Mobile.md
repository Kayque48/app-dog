---
tags: [all-love, tecnico, flutter]
---
# App mobile (Flutter)

Funciona no celular e no tablet. Em telas de 700 px ou mais, o menu vira uma barra lateral.

## Abas
| Aba | Conteúdo |
|---|---|
| Feed | [[Feed]] com stories, vídeos, comentários e blocos |
| Descobrir | [[Descobrir-e-Match]] |
| Encontros | Pedidos e encontros (com badge de pedidos novos) |
| Explorar | [[Eventos]], [[Servicos-e-Agendamento]], [[Loja]] e [[Parques]] |
| Perfil | Meus dados, meus cães, premium, sair e excluir conta |

## Arquivos
- `lib/main.dart`: tema e paleta.
- `lib/api.dart`: cliente HTTP e token.
- `lib/models.dart`: `Dog`, rótulos e formatação.
- `lib/widgets.dart`: formas, avatares e anúncio.
- `lib/screens/`: uma tela por arquivo, como `feed_screen`, `discover_screen`, `events_screen` (aba Explorar), `event_detail_screen`, `services_screen`, `shop_screen`, `dog_detail_screen`, `dog_wallet` e `dog_form_screen`.
- `assets/sounds/au_au.wav` e `assets/fonts/` (Bricolage Grotesque + licença OFL).

## Pacotes
`http`, `shared_preferences`, `image_picker`, `geolocator`, `url_launcher`, `video_player`, `file_picker` e `audioplayers`.

## Comandos úteis
```bash
flutter analyze
flutter test
flutter run --dart-define=API_URL=http://192.168.0.10:3000
```
