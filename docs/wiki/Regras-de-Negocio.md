---
tags: [all-love, regras]
---
# Regras de negócio

As regras puras ficam em `backend/src/rules.rs` e têm testes (`cargo test`).

## Cadastro
- **CPF:** válido pelos dígitos verificadores e único. CPF de conta bloqueada não cria outra conta.
- **Telefone e CEP:** telefone com 10 ou 11 dígitos (com DDD) e CEP com 8 dígitos.
- **Termos:** é obrigatório aceitar os termos de uso e a política de privacidade (LGPD).

## Vacinação
- **"Em dia":** o cão precisa ter **V8 ou V10** e **antirrábica** registradas e **nenhum reforço vencido**. Vale sempre o registro mais recente de cada vacina.
- **Descobrir:** cão fora do dia não usa nem aparece no [[Descobrir-e-Match]], e vê o aviso para vacinar.
- **Eventos:** cão fora do dia não se inscreve em concursos de [[Eventos]].

## Descobrir
- **Distância:** raio padrão de **500 m** (pode ir de 100 m a 20 km pela API).
- **Quem não aparece:** cães de donos bloqueados ou excluídos, cães removidos e cães já avaliados.
- **Privacidade:** a distância é arredondada para 10 m e a localização exata nunca é enviada.
- **Cruzamento:** só sexo oposto, não castrado e que também procura cruzamento. **Cão castrado não pode marcar cruzamento.**
- **Match:** se o outro cão já tinha pedido, o match acontece na hora.
- **Telefone:** o telefone do outro dono só aparece depois do aceite.

## Eventos
- **Inscrição:** só em eventos com concurso, respeitando as regras do evento (sexo e raça).
- **Votos:** um voto por pessoa em cada evento (pode trocar) e não vale votar no próprio cão.

## Moderação
- **Denúncia procedente:** vira incidente no histórico do cão e pode bloquear a conta **para sempre**.
- **Exclusão de conta:** fica bloqueada enquanto houver denúncia em análise.

## Serviços e documentos
- **Agendamento:** só em horário futuro e para um cão do próprio dono.
- **Documentos:** os da carteira são privados. O pedigree só vira selo depois da verificação.
