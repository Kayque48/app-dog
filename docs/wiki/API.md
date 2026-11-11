---
tags: [all-love, tecnico, api]
---
# API

- **Base:** `http://localhost:3000/api`. Os arquivos ficam em `/uploads/...`.
- **Autenticação:** com exceção de cadastro e login, toda rota exige `Authorization: Bearer <token>`.
- **Erros:** respondem `{ "error": "mensagem em português" }` com o código HTTP adequado (400, 401, 403, 404, 409).

## Conta
| Método | Rota | Descrição |
|---|---|---|
| POST | `/auth/register` | Cadastro do dono (CPF, telefone, CEP, aceite dos termos) |
| POST | `/auth/login` | Login (devolve `token` e `user`) |
| POST | `/auth/logout` | Encerra a sessão |
| GET / PUT / DELETE | `/me` | Meus dados / atualizar / excluir conta (LGPD) |
| PUT | `/me/location` | Envia a localização atual |
| PUT | `/me/premium` | Liga ou desliga o premium |
| GET | `/users/{id}` | Perfil público do dono (cães atuais e antigos, incidentes) |

## Cães e carteira
| Método | Rota | Descrição |
|---|---|---|
| GET | `/dogs/mine` | Meus cães (atuais e antigos) |
| POST | `/dogs` | Cadastrar cão |
| GET / PUT / DELETE | `/dogs/{id}` | Perfil com histórico / editar / remover (mantém o histórico) |
| GET / POST | `/dogs/{id}/vaccines` | Vacinas |
| DELETE | `/vaccines/{id}` | Apagar registro de vacina |
| GET / POST | `/dogs/{id}/documents` | Documentos da carteira (só o dono vê) |
| DELETE | `/documents/{id}` | Apagar documento |

## Feed
| Método | Rota | Descrição |
|---|---|---|
| POST | `/uploads` | Upload (`multipart`, campo `file`): imagem, vídeo ou PDF |
| GET | `/feed?page=0` | 20 posts por página, mais recentes primeiro |
| POST | `/posts` | Publicar (`dog_id`, `image_url`, `caption`). Detecta se é vídeo |
| DELETE | `/posts/{id}` | Apagar (autor ou moderação) |
| POST | `/posts/{id}/like` | Curtir / descurtir |
| GET / POST | `/posts/{id}/comments` | Comentários |
| DELETE | `/comments/{id}` | Apagar comentário |

## Descobrir e encontros
| Método | Rota | Descrição |
|---|---|---|
| GET | `/discover?dog_id=&radius_m=500&goal=amizade` | Cartões por perto. `goal=cruzamento` filtra para cruzamento |
| POST | `/swipes` | `{from_dog_id, to_dog_id, liked}`. Devolve `{matched}` |
| GET | `/matches` | Pedidos recebidos, enviados e encontros aceitos |
| POST | `/matches/{id}/respond` | `{accept}` |

## Eventos
| Método | Rota | Descrição |
|---|---|---|
| GET / POST | `/events` | Próximos eventos / criar |
| GET | `/events/{id}` | Evento, ranking do concurso, meu voto, quem vai |
| POST | `/events/{id}/rsvp` | `{status: "going" \| "maybe" \| null}` |
| POST | `/events/{id}/entries` | Inscrever cão no concurso |
| POST | `/events/{id}/vote` | `{entry_id}` |

## Serviços e loja
| Método | Rota | Descrição |
|---|---|---|
| GET / POST | `/providers?kind=` | Profissionais por distância / cadastrar negócio |
| GET | `/providers/{id}` | Detalhe e produtos |
| GET / POST | `/appointments` | Meus agendamentos / agendar |
| POST | `/appointments/{id}/cancel` | Cancelar |
| GET | `/products?category=` | Catálogo da loja |

## Locais, anúncios e denúncias
| Método | Rota | Descrição |
|---|---|---|
| GET / POST | `/places` | 5 locais mais perto / sugerir |
| GET | `/ads/random` | Anúncio aleatório (`null` para premium) |
| POST | `/reports` | Denunciar dono ou cão |

## Moderação (só administrador)
| Método | Rota | Descrição |
|---|---|---|
| GET | `/admin/reports?status=aberta` | Denúncias |
| POST | `/admin/reports/{id}/resolve` | `{procedente, ban}` |
| GET | `/admin/users?q=` | Busca por nome, e-mail ou CPF |
| POST | `/admin/users/{id}/ban` | Bloqueio permanente `{reason}` |
| GET | `/admin/pedigrees` | Pedigrees aguardando análise |
| POST | `/admin/pedigrees/{id}/review` | `{approved}` |
| GET | `/admin/providers` | Profissionais sem selo |
| POST | `/admin/providers/{id}/verify` | Dar selo de verificado |
