use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;

use super::{first_name, required, today};
use crate::{
    auth::{create_session, hash_password, verify_password, AuthUser},
    error::{AppError, AppResult},
    rules, AppState,
};

#[derive(Debug, FromRow, Serialize)]
pub struct Me {
    pub id: i64,
    pub name: String,
    pub email: String,
    pub phone: String,
    pub cpf: Option<String>,
    pub cep: String,
    pub city: String,
    pub address: String,
    pub lat: Option<f64>,
    pub lng: Option<f64>,
    pub is_admin: bool,
    pub is_premium: bool,
    pub created_at: String,
}

const ME_COLUMNS: &str =
    "id, name, email, phone, cpf, cep, city, address, lat, lng, is_admin, is_premium, created_at";

async fn load_me(state: &AppState, id: i64) -> AppResult<Me> {
    Ok(sqlx::query_as(&format!("SELECT {ME_COLUMNS} FROM users WHERE id = ?"))
        .bind(id)
        .fetch_one(&state.db)
        .await?)
}

#[derive(Deserialize)]
pub struct RegisterInput {
    name: String,
    email: String,
    password: String,
    phone: String,
    cpf: String,
    cep: String,
    city: String,
    address: String,
    /// Consentimento com os termos e a política de privacidade (LGPD).
    accepted_terms: bool,
}

pub async fn register(State(state): State<AppState>, Json(input): Json<RegisterInput>) -> AppResult<Json<Value>> {
    if !input.accepted_terms {
        return Err(AppError::bad("É preciso aceitar os termos de uso e a política de privacidade"));
    }
    let name = required(&input.name, "nome")?;
    let email = required(&input.email, "e-mail")?.to_lowercase();
    if !email.contains('@') {
        return Err(AppError::bad("E-mail inválido"));
    }
    if input.password.len() < 6 {
        return Err(AppError::bad("A senha precisa ter pelo menos 6 caracteres"));
    }
    let cpf = rules::normalize_cpf(&input.cpf).ok_or_else(|| AppError::bad("CPF inválido"))?;
    let phone = rules::normalize_phone(&input.phone)
        .ok_or_else(|| AppError::bad("Telefone inválido (use DDD + número)"))?;
    let cep = rules::normalize_cep(&input.cep).ok_or_else(|| AppError::bad("CEP inválido"))?;
    let city = required(&input.city, "cidade")?;
    let address = required(&input.address, "endereço")?;

    let taken: Option<(Option<String>,)> = sqlx::query_as("SELECT banned_at FROM users WHERE cpf = ? OR email = ?")
        .bind(&cpf)
        .bind(&email)
        .fetch_optional(&state.db)
        .await?;
    if let Some((banned,)) = taken {
        return Err(if banned.is_some() {
            AppError::forbidden("Este CPF está bloqueado no All Love")
        } else {
            AppError::Conflict("CPF ou e-mail já cadastrado".into())
        });
    }

    let id = sqlx::query(
        "INSERT INTO users (name, email, password_hash, phone, cpf, cep, city, address)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(name)
    .bind(email)
    .bind(hash_password(&input.password))
    .bind(phone)
    .bind(cpf)
    .bind(cep)
    .bind(city)
    .bind(address)
    .execute(&state.db)
    .await?
    .last_insert_rowid();

    let token = create_session(&state, id).await?;
    Ok(Json(json!({ "token": token, "user": load_me(&state, id).await? })))
}

#[derive(Deserialize)]
pub struct LoginInput {
    email: String,
    password: String,
}

pub async fn login(State(state): State<AppState>, Json(input): Json<LoginInput>) -> AppResult<Json<Value>> {
    let row: Option<(i64, String, Option<String>, Option<String>)> = sqlx::query_as(
        "SELECT id, password_hash, banned_at, ban_reason FROM users WHERE email = ? AND deleted_at IS NULL",
    )
    .bind(input.email.trim().to_lowercase())
    .fetch_optional(&state.db)
    .await?;

    let Some((id, _, banned, reason)) = row.filter(|r| verify_password(&input.password, &r.1)) else {
        return Err(AppError::Unauthorized("E-mail ou senha incorretos".into()));
    };
    if banned.is_some() {
        return Err(AppError::forbidden(format!(
            "Conta bloqueada permanentemente. Motivo: {}",
            reason.unwrap_or_default()
        )));
    }
    let token = create_session(&state, id).await?;
    Ok(Json(json!({ "token": token, "user": load_me(&state, id).await? })))
}

pub async fn logout(State(state): State<AppState>, headers: HeaderMap) -> AppResult<Json<Value>> {
    if let Some(token) = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
    {
        sqlx::query("DELETE FROM sessions WHERE token = ?").bind(token).execute(&state.db).await?;
    }
    Ok(Json(json!({ "ok": true })))
}

pub async fn me(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Me>> {
    Ok(Json(load_me(&state, user.id).await?))
}

#[derive(Deserialize)]
pub struct UpdateMeInput {
    name: String,
    phone: String,
    cep: String,
    city: String,
    address: String,
}

pub async fn update_me(
    State(state): State<AppState>,
    user: AuthUser,
    Json(input): Json<UpdateMeInput>,
) -> AppResult<Json<Me>> {
    let phone = rules::normalize_phone(&input.phone).ok_or_else(|| AppError::bad("Telefone inválido"))?;
    let cep = rules::normalize_cep(&input.cep).ok_or_else(|| AppError::bad("CEP inválido"))?;
    sqlx::query("UPDATE users SET name = ?, phone = ?, cep = ?, city = ?, address = ? WHERE id = ?")
        .bind(required(&input.name, "nome")?)
        .bind(phone)
        .bind(cep)
        .bind(required(&input.city, "cidade")?)
        .bind(required(&input.address, "endereço")?)
        .bind(user.id)
        .execute(&state.db)
        .await?;
    Ok(Json(load_me(&state, user.id).await?))
}

#[derive(Deserialize)]
pub struct LocationInput {
    lat: f64,
    lng: f64,
}

/// Os apps enviam a localização atual do dono. Ela nunca é mostrada para
/// outros usuários: o Descobrir só mostra a distância aproximada.
pub async fn update_location(
    State(state): State<AppState>,
    user: AuthUser,
    Json(input): Json<LocationInput>,
) -> AppResult<Json<Value>> {
    if !(-90.0..=90.0).contains(&input.lat) || !(-180.0..=180.0).contains(&input.lng) {
        return Err(AppError::bad("Coordenadas inválidas"));
    }
    sqlx::query("UPDATE users SET lat = ?, lng = ? WHERE id = ?")
        .bind(input.lat)
        .bind(input.lng)
        .bind(user.id)
        .execute(&state.db)
        .await?;
    Ok(Json(json!({ "ok": true })))
}

#[derive(Deserialize)]
pub struct PremiumInput {
    premium: bool,
}

/// Plano premium (sem anúncios). O pagamento ainda não foi definido pelo cliente,
/// então por enquanto é só um interruptor.
pub async fn set_premium(
    State(state): State<AppState>,
    user: AuthUser,
    Json(input): Json<PremiumInput>,
) -> AppResult<Json<Me>> {
    sqlx::query("UPDATE users SET is_premium = ? WHERE id = ?")
        .bind(input.premium)
        .bind(user.id)
        .execute(&state.db)
        .await?;
    Ok(Json(load_me(&state, user.id).await?))
}

/// Exclusão de conta (direito do titular na LGPD).
/// Os dados pessoais são apagados; o histórico dos cães é mantido de forma anônima.
/// Se houver denúncia em análise contra o dono, a exclusão espera a moderação.
pub async fn delete_me(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Value>> {
    let (open,): (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM reports WHERE target_user_id = ? AND status = 'aberta'")
            .bind(user.id)
            .fetch_one(&state.db)
            .await?;
    if open > 0 {
        return Err(AppError::forbidden(
            "Existe uma denúncia em análise contra esta conta. A exclusão poderá ser feita após a análise.",
        ));
    }
    let now = today().format("%Y-%m-%d").to_string();
    let mut tx = state.db.begin().await?;
    sqlx::query(
        "UPDATE users SET name = 'Usuário removido', email = 'removido-' || id || '@alllove.local',
         password_hash = '', phone = '', cpf = NULL, cep = '', city = '', address = '',
         lat = NULL, lng = NULL, deleted_at = ? WHERE id = ?",
    )
    .bind(&now)
    .bind(user.id)
    .execute(&mut *tx)
    .await?;
    sqlx::query("UPDATE dogs SET removed_at = ? WHERE owner_id = ? AND removed_at IS NULL")
        .bind(&now)
        .bind(user.id)
        .execute(&mut *tx)
        .await?;
    sqlx::query("DELETE FROM sessions WHERE user_id = ?").bind(user.id).execute(&mut *tx).await?;
    tx.commit().await?;
    Ok(Json(json!({ "ok": true })))
}

/// Perfil público de um dono: primeiro nome, cidade e todos os cães que ele já teve
/// (histórico pedido na entrevista), além do número de incidentes confirmados.
pub async fn public_profile(
    State(state): State<AppState>,
    _user: AuthUser,
    Path(id): Path<i64>,
) -> AppResult<Json<Value>> {
    let row: Option<(String, String, String, Option<String>)> =
        sqlx::query_as("SELECT name, city, created_at, banned_at FROM users WHERE id = ? AND deleted_at IS NULL")
            .bind(id)
            .fetch_optional(&state.db)
            .await?;
    let (name, city, created_at, banned) = row.ok_or_else(|| AppError::not_found("Usuário não encontrado"))?;

    let dogs: Vec<(i64, String, String, Option<String>, Option<String>, String)> = sqlx::query_as(
        "SELECT id, name, breed, photo_url, removed_at, created_at FROM dogs WHERE owner_id = ? ORDER BY created_at",
    )
    .bind(id)
    .fetch_all(&state.db)
    .await?;
    let (incidents,): (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM reports WHERE target_user_id = ? AND status = 'procedente'")
            .bind(id)
            .fetch_one(&state.db)
            .await?;

    Ok(Json(json!({
        "id": id,
        "first_name": first_name(&name),
        "city": city,
        "member_since": created_at,
        "banned": banned.is_some(),
        "confirmed_incidents": incidents,
        "dogs": dogs.into_iter().map(|(id, name, breed, photo_url, removed_at, created_at)| json!({
            "id": id, "name": name, "breed": breed, "photo_url": photo_url,
            "current": removed_at.is_none(), "since": created_at, "until": removed_at,
        })).collect::<Vec<_>>(),
    })))
}
