//! Denúncias e moderação. Denúncia grave confirmada = bloqueio permanente da conta.

use axum::{
    extract::{Path, Query, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::{FromRow, SqlitePool};

use super::{add_event, find_dog};
use crate::{
    auth::{AdminUser, AuthUser},
    error::{AppError, AppResult},
    rules::REPORT_REASONS,
    AppState,
};

#[derive(Deserialize)]
pub struct ReportInput {
    target_user_id: Option<i64>,
    target_dog_id: Option<i64>,
    reason: String,
    #[serde(default)]
    details: String,
}

pub async fn create_report(State(state): State<AppState>, user: AuthUser, Json(input): Json<ReportInput>) -> AppResult<Json<Value>> {
    if !REPORT_REASONS.contains(&input.reason.as_str()) {
        return Err(AppError::bad(format!("Motivo inválido. Use um destes: {}", REPORT_REASONS.join(", "))));
    }
    let target_user = match (input.target_dog_id, input.target_user_id) {
        (Some(dog_id), _) => find_dog(&state.db, dog_id).await?.owner_id,
        (None, Some(uid)) => uid,
        (None, None) => return Err(AppError::bad("Informe o cão ou o dono denunciado")),
    };
    if target_user == user.id {
        return Err(AppError::bad("Você não pode denunciar a si mesmo"));
    }
    sqlx::query(
        "INSERT INTO reports (reporter_id, target_user_id, target_dog_id, reason, details) VALUES (?, ?, ?, ?, ?)",
    )
    .bind(user.id)
    .bind(target_user)
    .bind(input.target_dog_id)
    .bind(&input.reason)
    .bind(input.details.trim())
    .execute(&state.db)
    .await?;
    Ok(Json(json!({ "ok": true, "message": "Denúncia enviada. A moderação vai analisar." })))
}

#[derive(FromRow, Serialize)]
pub struct ReportRow {
    id: i64,
    reason: String,
    details: String,
    status: String,
    created_at: String,
    reporter_id: i64,
    reporter_name: String,
    target_user_id: i64,
    target_name: String,
    target_email: String,
    target_phone: String,
    target_cpf: Option<String>,
    target_address: String,
    target_banned: bool,
    target_dog_id: Option<i64>,
    target_dog_name: Option<String>,
    /// Quantas denúncias o mesmo dono já recebeu (ajuda a decidir).
    target_total_reports: i64,
}

#[derive(Deserialize)]
pub struct ReportsQuery {
    status: Option<String>,
}

pub async fn list_reports(
    State(state): State<AppState>,
    _admin: AdminUser,
    Query(q): Query<ReportsQuery>,
) -> AppResult<Json<Vec<ReportRow>>> {
    let rows = sqlx::query_as(
        "SELECT r.id, r.reason, r.details, r.status, r.created_at,
                r.reporter_id, ur.name AS reporter_name,
                r.target_user_id, ut.name AS target_name, ut.email AS target_email, ut.phone AS target_phone,
                ut.cpf AS target_cpf, (ut.address || ' - ' || ut.city || ' - CEP ' || ut.cep) AS target_address,
                ut.banned_at IS NOT NULL AS target_banned,
                r.target_dog_id, d.name AS target_dog_name,
                (SELECT COUNT(*) FROM reports r2 WHERE r2.target_user_id = r.target_user_id) AS target_total_reports
         FROM reports r
         JOIN users ur ON ur.id = r.reporter_id
         JOIN users ut ON ut.id = r.target_user_id
         LEFT JOIN dogs d ON d.id = r.target_dog_id
         WHERE r.status = ?
         ORDER BY r.id DESC",
    )
    .bind(q.status.unwrap_or_else(|| "aberta".into()))
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

#[derive(Deserialize)]
pub struct ResolveInput {
    /// A denúncia é verdadeira?
    procedente: bool,
    /// Bloquear o dono permanentemente?
    #[serde(default)]
    ban: bool,
}

pub async fn resolve_report(
    State(state): State<AppState>,
    AdminUser(admin): AdminUser,
    Path(id): Path<i64>,
    Json(input): Json<ResolveInput>,
) -> AppResult<Json<Value>> {
    let row: Option<(i64, Option<i64>, String, String)> =
        sqlx::query_as("SELECT target_user_id, target_dog_id, reason, status FROM reports WHERE id = ?")
            .bind(id)
            .fetch_optional(&state.db)
            .await?;
    let (target_user, target_dog, reason, status) = row.ok_or_else(|| AppError::not_found("Denúncia não encontrada"))?;
    if status != "aberta" {
        return Err(AppError::bad("Esta denúncia já foi analisada"));
    }
    sqlx::query("UPDATE reports SET status = ?, resolved_at = CURRENT_TIMESTAMP, resolved_by = ? WHERE id = ?")
        .bind(if input.procedente { "procedente" } else { "improcedente" })
        .bind(admin.id)
        .bind(id)
        .execute(&state.db)
        .await?;

    if input.procedente {
        if let Some(dog_id) = target_dog {
            add_event(&state.db, dog_id, "incidente", &format!("Denúncia confirmada pela moderação: {reason}")).await?;
        }
        if input.ban {
            ban(&state.db, target_user, &format!("Denúncia confirmada: {reason}")).await?;
        }
    }
    Ok(Json(json!({ "ok": true })))
}

#[derive(FromRow, Serialize)]
pub struct AdminUserRow {
    id: i64,
    name: String,
    email: String,
    phone: String,
    cpf: Option<String>,
    cep: String,
    city: String,
    address: String,
    is_admin: bool,
    is_premium: bool,
    banned_at: Option<String>,
    ban_reason: Option<String>,
    created_at: String,
    dogs: i64,
    reports: i64,
}

#[derive(Deserialize)]
pub struct UsersQuery {
    q: Option<String>,
}

/// Busca de donos por nome, e-mail ou CPF (dados completos, só para a moderação).
pub async fn list_users(
    State(state): State<AppState>,
    _admin: AdminUser,
    Query(q): Query<UsersQuery>,
) -> AppResult<Json<Vec<AdminUserRow>>> {
    let term = q.q.unwrap_or_default();
    let digits: String = term.chars().filter(|c| c.is_ascii_digit()).collect();
    let like = format!("%{}%", term.trim().to_lowercase());
    let cpf_like = if digits.is_empty() { "-".to_string() } else { format!("%{digits}%") };
    let rows = sqlx::query_as(
        "SELECT u.id, u.name, u.email, u.phone, u.cpf, u.cep, u.city, u.address, u.is_admin, u.is_premium,
                u.banned_at, u.ban_reason, u.created_at,
                (SELECT COUNT(*) FROM dogs d WHERE d.owner_id = u.id) AS dogs,
                (SELECT COUNT(*) FROM reports r WHERE r.target_user_id = u.id) AS reports
         FROM users u
         WHERE u.deleted_at IS NULL AND (lower(u.name) LIKE ?1 OR lower(u.email) LIKE ?1 OR u.cpf LIKE ?2)
         ORDER BY u.id DESC LIMIT 100",
    )
    .bind(like)
    .bind(cpf_like)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

#[derive(Deserialize)]
pub struct BanInput {
    reason: String,
}

/// Bloqueio direto, por exemplo quando o dono responde a processo judicial envolvendo animais.
pub async fn ban_user(
    State(state): State<AppState>,
    AdminUser(admin): AdminUser,
    Path(id): Path<i64>,
    Json(input): Json<BanInput>,
) -> AppResult<Json<Value>> {
    if id == admin.id {
        return Err(AppError::bad("Você não pode bloquear a própria conta"));
    }
    let reason = input.reason.trim();
    if reason.is_empty() {
        return Err(AppError::bad("Informe o motivo do bloqueio"));
    }
    ban(&state.db, id, reason).await?;
    Ok(Json(json!({ "ok": true })))
}

async fn ban(db: &SqlitePool, user_id: i64, reason: &str) -> AppResult<()> {
    sqlx::query("UPDATE users SET banned_at = CURRENT_TIMESTAMP, ban_reason = ? WHERE id = ? AND banned_at IS NULL")
        .bind(reason)
        .bind(user_id)
        .execute(db)
        .await?;
    sqlx::query("DELETE FROM sessions WHERE user_id = ?").bind(user_id).execute(db).await?;
    Ok(())
}

// ---------- pedigrees e profissionais aguardando verificação ----------

#[derive(FromRow, Serialize)]
pub struct PendingDocument {
    id: i64,
    title: String,
    file_url: String,
    created_at: String,
    dog_id: i64,
    dog_name: String,
    dog_breed: String,
    owner_name: String,
}

pub async fn pending_pedigrees(State(state): State<AppState>, _admin: AdminUser) -> AppResult<Json<Vec<PendingDocument>>> {
    let rows = sqlx::query_as(
        "SELECT x.id, x.title, x.file_url, x.created_at, d.id AS dog_id, d.name AS dog_name, d.breed AS dog_breed,
                u.name AS owner_name
         FROM dog_documents x JOIN dogs d ON d.id = x.dog_id JOIN users u ON u.id = d.owner_id
         WHERE x.kind = 'pedigree' AND x.status = 'enviado' ORDER BY x.id",
    )
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

#[derive(Deserialize)]
pub struct ReviewInput {
    approved: bool,
}

pub async fn review_pedigree(
    State(state): State<AppState>,
    _admin: AdminUser,
    Path(id): Path<i64>,
    Json(input): Json<ReviewInput>,
) -> AppResult<Json<Value>> {
    let row: Option<(i64,)> = sqlx::query_as("SELECT dog_id FROM dog_documents WHERE id = ? AND kind = 'pedigree'")
        .bind(id)
        .fetch_optional(&state.db)
        .await?;
    let (dog_id,) = row.ok_or_else(|| AppError::not_found("Pedigree não encontrado"))?;
    sqlx::query("UPDATE dog_documents SET status = ? WHERE id = ?")
        .bind(if input.approved { "verificado" } else { "recusado" })
        .bind(id)
        .execute(&state.db)
        .await?;
    add_event(
        &state.db,
        dog_id,
        "pedigree",
        if input.approved { "Pedigree verificado pela moderação" } else { "Pedigree recusado pela moderação" },
    )
    .await?;
    Ok(Json(json!({ "ok": true })))
}

#[derive(FromRow, Serialize)]
pub struct PendingProvider {
    id: i64,
    name: String,
    kind: String,
    phone: String,
    address: String,
    services: String,
    owner_name: Option<String>,
}

pub async fn pending_providers(State(state): State<AppState>, _admin: AdminUser) -> AppResult<Json<Vec<PendingProvider>>> {
    let rows = sqlx::query_as(
        "SELECT p.id, p.name, p.kind, p.phone, p.address, p.services, u.name AS owner_name
         FROM providers p LEFT JOIN users u ON u.id = p.owner_id WHERE p.verified = 0 ORDER BY p.id",
    )
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}
