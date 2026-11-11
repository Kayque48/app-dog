---
tags: [all-love, projeto]
---
# Decisões e limitações

## Do documento de funcionalidades: o que não entrou
| Item | Motivo |
|---|---|
| Nome "Fatal Dog" | O cliente deu ao app o nome **All Love** |
| Rastreamento do cão por GPS | O cliente pediu segurança, e "pedir localização" foi um dos motivos de denúncia que ele citou. O app nunca mostra a posição exata de ninguém. Também exigiria um hardware |
| Pagamento na loja | O modelo do cliente é anúncio, patrocínio e premium (pagamento ainda não definido). A loja virou um catálogo de parceiros |
| Intermediação de cruzamento em clínicas | Virou um serviço agendável na clínica ("Acompanhamento de cruzamento") |

## Em aberto com o cliente
- **Premium:** o pagamento ainda não foi definido; hoje é só um interruptor.
- **Vacinação oficial:** não há integração com a carteira oficial, e o dono registra as vacinas à mão.
- **Agendamentos:** o estabelecimento confirma por telefone. Ainda não existe painel para ele.

## Escala (20 a 50 mil acessos)
O SQLite atende bem uma turma. Para produção:
- trocar por **PostgreSQL** (o sqlx suporta);
- guardar os uploads num armazenamento de objetos;
- usar um servidor com mais núcleos e o banco separado.

## Ambiente de desenvolvimento
- **Tauri:** a parte Rust do desktop precisa das bibliotecas `webkit2gtk-4.1` e `gtk3` instaladas.
- **Fotos de exemplo:** são carregadas direto do Unsplash, então precisam de internet. Sem internet aparece o ícone de pata.
