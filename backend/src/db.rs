//! Conexão com o SQLite, migrações e dados iniciais.

use std::str::FromStr;

use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions},
    SqlitePool,
};

use crate::auth::hash_password;

pub async fn connect(url: &str) -> SqlitePool {
    let options = SqliteConnectOptions::from_str(url)
        .expect("DATABASE_URL inválida")
        .create_if_missing(true)
        .journal_mode(SqliteJournalMode::Wal)
        .foreign_keys(true);
    let pool = SqlitePoolOptions::new()
        .max_connections(8)
        .connect_with(options)
        .await
        .expect("não foi possível abrir o banco");
    sqlx::migrate!("./migrations").run(&pool).await.expect("falha nas migrações");
    pool
}

/// Cria o administrador, os parques/pontos de encontro e os anúncios.
/// Com `SEED_DEMO=1` (padrão) também cria donos e cães de exemplo perto do Ibirapuera,
/// para o Descobrir ter alguém para mostrar durante as aulas.
pub async fn seed(pool: &SqlitePool) {
    let admin_email = std::env::var("ADMIN_EMAIL").unwrap_or_else(|_| "admin@alllove.local".into());
    let admin_password = std::env::var("ADMIN_PASSWORD").unwrap_or_else(|_| "admin123".into());

    let exists: Option<(i64,)> = sqlx::query_as("SELECT id FROM users WHERE email = ?")
        .bind(&admin_email)
        .fetch_optional(pool)
        .await
        .unwrap();
    if exists.is_some() {
        return; // já foi semeado
    }

    sqlx::query(
        "INSERT INTO users (name, email, password_hash, phone, cep, city, address, is_admin)
         VALUES ('Moderação All Love', ?, ?, '11999999999', '01310100', 'São Paulo', 'Av. Paulista', 1)",
    )
    .bind(&admin_email)
    .bind(hash_password(&admin_password))
    .execute(pool)
    .await
    .unwrap();

    let places = [
        ("Parque Ibirapuera", "parque", "Av. Pedro Álvares Cabral - Vila Mariana", -23.5874, -46.6576),
        ("Horto Florestal (Parque Alberto Löfgren)", "parque", "R. do Horto, 931 - Horto Florestal", -23.4597, -46.6347),
        ("Parque Villa-Lobos", "parque", "Av. Prof. Fonseca Rodrigues, 2001 - Alto de Pinheiros", -23.5465, -46.7225),
        ("Parque da Água Branca", "parque", "Av. Francisco Matarazzo, 455 - Água Branca", -23.5267, -46.6693),
        ("Parque do Povo", "parque", "Av. Henrique Chamma, 420 - Itaim Bibi", -23.5862, -46.6866),
        ("Praça Pôr do Sol", "praca", "Praça Cel. Custódio Fernandes Pinheiro - Pinheiros", -23.5517, -46.6936),
        ("Cachorródromo do Ibirapuera", "ponto_encontro", "Portão 3 do Parque Ibirapuera", -23.5850, -46.6560),
        ("Parque Buenos Aires", "parque", "Av. Angélica, 1500 - Higienópolis", -23.5469, -46.6560),
    ];
    for (name, kind, address, lat, lng) in places {
        sqlx::query("INSERT INTO places (name, kind, address, lat, lng) VALUES (?, ?, ?, ?, ?)")
            .bind(name)
            .bind(kind)
            .bind(address)
            .bind(lat)
            .bind(lng)
            .execute(pool)
            .await
            .unwrap();
    }

    let ads = [
        ("Pet Shop Amigo Fiel", "Banho e tosa com 15% de desconto para quem usa o All Love!", ""),
        ("Ração Patinha Feliz", "Frete grátis na primeira compra.", ""),
        ("Clínica Vet Bem-Estar", "Vacina em dia? Agende a sua com a gente.", ""),
    ];
    for (sponsor, message, link) in ads {
        sqlx::query("INSERT INTO ads (sponsor, message, link) VALUES (?, ?, ?)")
            .bind(sponsor)
            .bind(message)
            .bind(link)
            .execute(pool)
            .await
            .unwrap();
    }

    if std::env::var("SEED_DEMO").map(|v| v != "0").unwrap_or(true) {
        seed_demo(pool).await;
    }
    tracing::info!("dados iniciais criados (admin: {admin_email})");
}

async fn seed_demo(pool: &SqlitePool) {
    let today = chrono::Local::now().date_naive();
    let next_year = (today + chrono::Days::new(300)).format("%Y-%m-%d").to_string();
    let applied = (today - chrono::Days::new(60)).format("%Y-%m-%d").to_string();

    // (dono, e-mail, cpf, lat, lng, cão, raça, nascimento, sexo, cio, temperamento, morde, gosta, não gosta)
    let demo = [
        ("Maria Souza", "maria@demo.local", "52998224725", -23.5868, -46.6570,
         "Mel", "Shih Tzu", "2021-03-15", "femea", false, "calmo", false, "Dormir no sofá, petiscos", "Chinelo, barulho de moto"),
        ("João Lima", "joao@demo.local", "16899535009", -23.5880, -46.6590,
         "Thor", "Golden Retriever", "2019-08-02", "macho", false, "brincalhao", false, "Morder bolinha, nadar", "Ficar sozinho"),
        ("Ana Costa", "ana@demo.local", "71428793860", -23.5859, -46.6555,
         "Luna", "Vira-lata", "2022-11-20", "femea", true, "timido", false, "Passear de manhã", "Cachorros grandes"),
    ];
    for (owner, email, cpf, lat, lng, dog, breed, birth, sex, heat, temp, bites, likes, dislikes) in demo {
        let user_id = sqlx::query(
            "INSERT INTO users (name, email, password_hash, phone, cpf, cep, city, address, lat, lng)
             VALUES (?, ?, ?, '11988887777', ?, '04094050', 'São Paulo', 'Vila Mariana', ?, ?)",
        )
        .bind(owner)
        .bind(email)
        .bind(hash_password("demo1234"))
        .bind(cpf)
        .bind(lat)
        .bind(lng)
        .execute(pool)
        .await
        .unwrap()
        .last_insert_rowid();

        let dog_id = sqlx::query(
            "INSERT INTO dogs (owner_id, name, breed, birth_date, sex, in_heat, temperament, bites, likes, dislikes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(user_id)
        .bind(dog)
        .bind(breed)
        .bind(birth)
        .bind(sex)
        .bind(heat)
        .bind(temp)
        .bind(bites)
        .bind(likes)
        .bind(dislikes)
        .execute(pool)
        .await
        .unwrap()
        .last_insert_rowid();

        for vaccine in ["V10", "Antirrábica"] {
            sqlx::query("INSERT INTO vaccines (dog_id, name, applied_on, next_due) VALUES (?, ?, ?, ?)")
                .bind(dog_id)
                .bind(vaccine)
                .bind(&applied)
                .bind(&next_year)
                .execute(pool)
                .await
                .unwrap();
        }
        sqlx::query("INSERT INTO dog_events (dog_id, kind, description) VALUES (?, 'cadastro', ?)")
            .bind(dog_id)
            .bind(format!("{dog} foi cadastrado no All Love"))
            .execute(pool)
            .await
            .unwrap();
    }
}
