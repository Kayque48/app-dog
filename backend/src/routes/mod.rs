mod discover;
mod dogs;
mod feed;
mod moderation;
mod places;
mod users;

use axum::{
    routing::{delete, get, post, put},
    Router,
};
use serde::Serialize;
use sqlx::{FromRow, SqlitePool};

use crate::{
    error::{AppError, AppResult},
    rules::{self, VaccineRecord, VaccineStatus},
    AppState,
};

pub fn router() -> Router<AppState> {
    Router::new()
        // conta
        .route("/auth/register", post(users::register))
        .route("/auth/login", post(users::login))
        .route("/auth/logout", post(users::logout))
        .route("/me", get(users::me).put(users::update_me).delete(users::delete_me))
        .route("/me/location", put(users::update_location))
        .route("/me/premium", put(users::set_premium))
        .route("/users/{id}", get(users::public_profile))
        // cães
        .route("/dogs/mine", get(dogs::my_dogs))
        .route("/dogs", post(dogs::create))
        .route("/dogs/{id}", get(dogs::profile).put(dogs::update).delete(dogs::remove))
        .route("/dogs/{id}/vaccines", get(dogs::list_vaccines).post(dogs::add_vaccine))
        .route("/vaccines/{id}", delete(dogs::delete_vaccine))
        // feed
        .route("/uploads", post(feed::upload))
        .route("/feed", get(feed::feed))
        .route("/posts", post(feed::create_post))
        .route("/posts/{id}", delete(feed::delete_post))
        .route("/posts/{id}/like", post(feed::toggle_like))
        // descobrir / encontros
        .route("/discover", get(discover::discover))
        .route("/swipes", post(discover::swipe))
        .route("/matches", get(discover::matches))
        .route("/matches/{id}/respond", post(discover::respond))
        // locais e anúncios
        .route("/places", get(places::nearby).post(places::create))
        .route("/ads/random", get(places::random_ad))
        // denúncias e moderação
        .route("/reports", post(moderation::create_report))
        .route("/admin/reports", get(moderation::list_reports))
        .route("/admin/reports/{id}/resolve", post(moderation::resolve_report))
        .route("/admin/users", get(moderation::list_users))
        .route("/admin/users/{id}/ban", post(moderation::ban_user))
}

// ---------- tipos e funções compartilhados pelas rotas ----------

#[derive(Debug, Clone, FromRow, Serialize)]
pub struct DogRow {
    pub id: i64,
    pub owner_id: i64,
    pub name: String,
    pub breed: String,
    pub birth_date: String,
    pub sex: String,
    pub in_heat: bool,
    pub temperament: String,
    pub bites: bool,
    pub likes: String,
    pub dislikes: String,
    pub photo_url: Option<String>,
    pub removed_at: Option<String>,
    pub created_at: String,
}

pub const DOG_COLUMNS: &str = "d.id, d.owner_id, d.name, d.breed, d.birth_date, d.sex, d.in_heat, d.temperament, \
     d.bites, d.likes, d.dislikes, d.photo_url, d.removed_at, d.created_at";

/// Cão como é enviado para os apps: dados + idade + situação vacinal.
#[derive(Serialize)]
pub struct DogView {
    #[serde(flatten)]
    pub dog: DogRow,
    pub age_years: i64,
    pub vaccine_status: VaccineStatus,
}

pub fn today() -> chrono::NaiveDate {
    chrono::Local::now().date_naive()
}

pub async fn dog_view(db: &SqlitePool, dog: DogRow) -> AppResult<DogView> {
    let vaccine_status = vaccine_status_of(db, dog.id).await?;
    let age_years = rules::parse_date(&dog.birth_date)
        .map(|b| rules::age_years(b, today()))
        .unwrap_or(0);
    Ok(DogView { dog, age_years, vaccine_status })
}

pub async fn vaccine_status_of(db: &SqlitePool, dog_id: i64) -> AppResult<VaccineStatus> {
    let rows: Vec<(String, String, Option<String>)> =
        sqlx::query_as("SELECT name, applied_on, next_due FROM vaccines WHERE dog_id = ?")
            .bind(dog_id)
            .fetch_all(db)
            .await?;
    let records: Vec<VaccineRecord> = rows
        .iter()
        .map(|(name, applied_on, next_due)| VaccineRecord {
            name,
            applied_on,
            next_due: next_due.as_deref(),
        })
        .collect();
    Ok(rules::vaccine_status(&records, today()))
}

pub async fn find_dog(db: &SqlitePool, id: i64) -> AppResult<DogRow> {
    sqlx::query_as(&format!("SELECT {DOG_COLUMNS} FROM dogs d WHERE d.id = ?"))
        .bind(id)
        .fetch_optional(db)
        .await?
        .ok_or_else(|| AppError::not_found("Cão não encontrado"))
}

/// Busca um cão ativo que pertence ao usuário logado.
pub async fn find_own_dog(db: &SqlitePool, id: i64, owner_id: i64) -> AppResult<DogRow> {
    let dog = find_dog(db, id).await?;
    if dog.owner_id != owner_id || dog.removed_at.is_some() {
        return Err(AppError::forbidden("Este cão não é seu"));
    }
    Ok(dog)
}

pub async fn add_event(db: &SqlitePool, dog_id: i64, kind: &str, description: &str) -> AppResult<()> {
    sqlx::query("INSERT INTO dog_events (dog_id, kind, description) VALUES (?, ?, ?)")
        .bind(dog_id)
        .bind(kind)
        .bind(description)
        .execute(db)
        .await?;
    Ok(())
}

/// Primeiro nome do dono: é o único dado pessoal mostrado para outros usuários.
pub fn first_name(name: &str) -> String {
    name.split_whitespace().next().unwrap_or("").to_string()
}

pub fn required(value: &str, field: &str) -> AppResult<String> {
    let v = value.trim();
    if v.is_empty() {
        return Err(AppError::bad(format!("O campo \"{field}\" é obrigatório")));
    }
    Ok(v.to_string())
}
