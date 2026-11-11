---
tags: [all-love, funcionalidade, seguranca, lgpd]
---
# Cadastro e segurança

O cliente queria um cadastro **simples**, que até "as senhorinhas" consigam usar, mas **seguro**: se alguém mal-intencionado entrar, tem de ser possível identificar a pessoa.

## Cadastro do dono
- **Campos obrigatórios:** nome, e-mail, senha, telefone com DDD, **CPF**, CEP, cidade e endereço.
- **CPF:** os dígitos verificadores são conferidos e o CPF não pode se repetir. CPF de conta bloqueada não cria outra conta.
- **CEP:** preenche cidade e rua pelo ViaCEP.
- **LGPD:** é preciso aceitar os termos de uso e a política de privacidade.

## Quem vê o quê
| Dado | Outros donos | Moderação |
|---|---|---|
| Primeiro nome e cidade | ✅ | ✅ |
| Telefone | Só depois de um encontro aceito | ✅ |
| CPF, endereço, e-mail | ❌ | ✅ |
| Localização exata | ❌ (só a distância aproximada) | ❌ |
| Documentos da carteira do cão | ❌ | ✅ |

## Conta
- **Login:** por token (`Authorization: Bearer ...`) e senha guardada com **Argon2**.
- **Exclusão de conta (LGPD):** apaga os dados pessoais, e os cães saem do perfil mantendo o histórico anônimo. Ela fica **bloqueada enquanto houver denúncia em análise** contra a conta.
- **Conta bloqueada:** não consegue entrar nem usar a API.

Relacionado: [[Moderacao]], [[Regras-de-Negocio]].
