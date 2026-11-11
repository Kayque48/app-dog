//! "Descobrir" no estilo Tinder: cães a até 500 m, arrastar para a direita (quero conhecer)
//! ou para a esquerda (passar). O dono do outro cão aceita ou recusa o encontro.

use axum::{
    extract::{Path, Query, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;

use super::{add_event, dog_view, find_dog, find_own_dog, first_name, vaccine_status_of, DogRow, DogView, DOG_COLUMNS};
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    rules, AppState,
};

/// O cão do usuário só pode usar o Descobrir com a vacinação em dia.
async fn ensure_vaccinated(state: &AppState, dog: &DogRow) -> AppResult<()> {
    let status = vaccine_status_of(&state.db, dog.id).await?;
    if status.up_to_date {
        return Ok(());
    }
    let mut problems = Vec::new();
    if !status.overdue.is_empty() {
        problems.push(format!("vacinas atrasadas: {}", status.overdue.join(", ")));
    }
    if !status.missing.is_empty() {
        problems.push(format!("vacinas obrigatórias faltando: {}", status.missing.join(", ")));
    }
    Err(AppError::forbidden(format!(
        "{} está bloqueado no Descobrir ({}). Atualize a carteira de vacinação para voltar.",
        dog.name,
        problems.join("; ")
    )))
}

#[derive(Deserialize)]
pub struct DiscoverQuery {
    dog_id: i64,
    radius_m: Option<f64>,
    /// "cruzamento" mostra só cães do sexo oposto, não castrados, que também procuram cruzamento.
    goal: Option<String>,
}

#[derive(Serialize)]
pub struct Card {
    #[serde(flatten)]
    dog: DogView,
    /// Distância aproximada (arredondada para 10 m). A localização exata nunca é enviada.
    distance_m: i64,
    owner_first_name: String,
    /// O outro cão já pediu para conhecer o seu.
    wants_to_meet_you: bool,
}

#[derive(FromRow)]
struct Candidate {
    #[sqlx(flatten)]
    dog: DogRow,
    owner_name: String,
    lat: f64,
    lng: f64,
    wants_me: bool,
}

pub async fn discover(
    State(state): State<AppState>,
    user: AuthUser,
    Query(q): Query<DiscoverQuery>,
) -> AppResult<Json<Vec<Card>>> {
    let my_dog = find_own_dog(&state.db, q.dog_id, user.id).await?;
    ensure_vaccinated(&state, &my_dog).await?;
    let (Some(lat), Some(lng)) = (user.lat, user.lng) else {
        return Err(AppError::bad("Ative a localização para encontrar cães por perto"));
    };
    let radius = q.radius_m.unwrap_or(rules::DEFAULT_RADIUS_M).clamp(100.0, 20_000.0);
    let breeding = q.goal.as_deref() == Some("cruzamento");
    if breeding && (my_dog.neutered || my_dog.looking_for == "amizade") {
        return Err(AppError::bad(format!(
            "Para procurar cruzamento, marque no perfil de {} que ele procura cruzamento (e não é castrado).",
            my_dog.name
        )));
    }

    // Primeiro um filtro rápido por "quadrado" no SQL, depois a distância exata em Rust.
    let dlat = radius / 111_320.0;
    let dlng = radius / (111_320.0 * lat.to_radians().cos().max(0.01));
    let candidates: Vec<Candidate> = sqlx::query_as(&format!(
        "SELECT {DOG_COLUMNS}, u.name AS owner_name, u.lat AS lat, u.lng AS lng,
                EXISTS (SELECT 1 FROM match_requests m
                        WHERE m.from_dog_id = d.id AND m.to_dog_id = ?1 AND m.status = 'pending') AS wants_me
         FROM dogs d JOIN users u ON u.id = d.owner_id
         WHERE u.id != ?2 AND u.banned_at IS NULL AND u.deleted_at IS NULL AND d.removed_at IS NULL
           AND u.lat BETWEEN ?3 AND ?4 AND u.lng BETWEEN ?5 AND ?6
           AND d.id NOT IN (SELECT to_dog_id FROM match_requests WHERE from_dog_id = ?1)
           AND d.id NOT IN (SELECT from_dog_id FROM match_requests
                            WHERE to_dog_id = ?1 AND status IN ('accepted', 'rejected'))"
    ))
    .bind(my_dog.id)
    .bind(user.id)
    .bind(lat - dlat)
    .bind(lat + dlat)
    .bind(lng - dlng)
    .bind(lng + dlng)
    .fetch_all(&state.db)
    .await?;

    let mut cards = Vec::new();
    for c in candidates {
        let distance = rules::distance_m(lat, lng, c.lat, c.lng);
        if distance > radius {
            continue;
        }
        let view = dog_view(&state.db, c.dog).await?;
        if !view.vaccine_status.up_to_date {
            continue; // cães com vacina atrasada não aparecem para ninguém
        }
        if breeding && (view.dog.sex == my_dog.sex || view.dog.neutered || view.dog.looking_for == "amizade") {
            continue;
        }
        cards.push(Card {
            dog: view,
            distance_m: ((distance / 10.0).round() * 10.0) as i64,
            owner_first_name: first_name(&c.owner_name),
            wants_to_meet_you: c.wants_me,
        });
    }
    cards.sort_by_key(|c| c.distance_m);
    Ok(Json(cards))
}

#[derive(Deserialize)]
pub struct SwipeInput {
    from_dog_id: i64,
    to_dog_id: i64,
    /// `true` = arrastou para a direita (quero conhecer).
    liked: bool,
}

pub async fn swipe(State(state): State<AppState>, user: AuthUser, Json(input): Json<SwipeInput>) -> AppResult<Json<Value>> {
    let mine = find_own_dog(&state.db, input.from_dog_id, user.id).await?;
    ensure_vaccinated(&state, &mine).await?;
    let other = find_dog(&state.db, input.to_dog_id).await?;
    if other.owner_id == user.id || other.removed_at.is_some() {
        return Err(AppError::bad("Cão inválido"));
    }

    if input.liked {
        // Se o outro cão já tinha pedido para conhecer o meu, o encontro é aceito na hora.
        let accepted = sqlx::query(
            "UPDATE match_requests SET status = 'accepted', responded_at = CURRENT_TIMESTAMP
             WHERE from_dog_id = ? AND to_dog_id = ? AND status = 'pending'",
        )
        .bind(other.id)
        .bind(mine.id)
        .execute(&state.db)
        .await?
        .rows_affected();
        if accepted > 0 {
            register_match(&state, &other, &mine).await?;
            return Ok(Json(json!({ "matched": true })));
        }
    }

    sqlx::query("INSERT OR IGNORE INTO match_requests (from_dog_id, to_dog_id, status) VALUES (?, ?, ?)")
        .bind(mine.id)
        .bind(other.id)
        .bind(if input.liked { "pending" } else { "passed" })
        .execute(&state.db)
        .await?;
    Ok(Json(json!({ "matched": false })))
}

async fn register_match(state: &AppState, a: &DogRow, b: &DogRow) -> AppResult<()> {
    add_event(&state.db, a.id, "encontro", &format!("Combinou um encontro com {}", b.name)).await?;
    add_event(&state.db, b.id, "encontro", &format!("Combinou um encontro com {}", a.name)).await?;
    Ok(())
}

#[derive(FromRow)]
struct MatchRow {
    id: i64,
    status: String,
    created_at: String,
    from_dog_id: i64,
    from_dog_name: String,
    from_dog_breed: String,
    from_dog_photo: Option<String>,
    from_owner_id: i64,
    from_owner_name: String,
    from_owner_phone: String,
    to_dog_id: i64,
    to_dog_name: String,
    to_dog_breed: String,
    to_dog_photo: Option<String>,
    to_owner_id: i64,
    to_owner_name: String,
    to_owner_phone: String,
}

/// Lista pedidos recebidos, pedidos enviados e encontros aceitos.
/// O telefone do outro dono só aparece depois que o encontro é aceito.
pub async fn matches(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Vec<Value>>> {
    let rows: Vec<MatchRow> = sqlx::query_as(
        "SELECT m.id, m.status, m.created_at,
                a.id AS from_dog_id, a.name AS from_dog_name, a.breed AS from_dog_breed, a.photo_url AS from_dog_photo,
                ua.id AS from_owner_id, ua.name AS from_owner_name, ua.phone AS from_owner_phone,
                b.id AS to_dog_id, b.name AS to_dog_name, b.breed AS to_dog_breed, b.photo_url AS to_dog_photo,
                ub.id AS to_owner_id, ub.name AS to_owner_name, ub.phone AS to_owner_phone
         FROM match_requests m
         JOIN dogs a ON a.id = m.from_dog_id JOIN users ua ON ua.id = a.owner_id
         JOIN dogs b ON b.id = m.to_dog_id   JOIN users ub ON ub.id = b.owner_id
         WHERE m.status IN ('pending', 'accepted') AND (ua.id = ?1 OR ub.id = ?1)
           AND ua.banned_at IS NULL AND ub.banned_at IS NULL
           AND ua.deleted_at IS NULL AND ub.deleted_at IS NULL
           AND a.removed_at IS NULL AND b.removed_at IS NULL
         ORDER BY m.id DESC",
    )
    .bind(user.id)
    .fetch_all(&state.db)
    .await?;

    let out = rows
        .into_iter()
        .map(|m| {
            let incoming = m.to_owner_id == user.id;
            let accepted = m.status == "accepted";
            let (my_dog, other_dog, other_owner_id, other_owner_name, other_owner_phone) = if incoming {
                (
                    json!({ "id": m.to_dog_id, "name": m.to_dog_name, "breed": m.to_dog_breed, "photo_url": m.to_dog_photo }),
                    json!({ "id": m.from_dog_id, "name": m.from_dog_name, "breed": m.from_dog_breed, "photo_url": m.from_dog_photo }),
                    m.from_owner_id,
                    m.from_owner_name,
                    m.from_owner_phone,
                )
            } else {
                (
                    json!({ "id": m.from_dog_id, "name": m.from_dog_name, "breed": m.from_dog_breed, "photo_url": m.from_dog_photo }),
                    json!({ "id": m.to_dog_id, "name": m.to_dog_name, "breed": m.to_dog_breed, "photo_url": m.to_dog_photo }),
                    m.to_owner_id,
                    m.to_owner_name,
                    m.to_owner_phone,
                )
            };
            json!({
                "id": m.id,
                "status": m.status,
                "direction": if incoming { "incoming" } else { "outgoing" },
                "created_at": m.created_at,
                "my_dog": my_dog,
                "other_dog": other_dog,
                "other_owner": {
                    "id": other_owner_id,
                    "first_name": first_name(&other_owner_name),
                    "phone": if accepted { Some(other_owner_phone) } else { None },
                },
            })
        })
        .collect();
    Ok(Json(out))
}

#[derive(Deserialize)]
pub struct RespondInput {
    accept: bool,
}

/// O dono do cão que recebeu o pedido aceita ou recusa.
pub async fn respond(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<RespondInput>,
) -> AppResult<Json<Value>> {
    let row: Option<(i64, i64, String)> =
        sqlx::query_as("SELECT from_dog_id, to_dog_id, status FROM match_requests WHERE id = ?")
            .bind(id)
            .fetch_optional(&state.db)
            .await?;
    let (from_id, to_id, status) = row.ok_or_else(|| AppError::not_found("Pedido não encontrado"))?;
    let mine = find_own_dog(&state.db, to_id, user.id).await?;
    if status != "pending" {
        return Err(AppError::bad("Este pedido já foi respondido"));
    }
    sqlx::query("UPDATE match_requests SET status = ?, responded_at = CURRENT_TIMESTAMP WHERE id = ?")
        .bind(if input.accept { "accepted" } else { "rejected" })
        .bind(id)
        .execute(&state.db)
        .await?;
    if input.accept {
        let other = find_dog(&state.db, from_id).await?;
        register_match(&state, &other, &mine).await?;
    }
    Ok(Json(json!({ "ok": true })))
}
