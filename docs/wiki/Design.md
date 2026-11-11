---
tags: [all-love, design]
---
# Design

## Material 3 Expressive
- **Formas:** formas orgânicas (cookie de 9 e de 12 ondas, flor e blob) em avatares, stories, datas e preços.
- **Tipografia:** títulos grandes na fonte **Bricolage Grotesque** (variável) e textos em Roboto.
- **Botões:** grandes e em pílula. "Vou / Talvez" e "Passa / Quero!" mudam de forma quando escolhidos.
- **Muito movimento:** curtida que pula, coração gigante, confete no match, formas girando e cartões entrando com animação.
- **Feed carregado:** blocos misturados para ter sempre conteúdo novo (ver [[Feed]]).

## As cores que o cachorro enxerga
Cães são **dicromatas**: têm cones só para **azul-violeta** e **amarelo**. Vermelho e verde viram um marrom acinzentado para eles. Por isso a paleta inteira usa só azul, amarelo, violeta e neutros.

| Papel | Claro | Escuro |
|---|---|---|
| Primária (azul) | `#2A4BDB` | `#B6C4FF` |
| Container primário (o azul fraquinho do cliente) | `#DBE2FF` | `#1F3BBF` |
| Secundária (amarelo) | `#FFD83D` | `#574500` |
| Terciária (violeta) | `#5C4FD6` | `#C7BFFF` |
| Curtida | `#F5B700` | `#FFD83D` |
| Superfície | `#F8F9FF` | `#0C1030` |

> [!NOTE]
> Até o **erro é amarelo** e o **sucesso é azul**, sempre com ícones de apoio (⚠️, ✅) para quem não distingue cores.

## Onde fica
- **Flutter:** `mobile/lib/main.dart` (`dogLight` e `dogDark`) e as formas em `mobile/lib/widgets.dart` (`Shapes`).
- **Desktop:** os tokens CSS em `desktop/src/app.css` e as formas em `desktop/src/shapes.css`, geradas por `r(θ) = base + amplitude·cos(nθ)`.
- **Ícones:** Material Symbols, que no desktop vão empacotados no app e funcionam offline.
