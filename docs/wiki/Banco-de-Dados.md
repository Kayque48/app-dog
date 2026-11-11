---
tags: [all-love, tecnico, banco]
---
# Banco de dados

SQLite com migrações em `backend/migrations/`, que rodam sozinhas ao iniciar a API.

```mermaid
erDiagram
  users ||--o{ dogs : "tem"
  users ||--o{ sessions : ""
  dogs ||--o{ vaccines : ""
  dogs ||--o{ dog_documents : "carteira"
  dogs ||--o{ dog_events : "histórico"
  dogs ||--o{ posts : ""
  posts ||--o{ post_likes : ""
  posts ||--o{ post_comments : ""
  dogs ||--o{ match_requests : "pede / recebe"
  users ||--o{ reports : "denuncia / é denunciado"
  events ||--o{ event_rsvps : ""
  events ||--o{ event_entries : "concurso"
  event_entries ||--o{ event_votes : ""
  providers ||--o{ appointments : ""
  providers ||--o{ products : ""
  dogs ||--o{ appointments : ""
  places
  ads
```

| Tabela | Para que serve |
|---|---|
| `users` | Donos e administradores. CPF único, bloqueio (`banned_at`), exclusão (`deleted_at`) |
| `sessions` | Tokens de login |
| `dogs` | Perfil e carteira (peso, cor, atividade, procura, microchip, castração...). `removed_at` mantém o histórico |
| `vaccines` | Aplicação e reforço |
| `dog_documents` | Pedigree, exames, RG... (`status`: enviado, verificado, recusado) |
| `dog_events` | Histórico do cão |
| `posts`, `post_likes`, `post_comments` | Feed (`media_type`: image ou video) |
| `match_requests` | `passed`, `pending`, `accepted` ou `rejected` |
| `events`, `event_rsvps`, `event_entries`, `event_votes` | Eventos, presença, concurso e votos (um por pessoa) |
| `providers`, `appointments`, `products` | Serviços, agendamentos e loja |
| `places` | Parques e pontos de encontro |
| `reports` | Denúncias (`aberta`, `procedente` ou `improcedente`) |
| `ads` | Anúncios de patrocinadores |
