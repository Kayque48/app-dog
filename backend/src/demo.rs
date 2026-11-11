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
