//! Profissionais e estabelecimentos pet (veterinários, criadores, adestradores...),
//! agendamentos e a loja (catálogo dos pet shops parceiros).

use axum::{
    extract::{Path, Query, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;

use super::{find_own_dog, required};
use crate::{
    auth::{AdminUser, AuthUser},
    error::{AppError, AppResult},
    rules, AppState,
};

pub const PROVIDER_KINDS: &[&str] =
    &["veterinario", "criador", "adestrador", "passeador", "hotel", "banho_tosa", "adocao", "pet_shop"];
pub const PRODUCT_CATEGORIES: &[&str] = &["roupas", "alimentos", "brinquedos", "acessorios", "higiene"];

#[derive(FromRow, Serialize)]
pub struct ProviderRow {
    id: i64,
    name: String,
    kind: String,
    description: String,
    services: String,
    phone: String,
    address: String,
    lat: f64,
    lng: f64,
    photo_url: Option<String>,
    verified: bool,
    #[sqlx(skip)]
    distance_m: Option<i64>,
}

const PROVIDER_COLUMNS: &str = "id, name, kind, description, services, phone, address, lat, lng, photo_url, verified";

#[derive(Deserialize)]
pub struct ProvidersQuery {
    kind: Option<String>,
}

/// Lista de profissionais, do mais perto para o mais longe.
pub async fn list(State(state): State<AppState>, user: AuthUser, Query(q): Query<ProvidersQuery>) -> AppResult<Json<Vec<ProviderRow>>> {
    let mut rows: Vec<ProviderRow> = match q.kind.filter(|k| !k.is_empty()) {
        Some(k) => sqlx::query_as(&format!("SELECT {PROVIDER_COLUMNS} FROM providers WHERE kind = ?"))
            .bind(k)
            .fetch_all(&state.db)
            .await?,
        None => sqlx::query_as(&format!("SELECT {PROVIDER_COLUMNS} FROM providers")).fetch_all(&state.db).await?,
    };
    if let (Some(lat), Some(lng)) = (user.lat, user.lng) {
        for p in &mut rows {
            p.distance_m = Some(rules::distance_m(lat, lng, p.lat, p.lng).round() as i64);
        }
        rows.sort_by_key(|p| p.distance_m);
    }
    Ok(Json(rows))
}

pub async fn detail(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let mut p: ProviderRow = sqlx::query_as(&format!("SELECT {PROVIDER_COLUMNS} FROM providers WHERE id = ?"))
        .bind(id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| AppError::not_found("Estabelecimento não encontrado"))?;
    if let (Some(lat), Some(lng)) = (user.lat, user.lng) {
        p.distance_m = Some(rules::distance_m(lat, lng, p.lat, p.lng).round() as i64);
    }
    let products: Vec<ProductRow> = sqlx::query_as(&format!("{PRODUCT_SELECT} WHERE p.provider_id = ? ORDER BY p.id"))
        .bind(id)
        .fetch_all(&state.db)
        .await?;
    Ok(Json(json!({ "provider": p, "products": products })))
}

#[derive(Deserialize)]
pub struct ProviderInput {
    name: String,
    kind: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    services: String,
    phone: String,
    #[serde(default)]
    address: String,
    lat: f64,
    lng: f64,
    photo_url: Option<String>,
}

/// Cadastro de profissional ou estabelecimento. Começa sem o selo de verificado.
pub async fn create(State(state): State<AppState>, user: AuthUser, Json(input): Json<ProviderInput>) -> AppResult<Json<Value>> {
    if !PROVIDER_KINDS.contains(&input.kind.as_str()) {
        return Err(AppError::bad(format!("Tipo inválido. Use: {}", PROVIDER_KINDS.join(", "))));
    }
    let phone = rules::normalize_phone(&input.phone).ok_or_else(|| AppError::bad("Telefone inválido (use DDD + número)"))?;
    let id = sqlx::query(
        "INSERT INTO providers (owner_id, name, kind, description, services, phone, address, lat, lng, photo_url)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(user.id)
    .bind(required(&input.name, "nome")?)
    .bind(&input.kind)
    .bind(input.description.trim())
    .bind(input.services.trim())
    .bind(phone)
    .bind(input.address.trim())
    .bind(input.lat)
    .bind(input.lng)
    .bind(&input.photo_url)
    .execute(&state.db)
    .await?
    .last_insert_rowid();
    Ok(Json(json!({ "id": id, "message": "Cadastro enviado! A moderação vai verificar e liberar o selo." })))
}

pub async fn verify(State(state): State<AppState>, _admin: AdminUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    sqlx::query("UPDATE providers SET verified = 1 WHERE id = ?").bind(id).execute(&state.db).await?;
    Ok(Json(json!({ "ok": true })))
}

// ---------- agendamentos ----------

#[derive(Deserialize)]
pub struct AppointmentInput {
    provider_id: i64,
    dog_id: i64,
    service: String,
    date_time: String,
    #[serde(default)]
    notes: String,
}

pub async fn book(State(state): State<AppState>, user: AuthUser, Json(input): Json<AppointmentInput>) -> AppResult<Json<Value>> {
    let dog = find_own_dog(&state.db, input.dog_id, user.id).await?;
    let provider: Option<(String,)> = sqlx::query_as("SELECT name FROM providers WHERE id = ?")
        .bind(input.provider_id)
        .fetch_optional(&state.db)
        .await?;
    let (provider_name,) = provider.ok_or_else(|| AppError::not_found("Estabelecimento não encontrado"))?;
    let when = chrono::NaiveDateTime::parse_from_str(&input.date_time.replace('T', " "), "%Y-%m-%d %H:%M")
        .map_err(|_| AppError::bad("Data e hora inválidas (use AAAA-MM-DD HH:MM)"))?;
    if when < chrono::Local::now().naive_local() {
        return Err(AppError::bad("Escolha um horário no futuro"));
    }
    let service = required(&input.service, "serviço")?;
    sqlx::query("INSERT INTO appointments (provider_id, user_id, dog_id, service, date_time, notes) VALUES (?, ?, ?, ?, ?, ?)")
        .bind(input.provider_id)
        .bind(user.id)
        .bind(dog.id)
        .bind(&service)
        .bind(when.format("%Y-%m-%d %H:%M").to_string())
        .bind(input.notes.trim())
        .execute(&state.db)
        .await?;
    super::add_event(&state.db, dog.id, "agendamento", &format!("{service} agendado em {provider_name}")).await?;
    Ok(Json(json!({ "ok": true, "message": format!("Pedido enviado! {provider_name} vai confirmar pelo telefone.") })))
}

#[derive(FromRow, Serialize)]
pub struct AppointmentRow {
    id: i64,
    service: String,
    date_time: String,
    notes: String,
    status: String,
    provider_id: i64,
    provider_name: String,
    provider_phone: String,
    dog_id: i64,
    dog_name: String,
}

pub async fn my_appointments(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Vec<AppointmentRow>>> {
    let rows = sqlx::query_as(
        "SELECT a.id, a.service, a.date_time, a.notes, a.status, p.id AS provider_id, p.name AS provider_name,
                p.phone AS provider_phone, d.id AS dog_id, d.name AS dog_name
         FROM appointments a JOIN providers p ON p.id = a.provider_id JOIN dogs d ON d.id = a.dog_id
         WHERE a.user_id = ? ORDER BY a.date_time DESC",
    )
    .bind(user.id)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

pub async fn cancel(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let done = sqlx::query("UPDATE appointments SET status = 'cancelado' WHERE id = ? AND user_id = ? AND status != 'cancelado'")
        .bind(id)
        .bind(user.id)
        .execute(&state.db)
        .await?
        .rows_affected();
    if done == 0 {
        return Err(AppError::not_found("Agendamento não encontrado"));
    }
    Ok(Json(json!({ "ok": true })))
}

// ---------- loja ----------

#[derive(FromRow, Serialize)]
pub struct ProductRow {
    id: i64,
    name: String,
    category: String,
    description: String,
    price_cents: i64,
    photo_url: Option<String>,
    link: String,
    provider_id: Option<i64>,
    provider_name: Option<String>,
    provider_phone: Option<String>,
}

const PRODUCT_SELECT: &str = "SELECT p.id, p.name, p.category, p.description, p.price_cents, p.photo_url, p.link,
        p.provider_id, s.name AS provider_name, s.phone AS provider_phone
     FROM products p LEFT JOIN providers s ON s.id = p.provider_id";

#[derive(Deserialize)]
pub struct ProductsQuery {
    category: Option<String>,
}

/// Catálogo da loja. A compra é feita direto com o pet shop (WhatsApp ou site).
pub async fn products(
    State(state): State<AppState>,
    _user: AuthUser,
    Query(q): Query<ProductsQuery>,
) -> AppResult<Json<Vec<ProductRow>>> {
    let rows = match q.category.filter(|c| !c.is_empty()) {
        Some(c) if PRODUCT_CATEGORIES.contains(&c.as_str()) => {
            sqlx::query_as(&format!("{PRODUCT_SELECT} WHERE p.category = ? ORDER BY p.id"))
                .bind(c)
                .fetch_all(&state.db)
                .await?
        }
        Some(_) => return Err(AppError::bad(format!("Categoria inválida. Use: {}", PRODUCT_CATEGORIES.join(", ")))),
        None => sqlx::query_as(&format!("{PRODUCT_SELECT} ORDER BY p.id")).fetch_all(&state.db).await?,
    };
    Ok(Json(rows))
}
