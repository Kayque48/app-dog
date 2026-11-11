//! Eventos (desfile de cadelas, corrida de salsichas, festas...): presença,
//! inscrição de cães no concurso e votação com ranking.

use axum::{
    extract::{Path, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;

use super::{add_event, find_own_dog, first_name, required, vaccine_status_of};
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    rules, AppState,
};

pub const EVENT_KINDS: &[&str] = &["desfile", "corrida", "festa", "encontro", "concurso", "adocao", "competicao"];

#[derive(FromRow, Serialize)]
pub struct EventRow {
    id: i64,
    title: String,
    description: String,
    kind: String,
    place_name: String,
    address: String,
    lat: f64,
    lng: f64,
    starts_at: String,
    cover_url: Option<String>,
    has_contest: bool,
    entry_sex: Option<String>,
    entry_breed: Option<String>,
    going: i64,
    maybe: i64,
    entries: i64,
    my_rsvp: Option<String>,
    #[sqlx(skip)]
    distance_m: Option<i64>,
}

const EVENT_SELECT: &str = "SELECT e.id, e.title, e.description, e.kind, e.place_name, e.address, e.lat, e.lng,
        e.starts_at, e.cover_url, e.has_contest, e.entry_sex, e.entry_breed,
        (SELECT COUNT(*) FROM event_rsvps r WHERE r.event_id = e.id AND r.status = 'going') AS going,
        (SELECT COUNT(*) FROM event_rsvps r WHERE r.event_id = e.id AND r.status = 'maybe') AS maybe,
        (SELECT COUNT(*) FROM event_entries x WHERE x.event_id = e.id) AS entries,
        (SELECT status FROM event_rsvps r WHERE r.event_id = e.id AND r.user_id = ?1) AS my_rsvp
     FROM events e";

fn with_distance(mut e: EventRow, user: &AuthUser) -> EventRow {
    if let (Some(lat), Some(lng)) = (user.lat, user.lng) {
        e.distance_m = Some(rules::distance_m(lat, lng, e.lat, e.lng).round() as i64);
    }
    e
}

/// Próximos eventos, do mais perto no tempo para o mais longe.
pub async fn list(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Vec<EventRow>>> {
    let rows: Vec<EventRow> = sqlx::query_as(&format!(
        "{EVENT_SELECT} WHERE e.starts_at >= strftime('%Y-%m-%d', 'now', '-1 day') ORDER BY e.starts_at LIMIT 50"
    ))
    .bind(user.id)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows.into_iter().map(|e| with_distance(e, &user)).collect()))
}

#[derive(FromRow, Serialize)]
struct EntryRow {
    id: i64,
    dog_id: i64,
    dog_name: String,
    dog_breed: String,
    dog_photo_url: Option<String>,
    owner_id: i64,
    owner_name: String,
    votes: i64,
}

/// Evento com ranking do concurso, meu voto e cães de quem confirmou presença.
pub async fn detail(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let event: EventRow = sqlx::query_as(&format!("{EVENT_SELECT} WHERE e.id = ?2"))
        .bind(user.id)
        .bind(id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| AppError::not_found("Evento não encontrado"))?;

    let mut entries: Vec<EntryRow> = sqlx::query_as(
        "SELECT x.id, d.id AS dog_id, d.name AS dog_name, d.breed AS dog_breed, d.photo_url AS dog_photo_url,
                u.id AS owner_id, u.name AS owner_name,
                (SELECT COUNT(*) FROM event_votes v WHERE v.entry_id = x.id) AS votes
         FROM event_entries x JOIN dogs d ON d.id = x.dog_id JOIN users u ON u.id = d.owner_id
         WHERE x.event_id = ? AND u.banned_at IS NULL AND d.removed_at IS NULL
         ORDER BY votes DESC, x.id",
    )
    .bind(id)
    .fetch_all(&state.db)
    .await?;
    for e in &mut entries {
        e.owner_name = first_name(&e.owner_name);
    }

    let my_vote: Option<(i64,)> = sqlx::query_as("SELECT entry_id FROM event_votes WHERE event_id = ? AND user_id = ?")
        .bind(id)
        .bind(user.id)
        .fetch_optional(&state.db)
        .await?;

    // "quem vai": cães dos donos que confirmaram presença
    let attendees: Vec<(i64, String, Option<String>)> = sqlx::query_as(
        "SELECT d.id, d.name, d.photo_url FROM event_rsvps r
         JOIN dogs d ON d.owner_id = r.user_id AND d.removed_at IS NULL
         WHERE r.event_id = ? AND r.status = 'going' LIMIT 30",
    )
    .bind(id)
    .fetch_all(&state.db)
    .await?;

    Ok(Json(json!({
        "event": with_distance(event, &user),
        "entries": entries,
        "my_vote": my_vote.map(|v| v.0),
        "attendees": attendees.into_iter().map(|(id, name, photo_url)| json!({ "id": id, "name": name, "photo_url": photo_url })).collect::<Vec<_>>(),
    })))
}

#[derive(Deserialize)]
pub struct EventInput {
    title: String,
    #[serde(default)]
    description: String,
    kind: String,
    place_name: String,
    #[serde(default)]
    address: String,
    lat: f64,
    lng: f64,
    starts_at: String,
    #[serde(default)]
    has_contest: bool,
    entry_sex: Option<String>,
    entry_breed: Option<String>,
}

/// Qualquer dono pode criar um evento.
pub async fn create(State(state): State<AppState>, user: AuthUser, Json(input): Json<EventInput>) -> AppResult<Json<Value>> {
    if !EVENT_KINDS.contains(&input.kind.as_str()) {
        return Err(AppError::bad(format!("Tipo inválido. Use: {}", EVENT_KINDS.join(", "))));
    }
    let starts = chrono::NaiveDateTime::parse_from_str(&input.starts_at.replace('T', " "), "%Y-%m-%d %H:%M")
        .map_err(|_| AppError::bad("Data e hora inválidas (use AAAA-MM-DD HH:MM)"))?;
    if starts < chrono::Local::now().naive_local() {
        return Err(AppError::bad("O evento precisa ser no futuro"));
    }
    let entry_sex = input.entry_sex.filter(|s| !s.is_empty());
    if let Some(s) = &entry_sex {
        if !["macho", "femea"].contains(&s.as_str()) {
            return Err(AppError::bad("Sexo do concurso deve ser 'macho' ou 'femea'"));
        }
    }
    let id = sqlx::query(
        "INSERT INTO events (title, description, kind, place_name, address, lat, lng, starts_at, has_contest,
                             entry_sex, entry_breed, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(required(&input.title, "título")?)
    .bind(input.description.trim())
    .bind(&input.kind)
    .bind(required(&input.place_name, "local")?)
    .bind(input.address.trim())
    .bind(input.lat)
    .bind(input.lng)
    .bind(starts.format("%Y-%m-%d %H:%M").to_string())
    .bind(input.has_contest)
    .bind(&entry_sex)
    .bind(input.entry_breed.as_deref().map(str::trim).filter(|s| !s.is_empty()))
    .bind(user.id)
    .execute(&state.db)
    .await?
    .last_insert_rowid();
    // quem cria já vai
    sqlx::query("INSERT INTO event_rsvps (event_id, user_id, status) VALUES (?, ?, 'going')")
        .bind(id)
        .bind(user.id)
        .execute(&state.db)
        .await?;
    Ok(Json(json!({ "id": id })))
}

#[derive(Deserialize)]
pub struct RsvpInput {
    /// "going", "maybe" ou null para desmarcar.
    status: Option<String>,
}

pub async fn rsvp(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<RsvpInput>,
) -> AppResult<Json<Value>> {
    match input.status.as_deref() {
        None => {
            sqlx::query("DELETE FROM event_rsvps WHERE event_id = ? AND user_id = ?")
                .bind(id)
                .bind(user.id)
                .execute(&state.db)
                .await?;
        }
        Some(s @ ("going" | "maybe")) => {
            sqlx::query(
                "INSERT INTO event_rsvps (event_id, user_id, status) SELECT id, ?, ? FROM events WHERE id = ?
                 ON CONFLICT (event_id, user_id) DO UPDATE SET status = excluded.status",
            )
            .bind(user.id)
            .bind(s)
            .bind(id)
            .execute(&state.db)
            .await?;
        }
        Some(_) => return Err(AppError::bad("Status deve ser 'going' ou 'maybe'")),
    }
    Ok(Json(json!({ "ok": true })))
}

#[derive(Deserialize)]
pub struct EntryInput {
    dog_id: i64,
}

/// Inscreve um cão no concurso, conferindo as regras do evento e a vacinação.
pub async fn enter(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<EntryInput>,
) -> AppResult<Json<Value>> {
    let event: Option<(String, bool, Option<String>, Option<String>)> =
        sqlx::query_as("SELECT title, has_contest, entry_sex, entry_breed FROM events WHERE id = ?")
            .bind(id)
            .fetch_optional(&state.db)
            .await?;
    let (title, has_contest, entry_sex, entry_breed) = event.ok_or_else(|| AppError::not_found("Evento não encontrado"))?;
    if !has_contest {
        return Err(AppError::bad("Este evento não tem concurso"));
    }
    let dog = find_own_dog(&state.db, input.dog_id, user.id).await?;
    if let Some(sex) = &entry_sex {
        if &dog.sex != sex {
            let who = if sex == "femea" { "fêmeas" } else { "machos" };
            return Err(AppError::bad(format!("Este concurso é só para {who}")));
        }
    }
    if let Some(breed) = &entry_breed {
        if !dog.breed.to_lowercase().contains(&breed.to_lowercase()) {
            return Err(AppError::bad(format!("Este concurso é só para a raça {breed}")));
        }
    }
    if !vaccine_status_of(&state.db, dog.id).await?.up_to_date {
        return Err(AppError::forbidden(format!("{} precisa estar com a vacinação em dia para participar", dog.name)));
    }
    let added = sqlx::query("INSERT OR IGNORE INTO event_entries (event_id, dog_id) VALUES (?, ?)")
        .bind(id)
        .bind(dog.id)
        .execute(&state.db)
        .await?
        .rows_affected();
    if added == 0 {
        return Err(AppError::Conflict(format!("{} já está inscrito", dog.name)));
    }
    // quem inscreve o cão vai ao evento
    sqlx::query(
        "INSERT INTO event_rsvps (event_id, user_id, status) VALUES (?, ?, 'going')
         ON CONFLICT (event_id, user_id) DO UPDATE SET status = 'going'",
    )
    .bind(id)
    .bind(user.id)
    .execute(&state.db)
    .await?;
    add_event(&state.db, dog.id, "evento", &format!("Inscrito no concurso \"{title}\"")).await?;
    Ok(Json(json!({ "ok": true })))
}

#[derive(Deserialize)]
pub struct VoteInput {
    entry_id: i64,
}

/// Vota em um participante. Um voto por pessoa por evento; votar de novo troca o voto.
pub async fn vote(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<VoteInput>,
) -> AppResult<Json<Value>> {
    let row: Option<(i64,)> = sqlx::query_as(
        "SELECT d.owner_id FROM event_entries x JOIN dogs d ON d.id = x.dog_id WHERE x.id = ? AND x.event_id = ?",
    )
    .bind(input.entry_id)
    .bind(id)
    .fetch_optional(&state.db)
    .await?;
    let (owner,) = row.ok_or_else(|| AppError::not_found("Participante não encontrado"))?;
    if owner == user.id {
        return Err(AppError::bad("Não vale votar no próprio cão 😉"));
    }
    sqlx::query(
        "INSERT INTO event_votes (event_id, user_id, entry_id) VALUES (?, ?, ?)
         ON CONFLICT (event_id, user_id) DO UPDATE SET entry_id = excluded.entry_id",
    )
    .bind(id)
    .bind(user.id)
    .bind(input.entry_id)
    .execute(&state.db)
    .await?;
    Ok(Json(json!({ "ok": true })))
}
