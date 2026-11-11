//! Dados de exemplo para ter uma noção do app funcionando.
//!
//! São 8 donos com cães perto do Parque Ibirapuera (todos a menos de 500 m uns dos outros),
//! fotos no feed, curtidas, pedidos de encontro, um cão com vacina atrasada,
//! um cão agressivo com incidente confirmado e uma denúncia aberta para a moderação.
//!
//! As fotos vêm do Unsplash (créditos no README). Todos usam a senha `demo1234`.

use chrono::{Days, Local};
use sqlx::SqlitePool;

use crate::auth::hash_password;

/// Monta a URL de uma foto do Unsplash já recortada em quadrado.
fn unsplash(photo: &str) -> String {
    format!("https://images.unsplash.com/{photo}?ixlib=rb-4.1.0&w=800&h=800&fit=crop&crop=entropy&q=80&fm=jpg")
}

/// Gera um CPF válido a partir de 9 dígitos (só para os dados de exemplo).
fn demo_cpf(base: &str) -> String {
    let mut d: Vec<u32> = base.chars().map(|c| c.to_digit(10).unwrap()).collect();
    for len in [9, 10] {
        let sum: u32 = d.iter().enumerate().map(|(i, x)| x * (len as u32 + 1 - i as u32)).sum();
        let rest = (sum * 10) % 11;
        d.push(if rest == 10 { 0 } else { rest });
    }
    d.iter().map(|x| char::from_digit(*x, 10).unwrap()).collect()
}

struct DemoDog {
    owner: &'static str,
    email: &'static str,
    phone: &'static str,
    /// deslocamento em relação ao Parque Ibirapuera, em graus (~0,001 = 110 m)
    offset: (f64, f64),
    name: &'static str,
    breed: &'static str,
    birth: &'static str,
    sex: &'static str,
    in_heat: bool,
    temperament: &'static str,
    bites: bool,
    likes: &'static str,
    dislikes: &'static str,
    photo: &'static str,
    /// vacinas atrasadas, para mostrar o bloqueio
    overdue: bool,
}

const DOGS: &[DemoDog] = &[
    DemoDog { owner: "Maria Souza", email: "maria@demo.local", phone: "11987650001", offset: (0.0006, 0.0006),
        name: "Mel", breed: "Shih Tzu", birth: "2021-03-15", sex: "femea", in_heat: false, temperament: "calmo", bites: false,
        likes: "Dormir no sofá, petiscos", dislikes: "Chinelo, barulho de moto", photo: "photo-1437957146754-f6377debe171", overdue: false },
    DemoDog { owner: "João Lima", email: "joao@demo.local", phone: "11987650002", offset: (-0.0006, -0.0014),
        name: "Thor", breed: "Golden Retriever", birth: "2019-08-02", sex: "macho", in_heat: false, temperament: "brincalhao", bites: false,
        likes: "Morder bolinha, nadar", dislikes: "Ficar sozinho", photo: "photo-1611003229186-80e40cd54966", overdue: false },
    DemoDog { owner: "Ana Costa", email: "ana@demo.local", phone: "11987650003", offset: (0.0015, 0.0021),
        name: "Luna", breed: "Vira-lata", birth: "2022-11-20", sex: "femea", in_heat: true, temperament: "timido", bites: false,
        likes: "Passear de manhã", dislikes: "Cachorros grandes", photo: "photo-1599765625577-61a6e65e3567", overdue: false },
    DemoDog { owner: "Pedro Almeida", email: "pedro@demo.local", phone: "11987650004", offset: (-0.0020, 0.0010),
        name: "Bento", breed: "Border Collie", birth: "2020-05-09", sex: "macho", in_heat: false, temperament: "brincalhao", bites: false,
        likes: "Correr atrás de frisbee", dislikes: "Ficar parado", photo: "photo-1623689278873-6981e40013ec", overdue: false },
    DemoDog { owner: "Beatriz Rocha", email: "beatriz@demo.local", phone: "11987650005", offset: (0.0025, -0.0008),
        name: "Pipoca", breed: "Pug", birth: "2023-01-30", sex: "femea", in_heat: false, temperament: "calmo", bites: false,
        likes: "Colo, soneca da tarde", dislikes: "Calor", photo: "photo-1632669672493-82abfc46da6b", overdue: false },
    DemoDog { owner: "Lucas Ferreira", email: "lucas@demo.local", phone: "11987650006", offset: (-0.0012, 0.0028),
        name: "Salsicha", breed: "Dachshund", birth: "2018-09-12", sex: "macho", in_heat: false, temperament: "timido", bites: false,
        likes: "Cobertor, cenoura", dislikes: "Escadas", photo: "photo-1689795467621-8b7f9bdc23fc", overdue: false },
    DemoDog { owner: "Rafaela Dias", email: "rafaela@demo.local", phone: "11987650007", offset: (0.0030, 0.0012),
        name: "Bidu", breed: "Buldogue Francês", birth: "2021-07-04", sex: "macho", in_heat: false, temperament: "brincalhao", bites: false,
        likes: "Bolinha amarela, folhas secas", dislikes: "Banho", photo: "photo-1778588783214-cd0b1992a668", overdue: true },
    DemoDog { owner: "Carlos Mendes", email: "carlos@demo.local", phone: "11987650008", offset: (-0.0025, -0.0020),
        name: "Rex", breed: "Vira-lata", birth: "2017-02-18", sex: "macho", in_heat: false, temperament: "agressivo", bites: true,
        likes: "Guardar o portão", dislikes: "Outros machos, bicicletas", photo: "photo-1652203243559-c9a451136f6f", overdue: false },
];

/// (cão, foto, legenda, dias atrás)
const POSTS: &[(&str, &str, &str, u64)] = &[
    ("Thor", "photo-1786861633874-a3daad97a85c", "Ninguém tira a bolinha azul do Thor 💙", 0),
    ("Pipoca", "photo-1768080646520-6bf539401e67", "Soneca da tarde é sagrada", 0),
    ("Mel", "photo-1661542157279-de91fdb574a6", "Mel depois do banho, toda cheirosa", 1),
    ("Bidu", "photo-1764558854396-3b074c531578", "Outono no Ibirapuera 🍂", 1),
    ("Bento", "photo-1544699207-f2c3440365ec", "Cansou de correr, finalmente", 2),
    ("Salsicha", "photo-1589935698791-5b0c81a0ce1a", "Salsicha no tapete favorito", 3),
    ("Thor", "photo-1738001525610-fca097d68b1c", "Olha essa carinha pedindo petisco", 4),
];

/// Um cão que a Maria já teve (aparece em "cães que já tive").
const PAST_DOG_PHOTO: &str = "photo-1763480789674-be1d6efeab91";

const IBIRAPUERA: (f64, f64) = (-23.5874, -46.6576);

pub async fn seed(pool: &SqlitePool) {
    let today = Local::now().date_naive();
    let fmt = |d: chrono::NaiveDate| d.format("%Y-%m-%d").to_string();
    let days_ago = |n: u64| fmt(today - Days::new(n));
    let in_days = |n: u64| fmt(today + Days::new(n));
    let password = hash_password("demo1234");

    let mut dog_ids = std::collections::HashMap::new();
    let mut owner_ids = std::collections::HashMap::new();

    for (i, d) in DOGS.iter().enumerate() {
        let user_id = sqlx::query(
            "INSERT INTO users (name, email, password_hash, phone, cpf, cep, city, address, lat, lng)
             VALUES (?, ?, ?, ?, ?, '04094050', 'São Paulo - SP', 'Vila Mariana', ?, ?)",
        )
        .bind(d.owner)
        .bind(d.email)
        .bind(&password)
        .bind(d.phone)
        .bind(demo_cpf(&format!("{:09}", 123_456_000 + i * 7)))
        .bind(round5(IBIRAPUERA.0 + d.offset.0))
        .bind(round5(IBIRAPUERA.1 + d.offset.1))
        .execute(pool)
        .await
        .unwrap()
        .last_insert_rowid();

        let dog_id = sqlx::query(
            "INSERT INTO dogs (owner_id, name, breed, birth_date, sex, in_heat, temperament, bites, likes, dislikes, photo_url)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(user_id)
        .bind(d.name)
        .bind(d.breed)
        .bind(d.birth)
        .bind(d.sex)
        .bind(d.in_heat)
        .bind(d.temperament)
        .bind(d.bites)
        .bind(d.likes)
        .bind(d.dislikes)
        .bind(unsplash(d.photo))
        .execute(pool)
        .await
        .unwrap()
        .last_insert_rowid();

        event(pool, dog_id, "cadastro", &format!("{} foi cadastrado no All Love", d.name)).await;
        let (applied, due) = if d.overdue { (days_ago(400), days_ago(35)) } else { (days_ago(60), in_days(300)) };
        for vaccine in ["V10", "Antirrábica"] {
            sqlx::query("INSERT INTO vaccines (dog_id, name, applied_on, next_due) VALUES (?, ?, ?, ?)")
                .bind(dog_id)
                .bind(vaccine)
                .bind(&applied)
                .bind(&due)
                .execute(pool)
                .await
                .unwrap();
            event(pool, dog_id, "vacina", &format!("Vacina {vaccine} aplicada em {applied}")).await;
        }
        dog_ids.insert(d.name, dog_id);
        owner_ids.insert(d.name, user_id);
    }

    // Cão antigo da Maria (removido do perfil, continua no histórico).
    let nina = sqlx::query(
        "INSERT INTO dogs (owner_id, name, breed, birth_date, sex, temperament, likes, photo_url, removed_at, created_at)
         VALUES (?, 'Nina', 'Shih Tzu', '2010-04-01', 'femea', 'calmo', 'Suéter quentinho', ?, ?, ?)",
    )
    .bind(owner_ids["Mel"])
    .bind(unsplash(PAST_DOG_PHOTO))
    .bind(days_ago(200))
    .bind(days_ago(900))
    .execute(pool)
    .await
    .unwrap()
    .last_insert_rowid();
    event(pool, nina, "cadastro", "Nina foi cadastrada no All Love").await;
    event(pool, nina, "removido", "Nina foi removida do perfil do dono").await;

    // Feed com curtidas.
    for (dog, photo, caption, ago) in POSTS {
        let post_id = sqlx::query("INSERT INTO posts (dog_id, image_url, caption, created_at) VALUES (?, ?, ?, ?)")
            .bind(dog_ids[dog])
            .bind(unsplash(photo))
            .bind(caption)
            .bind(format!("{} 10:00:00", days_ago(*ago)))
            .execute(pool)
            .await
            .unwrap()
            .last_insert_rowid();
        // cada post recebe curtidas de alguns donos (quantidade varia por post)
        for (j, liker) in owner_ids.values().enumerate() {
            if (j + caption.len()) % 3 != 0 {
                sqlx::query("INSERT OR IGNORE INTO post_likes (post_id, user_id) VALUES (?, ?)")
                    .bind(post_id)
                    .bind(liker)
                    .execute(pool)
                    .await
                    .unwrap();
            }
        }
    }

    // Encontros: Mel e Thor já combinaram; Bento e Pipoca pediram para conhecer o Thor e a Mel.
    let requests = [("Mel", "Thor", "accepted"), ("Bento", "Thor", "pending"), ("Pipoca", "Mel", "pending"), ("Luna", "Bento", "pending")];
    for (from, to, status) in requests {
        sqlx::query("INSERT INTO match_requests (from_dog_id, to_dog_id, status, responded_at) VALUES (?, ?, ?, ?)")
            .bind(dog_ids[from])
            .bind(dog_ids[to])
            .bind(status)
            .bind((status == "accepted").then(|| days_ago(2)))
            .execute(pool)
            .await
            .unwrap();
        if status == "accepted" {
            event(pool, dog_ids[from], "encontro", &format!("Combinou um encontro com {to}")).await;
            event(pool, dog_ids[to], "encontro", &format!("Combinou um encontro com {from}")).await;
        }
    }

    // Rex: um incidente já confirmado pela moderação e uma denúncia nova em aberto.
    let rex = dog_ids["Rex"];
    let carlos = owner_ids["Rex"];
    sqlx::query(
        "INSERT INTO reports (reporter_id, target_user_id, target_dog_id, reason, details, status, created_at, resolved_at)
         VALUES (?, ?, ?, 'agressividade', 'Avançou no meu cachorro na entrada do parque.', 'procedente', ?, ?)",
    )
    .bind(owner_ids["Salsicha"])
    .bind(carlos)
    .bind(rex)
    .bind(days_ago(40))
    .bind(days_ago(38))
    .execute(pool)
    .await
    .unwrap();
    event(pool, rex, "incidente", "Denúncia confirmada pela moderação: agressividade").await;
    sqlx::query(
        "INSERT INTO reports (reporter_id, target_user_id, target_dog_id, reason, details)
         VALUES (?, ?, ?, 'informacao_falsa', 'O perfil dizia que ele era calmo, mas ele mordeu a guia da Luna.')",
    )
    .bind(owner_ids["Luna"])
    .bind(carlos)
    .bind(rex)
    .execute(pool)
    .await
    .unwrap();
}

fn round5(x: f64) -> f64 {
    (x * 100_000.0).round() / 100_000.0
}

async fn event(pool: &SqlitePool, dog_id: i64, kind: &str, description: &str) {
    sqlx::query("INSERT INTO dog_events (dog_id, kind, description) VALUES (?, ?, ?)")
        .bind(dog_id)
        .bind(kind)
        .bind(description)
        .execute(pool)
        .await
        .unwrap();
}

#[cfg(test)]
mod tests {
    #[test]
    fn demo_cpfs_are_valid() {
        for i in 0..8 {
            let cpf = super::demo_cpf(&format!("{:09}", 123_456_000 + i * 7));
            assert!(crate::rules::normalize_cpf(&cpf).is_some(), "{cpf}");
        }
    }
}

// ---------------------------------------------------------------------------
// Eventos de exemplo (capas do Unsplash, créditos no README)
// ---------------------------------------------------------------------------

struct DemoEvent {
    title: &'static str,
    description: &'static str,
    kind: &'static str,
    place: &'static str,
    address: &'static str,
    lat: f64,
    lng: f64,
    in_days: u64,
    time: &'static str,
    cover: &'static str,
    contest: bool,
    entry_sex: Option<&'static str>,
    entry_breed: Option<&'static str>,
    /// cães inscritos no concurso
    entries: &'static [&'static str],
    /// (quem vota, em qual cão)
    votes: &'static [(&'static str, &'static str)],
    /// donos (pelo cão) que confirmaram ou estão em dúvida
    going: &'static [&'static str],
    maybe: &'static [&'static str],
}

const EVENTS: &[DemoEvent] = &[
    DemoEvent {
        title: "Encontrão dos Vira-latas Caramelo",
        description: "O patrimônio nacional se reúne! Caramelos, pretinhos, malhados: todo vira-lata é bem-vindo. Tem água fresca e petisco.",
        kind: "encontro", place: "Horto Florestal", address: "R. do Horto, 931", lat: -23.4597, lng: -46.6347,
        in_days: 1, time: "09:00", cover: "photo-1668757183096-bc55a8992558",
        contest: false, entry_sex: None, entry_breed: None, entries: &[], votes: &[],
        going: &["Luna", "Rex", "Thor"], maybe: &["Mel"],
    },
    DemoEvent {
        title: "Niver Coletivo dos Aniversariantes do Mês 🎂",
        description: "Bolo de patê, chapéu de festa e parabéns em uivo coletivo. Traga seu aniversariante!",
        kind: "festa", place: "Praça Pôr do Sol", address: "Praça Cel. Custódio Fernandes Pinheiro", lat: -23.5517, lng: -46.6936,
        in_days: 2, time: "16:00", cover: "photo-1579596380632-8c7aabb69148",
        contest: false, entry_sex: None, entry_breed: None, entries: &[], votes: &[],
        going: &["Pipoca", "Bento"], maybe: &["Salsicha", "Luna"],
    },
    DemoEvent {
        title: "Desfile de Cadelas: Fashion Week do Ibirapuera 💅",
        description: "Passarela, holofote e muito laço de fita. Só as divas de quatro patas desfilam; o público escolhe a rainha da passarela.",
        kind: "desfile", place: "Cachorródromo do Ibirapuera", address: "Portão 3 do Parque Ibirapuera", lat: -23.5850, lng: -46.6560,
        in_days: 3, time: "15:00", cover: "photo-1789846958815-3bc8a39c69d4",
        contest: true, entry_sex: Some("femea"), entry_breed: None,
        entries: &["Mel", "Luna", "Pipoca"],
        votes: &[("Thor", "Mel"), ("Bento", "Mel"), ("Salsicha", "Pipoca"), ("Rex", "Luna"), ("Bidu", "Mel")],
        going: &["Thor", "Bento", "Salsicha", "Bidu"], maybe: &["Rex"],
    },
    DemoEvent {
        title: "Corrida de Salsichas 🌭",
        description: "50 metros de pura emoção. Só para Dachshunds! Medalha para todos que cruzarem a linha (ou que pararem para cheirar a grama).",
        kind: "corrida", place: "Parque do Povo", address: "Av. Henrique Chamma, 420", lat: -23.5862, lng: -46.6866,
        in_days: 6, time: "10:00", cover: "photo-1602067340370-bdcebe8d1930",
        contest: true, entry_sex: None, entry_breed: Some("Dachshund"),
        entries: &["Salsicha"], votes: &[("Mel", "Salsicha"), ("Thor", "Salsicha")],
        going: &["Mel", "Pipoca"], maybe: &["Thor"],
    },
    DemoEvent {
        title: "Arraiá Cãotry 🤠",
        description: "Quadrilha, pescaria de petisco e concurso de look caipira. Chapéu de palha obrigatório (para o dono também).",
        kind: "festa", place: "Parque da Água Branca", address: "Av. Francisco Matarazzo, 455", lat: -23.5267, lng: -46.6693,
        in_days: 9, time: "17:00", cover: "photo-1792294247041-a0b6e50bf3a8",
        contest: true, entry_sex: None, entry_breed: None,
        entries: &["Bento", "Thor"], votes: &[("Luna", "Bento"), ("Mel", "Thor"), ("Pipoca", "Bento")],
        going: &["Luna", "Pipoca"], maybe: &["Mel", "Salsicha"],
    },
    DemoEvent {
        title: "Baile de Fantasia Assombrado 👻",
        description: "Fantasmas, abóboras e vampiros peludos. A fantasia mais criativa leva um ano de petiscos do Pet Shop Amigo Fiel.",
        kind: "concurso", place: "Parque Villa-Lobos", address: "Av. Prof. Fonseca Rodrigues, 2001", lat: -23.5465, lng: -46.7225,
        in_days: 13, time: "19:00", cover: "photo-1633025094151-6fc996255e28",
        contest: true, entry_sex: None, entry_breed: None,
        entries: &["Pipoca", "Rex"], votes: &[("Thor", "Pipoca")],
        going: &["Thor"], maybe: &["Bento", "Luna", "Mel"],
    },
    DemoEvent {
        title: "Feira de Adoção Patas do Bem 💙",
        description: "Mais de 30 cães esperando uma família. Vacinados, castrados e com muito amor para dar. Organização: ONG Patas do Bem.",
        kind: "adocao", place: "Parque Buenos Aires", address: "Av. Angélica, 1500", lat: -23.5469, lng: -46.6560,
        in_days: 4, time: "10:00", cover: "photo-1594004844563-536a03a6e532",
        contest: false, entry_sex: None, entry_breed: None, entries: &[], votes: &[],
        going: &["Mel", "Luna", "Salsicha"], maybe: &["Thor", "Pipoca"],
    },
    DemoEvent {
        title: "Cabo de Guerra dos Brutos 💪",
        description: "Competição de força com corda (macia!) e juiz veterinário. Categorias por peso para ninguém sair em desvantagem.",
        kind: "competicao", place: "Parque Villa-Lobos", address: "Av. Prof. Fonseca Rodrigues, 2001", lat: -23.5465, lng: -46.7225,
        in_days: 11, time: "09:30", cover: "photo-1772107900563-c7ad77ff30e1",
        contest: true, entry_sex: None, entry_breed: None,
        entries: &["Thor", "Bento"], votes: &[("Mel", "Thor"), ("Luna", "Bento"), ("Salsicha", "Thor")],
        going: &["Mel", "Salsicha"], maybe: &["Luna"],
    },
];

/// Cria os eventos de exemplo se ainda não houver nenhum e os donos de exemplo existirem.
pub async fn seed_events_if_missing(pool: &SqlitePool) {
    let (count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM events").fetch_one(pool).await.unwrap();
    if count > 0 {
        return;
    }
    // cão de exemplo -> (id do cão, id do dono)
    let rows: Vec<(String, i64, i64)> = sqlx::query_as(
        "SELECT d.name, d.id, d.owner_id FROM dogs d JOIN users u ON u.id = d.owner_id
         WHERE u.email LIKE '%@demo.local' AND d.removed_at IS NULL",
    )
    .fetch_all(pool)
    .await
    .unwrap();
    if rows.is_empty() {
        return;
    }
    let dog = |name: &str| rows.iter().find(|r| r.0 == name).map(|r| (r.1, r.2));
    let today = Local::now().date_naive();

    for e in EVENTS {
        let starts = format!("{} {}", (today + Days::new(e.in_days)).format("%Y-%m-%d"), e.time);
        let event_id = sqlx::query(
            "INSERT INTO events (title, description, kind, place_name, address, lat, lng, starts_at, cover_url,
                                 has_contest, entry_sex, entry_breed)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(e.title)
        .bind(e.description)
        .bind(e.kind)
        .bind(e.place)
        .bind(e.address)
        .bind(e.lat)
        .bind(e.lng)
        .bind(&starts)
        .bind(unsplash(e.cover))
        .bind(e.contest)
        .bind(e.entry_sex)
        .bind(e.entry_breed)
        .execute(pool)
        .await
        .unwrap()
        .last_insert_rowid();

        let rsvp = |owner: i64, status: &'static str| {
            sqlx::query("INSERT OR REPLACE INTO event_rsvps (event_id, user_id, status) VALUES (?, ?, ?)")
                .bind(event_id)
                .bind(owner)
                .bind(status)
        };
        for name in e.maybe {
            if let Some((_, owner)) = dog(name) {
                rsvp(owner, "maybe").execute(pool).await.unwrap();
            }
        }
        for name in e.going.iter().chain(e.entries) {
            if let Some((_, owner)) = dog(name) {
                rsvp(owner, "going").execute(pool).await.unwrap();
            }
        }
        for name in e.entries {
            if let Some((dog_id, _)) = dog(name) {
                sqlx::query("INSERT INTO event_entries (event_id, dog_id) VALUES (?, ?)")
                    .bind(event_id)
                    .bind(dog_id)
                    .execute(pool)
                    .await
                    .unwrap();
            }
        }
        for (voter, candidate) in e.votes {
            let (Some((_, voter)), Some((dog_id, _))) = (dog(voter), dog(candidate)) else { continue };
            sqlx::query(
                "INSERT INTO event_votes (event_id, user_id, entry_id)
                 SELECT ?, ?, id FROM event_entries WHERE event_id = ? AND dog_id = ?",
            )
            .bind(event_id)
            .bind(voter)
            .bind(event_id)
            .bind(dog_id)
            .execute(pool)
            .await
            .unwrap();
        }
    }
}

// ---------------------------------------------------------------------------
// Perfil completo dos cães, carteira digital, profissionais, loja e comentários
// ---------------------------------------------------------------------------

/// (cão, peso, cor, descrição, atividade, procura, microchip, castrado, alergias)
const DOG_DETAILS: &[(&str, f64, &str, &str, &str, &str, &str, bool, &str)] = &[
    ("Mel", 6.2, "Branca e dourada", "Princesa da casa. Adora colo e odeia chinelo voando.", "baixo", "amizade", "985112004561234", false, ""),
    ("Thor", 32.0, "Dourado", "Energia infinita, nada em qualquer poça e já trouxe 400 bolinhas este ano.", "alto", "ambos", "985112004569876", false, "Frango"),
    ("Luna", 14.5, "Caramelo malhado", "Tímida no começo, depois não larga mais.", "medio", "amizade", "", true, ""),
    ("Bento", 19.0, "Preto e branco", "Border collie de manual: precisa de tarefa, senão inventa uma.", "alto", "cruzamento", "985112004563333", false, ""),
    ("Pipoca", 8.0, "Bege", "Ronca alto, dorme mais alto ainda.", "baixo", "cruzamento", "", false, "Grãos"),
    ("Salsicha", 7.5, "Marrom", "Pequeno no tamanho, gigante na coragem (menos com escadas).", "medio", "amizade", "", true, ""),
    ("Bidu", 12.0, "Preto", "Comediante oficial do parque.", "medio", "ambos", "", false, ""),
    ("Rex", 28.0, "Preto e caramelo", "Guardião. Precisa de apresentação calma a outros machos.", "medio", "amizade", "", true, ""),
];

/// (nome, tipo, descrição, serviços, telefone, endereço, deslocamento lat/lng, verificado)
const PROVIDERS: &[(&str, &str, &str, &str, &str, &str, (f64, f64), bool)] = &[
    ("Clínica Vet Bem-Estar", "veterinario", "Clínica 24h com especialistas em cães.",
     "Consulta, Vacinação, Exames, Castração, Acompanhamento de cruzamento", "1133330001", "R. Domingos de Morais, 1200", (0.004, 0.002), true),
    ("Hospital Veterinário Patinhas", "veterinario", "Pronto-socorro e cirurgia.",
     "Consulta, Emergência, Cirurgia, Raio-X", "1133330002", "Av. Ibirapuera, 2500", (-0.006, -0.004), true),
    ("Canil Vale Dourado", "criador", "Criador registrado de Golden Retriever com pedigree CBKC.",
     "Filhotes com pedigree, Verificação de pedigree, Orientação de cruzamento", "1133330003", "Estrada do Vale, 300", (0.03, 0.02), true),
    ("Adestra Já – Carla", "adestrador", "Adestramento positivo, sem punição.",
     "Obediência básica, Correção de comportamento, Socialização", "11988880004", "Atende em domicílio", (0.002, -0.003), true),
    ("Passeios do Lucas", "passeador", "Passeios em grupo de até 4 cães no Ibirapuera.",
     "Passeio 30 min, Passeio 1 h, Pet sitter", "11988880005", "Vila Mariana", (-0.001, 0.001), false),
    ("Hotelzinho Late Late", "hotel", "Hospedagem com câmera ao vivo e quintal gramado.",
     "Diária, Creche, Hospedagem de fim de semana", "1133330006", "R. Vergueiro, 3000", (0.008, -0.002), true),
    ("Pet Shop Amigo Fiel", "pet_shop", "Banho, tosa e tudo para o seu cão.",
     "Banho, Tosa, Hidratação, Corte de unhas", "1133330007", "R. Sena Madureira, 500", (0.003, 0.004), true),
    ("ONG Patas do Bem", "adocao", "Resgate, castração e adoção responsável.",
     "Adoção, Lar temporário, Doações", "11988880008", "Parque Buenos Aires (feiras mensais)", (0.04, 0.001), true),
];

/// (pet shop, nome, categoria, descrição, preço em centavos, foto)
const PRODUCTS: &[(&str, &str, &str, &str, i64, Option<&str>)] = &[
    ("Pet Shop Amigo Fiel", "Capa de chuva Pata Seca", "roupas", "Impermeável, com refletivo para passeios à noite.", 8990, Some("photo-1740235475083-e17e5352f62f")),
    ("Pet Shop Amigo Fiel", "Peitoral Passeio Feliz", "acessorios", "Acolchoado, não aperta o pescoço.", 6990, Some("photo-1773086727839-8d9180b510fc")),
    ("Pet Shop Amigo Fiel", "Kit brinquedos que apitam", "brinquedos", "3 brinquedos de borracha atóxica.", 3990, Some("photo-1580597095981-8d21aa8cdfed")),
    ("Pet Shop Amigo Fiel", "Ração Patinha Feliz Adulto 10 kg", "alimentos", "Sem corantes, com ômega 3.", 18990, None),
    ("Pet Shop Amigo Fiel", "Shampoo pelagem clara", "higiene", "Para cães brancos e dourados.", 2990, None),
    ("Pet Shop Amigo Fiel", "Bandana All Love", "roupas", "Azul e amarela, as cores que o cão enxerga.", 2490, None),
    ("Pet Shop Amigo Fiel", "Petisco natural de batata-doce", "alimentos", "Desidratado, sem conservantes.", 1990, None),
];

/// (cão do post, autor pelo cão dele, texto)
const COMMENTS: &[(&str, &str, &str)] = &[
    ("Thor", "Mel", "A bolinha azul é a melhor amiga dele 😂"),
    ("Thor", "Bento", "Bora jogar bolinha no sábado?"),
    ("Pipoca", "Luna", "Que soninho gostoso!"),
    ("Pipoca", "Thor", "Esse ronco eu ouço daqui 🤣"),
    ("Mel", "Salsicha", "Cheirosa demais!"),
    ("Bidu", "Rex", "Outono é a estação dele"),
];

pub async fn seed_extras_if_missing(pool: &SqlitePool) {
    let (count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM providers").fetch_one(pool).await.unwrap();
    if count > 0 {
        return;
    }
    let rows: Vec<(String, i64, i64)> = sqlx::query_as(
        "SELECT d.name, d.id, d.owner_id FROM dogs d JOIN users u ON u.id = d.owner_id
         WHERE u.email LIKE '%@demo.local' AND d.removed_at IS NULL",
    )
    .fetch_all(pool)
    .await
    .unwrap();
    let dog = |name: &str| rows.iter().find(|r| r.0 == name).map(|r| (r.1, r.2));

    for (name, weight, color, bio, activity, looking, chip, neutered, allergies) in DOG_DETAILS {
        if let Some((id, _)) = dog(name) {
            sqlx::query(
                "UPDATE dogs SET weight_kg = ?, color = ?, bio = ?, activity_level = ?, looking_for = ?, microchip = ?,
                 neutered = ?, allergies = ? WHERE id = ?",
            )
            .bind(weight)
            .bind(color)
            .bind(bio)
            .bind(activity)
            .bind(looking)
            .bind(chip)
            .bind(neutered)
            .bind(allergies)
            .bind(id)
            .execute(pool)
            .await
            .unwrap();
        }
    }

    // Pedigrees: o do Thor já verificado, o do Bento esperando a moderação.
    let upload_dir = std::env::var("UPLOAD_DIR").unwrap_or_else(|_| "uploads".into());
    let pdf = b"%PDF-1.1\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 120]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj 4 0 obj<</Length 52>>stream\nBT /F1 14 Tf 20 60 Td (Pedigree de exemplo - All Love) Tj ET\nendstream endobj 5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF";
    let _ = std::fs::create_dir_all(&upload_dir);
    let _ = std::fs::write(std::path::Path::new(&upload_dir).join("exemplo-pedigree.pdf"), pdf);
    for (name, status) in [("Thor", "verificado"), ("Bento", "enviado")] {
        if let Some((id, _)) = dog(name) {
            sqlx::query("INSERT INTO dog_documents (dog_id, kind, title, file_url, status) VALUES (?, 'pedigree', ?, '/uploads/exemplo-pedigree.pdf', ?)")
                .bind(id)
                .bind(format!("Pedigree CBKC de {name}"))
                .bind(status)
                .execute(pool)
                .await
                .unwrap();
        }
    }
    if let Some((id, _)) = dog("Thor") {
        sqlx::query("INSERT INTO dog_documents (dog_id, kind, title, file_url) VALUES (?, 'exame', 'Hemograma 2026', '/uploads/exemplo-pedigree.pdf')")
            .bind(id)
            .execute(pool)
            .await
            .unwrap();
    }

    for (name, kind, desc, services, phone, address, (dlat, dlng), verified) in PROVIDERS {
        sqlx::query(
            "INSERT INTO providers (name, kind, description, services, phone, address, lat, lng, verified)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(name)
        .bind(kind)
        .bind(desc)
        .bind(services)
        .bind(phone)
        .bind(address)
        .bind(round5(IBIRAPUERA.0 + dlat))
        .bind(round5(IBIRAPUERA.1 + dlng))
        .bind(verified)
        .execute(pool)
        .await
        .unwrap();
    }
    for (shop, name, category, desc, price, photo) in PRODUCTS {
        sqlx::query(
            "INSERT INTO products (provider_id, name, category, description, price_cents, photo_url, link)
             SELECT id, ?, ?, ?, ?, ?, '' FROM providers WHERE name = ?",
        )
        .bind(name)
        .bind(category)
        .bind(desc)
        .bind(price)
        .bind(photo.map(unsplash))
        .bind(shop)
        .execute(pool)
        .await
        .unwrap();
    }

    // Um agendamento de exemplo para o João.
    if let Some((thor, joao)) = dog("Thor") {
        let when = format!("{} 14:30", (Local::now().date_naive() + Days::new(5)).format("%Y-%m-%d"));
        sqlx::query(
            "INSERT INTO appointments (provider_id, user_id, dog_id, service, date_time, notes, status)
             SELECT id, ?, ?, 'Vacinação', ?, 'Reforço da V10', 'confirmado' FROM providers WHERE name = 'Clínica Vet Bem-Estar'",
        )
        .bind(joao)
        .bind(thor)
        .bind(when)
        .execute(pool)
        .await
        .unwrap();
    }

    for (post_dog, author_dog, text) in COMMENTS {
        let (Some((post_dog_id, _)), Some((_, author))) = (dog(post_dog), dog(author_dog)) else { continue };
        sqlx::query(
            "INSERT INTO post_comments (post_id, user_id, text)
             SELECT id, ?, ? FROM posts WHERE dog_id = ? ORDER BY id LIMIT 1",
        )
        .bind(author)
        .bind(text)
        .bind(post_dog_id)
        .execute(pool)
        .await
        .unwrap();
    }
}
