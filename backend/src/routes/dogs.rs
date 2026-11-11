use axum::{
    extract::{Path, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;

use super::{add_event, dog_view, find_dog, find_own_dog, first_name, required, today, DogRow, DogView, DOG_COLUMNS};
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    rules, AppState,
};

#[derive(Deserialize)]
pub struct DogInput {
    name: String,
    breed: String,
    birth_date: String,
    sex: String,
    in_heat: bool,
    temperament: String,
    bites: bool,
    #[serde(default)]
    likes: String,
    #[serde(default)]
    dislikes: String,
    photo_url: Option<String>,
    weight_kg: Option<f64>,
    #[serde(default)]
    color: String,
    #[serde(default)]
    bio: String,
    #[serde(default = "default_activity")]
    activity_level: String,
    #[serde(default = "default_looking_for")]
    looking_for: String,
    #[serde(default)]
    microchip: String,
    #[serde(default)]
    neutered: bool,
    #[serde(default)]
    allergies: String,
    #[serde(default)]
    health_notes: String,
}

fn default_activity() -> String {
    "medio".into()
}
fn default_looking_for() -> String {
    "amizade".into()
}

struct ValidDog {
    name: String,
    breed: String,
    birth_date: String,
    sex: String,
    temperament: String,
}

fn validate(input: &DogInput) -> AppResult<ValidDog> {
    let birth = rules::parse_date(&input.birth_date)
        .ok_or_else(|| AppError::bad("Data de nascimento inválida (use AAAA-MM-DD)"))?;
    if birth > today() {
        return Err(AppError::bad("A data de nascimento não pode ser no futuro"));
    }
    if !["macho", "femea"].contains(&input.sex.as_str()) {
        return Err(AppError::bad("Sexo deve ser 'macho' ou 'femea'"));
    }
    if !["calmo", "brincalhao", "timido", "agressivo"].contains(&input.temperament.as_str()) {
        return Err(AppError::bad("Temperamento inválido"));
    }
    if !["baixo", "medio", "alto"].contains(&input.activity_level.as_str()) {
        return Err(AppError::bad("Nível de atividade deve ser baixo, medio ou alto"));
    }
    if !["amizade", "cruzamento", "ambos"].contains(&input.looking_for.as_str()) {
        return Err(AppError::bad("Objetivo deve ser amizade, cruzamento ou ambos"));
    }
    if input.looking_for != "amizade" && input.neutered {
        return Err(AppError::bad("Cão castrado não pode procurar cruzamento"));
    }
    if input.weight_kg.is_some_and(|w| !(0.3..=120.0).contains(&w)) {
        return Err(AppError::bad("Peso inválido"));
    }
    if input.in_heat && input.sex != "femea" {
        return Err(AppError::bad("Só fêmeas entram no cio"));
    }
    Ok(ValidDog {
        name: required(&input.name, "nome")?,
        breed: required(&input.breed, "raça")?,
        birth_date: input.birth_date.clone(),
        sex: input.sex.clone(),
        temperament: input.temperament.clone(),
    })
}

/// Cães atuais e antigos do usuário logado.
pub async fn my_dogs(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Vec<DogView>>> {
    let dogs: Vec<DogRow> =
        sqlx::query_as(&format!("SELECT {DOG_COLUMNS} FROM dogs d WHERE d.owner_id = ? ORDER BY d.removed_at IS NOT NULL, d.id"))
            .bind(user.id)
            .fetch_all(&state.db)
            .await?;
    let mut out = Vec::with_capacity(dogs.len());
    for d in dogs {
        out.push(dog_view(&state.db, d).await?);
    }
    Ok(Json(out))
}

pub async fn create(
    State(state): State<AppState>,
    user: AuthUser,
    Json(input): Json<DogInput>,
) -> AppResult<Json<DogView>> {
    let v = validate(&input)?;
    let id = sqlx::query(
        "INSERT INTO dogs (owner_id, name, breed, birth_date, sex, in_heat, temperament, bites, likes, dislikes, photo_url,
                           weight_kg, color, bio, activity_level, looking_for, microchip, neutered, allergies, health_notes)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(user.id)
    .bind(&v.name)
    .bind(&v.breed)
    .bind(&v.birth_date)
    .bind(&v.sex)
    .bind(input.in_heat)
    .bind(&v.temperament)
    .bind(input.bites)
    .bind(input.likes.trim())
    .bind(input.dislikes.trim())
    .bind(&input.photo_url)
    .bind(input.weight_kg)
    .bind(input.color.trim())
    .bind(input.bio.trim())
    .bind(&input.activity_level)
    .bind(&input.looking_for)
    .bind(input.microchip.trim())
    .bind(input.neutered)
    .bind(input.allergies.trim())
    .bind(input.health_notes.trim())
    .execute(&state.db)
    .await?
    .last_insert_rowid();

    add_event(&state.db, id, "cadastro", &format!("{} foi cadastrado no All Love", v.name)).await?;
    let dog = find_dog(&state.db, id).await?;
    Ok(Json(dog_view(&state.db, dog).await?))
}

pub async fn update(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<DogInput>,
) -> AppResult<Json<DogView>> {
    let old = find_own_dog(&state.db, id, user.id).await?;
    let v = validate(&input)?;
    sqlx::query(
        "UPDATE dogs SET name = ?, breed = ?, birth_date = ?, sex = ?, in_heat = ?, temperament = ?,
         bites = ?, likes = ?, dislikes = ?, photo_url = ?, weight_kg = ?, color = ?, bio = ?, activity_level = ?,
         looking_for = ?, microchip = ?, neutered = ?, allergies = ?, health_notes = ? WHERE id = ?",
    )
    .bind(&v.name)
    .bind(&v.breed)
    .bind(&v.birth_date)
    .bind(&v.sex)
    .bind(input.in_heat)
    .bind(&v.temperament)
    .bind(input.bites)
    .bind(input.likes.trim())
    .bind(input.dislikes.trim())
    .bind(&input.photo_url)
    .bind(input.weight_kg)
    .bind(input.color.trim())
    .bind(input.bio.trim())
    .bind(&input.activity_level)
    .bind(&input.looking_for)
    .bind(input.microchip.trim())
    .bind(input.neutered)
    .bind(input.allergies.trim())
    .bind(input.health_notes.trim())
    .bind(id)
    .execute(&state.db)
    .await?;

    // Mudanças de comportamento entram no histórico do cão.
    if old.temperament != v.temperament || old.bites != input.bites {
        let bites = if input.bites { "morde" } else { "não morde" };
        add_event(&state.db, id, "perfil", &format!("Temperamento atualizado para {} ({bites})", v.temperament)).await?;
    }
    let dog = find_dog(&state.db, id).await?;
    Ok(Json(dog_view(&state.db, dog).await?))
}

/// Remove o cão do perfil do dono. O registro continua no histórico.
pub async fn remove(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let dog = find_own_dog(&state.db, id, user.id).await?;
    sqlx::query("UPDATE dogs SET removed_at = ? WHERE id = ?")
        .bind(today().format("%Y-%m-%d").to_string())
        .bind(id)
        .execute(&state.db)
        .await?;
    add_event(&state.db, id, "removido", &format!("{} foi removido do perfil do dono", dog.name)).await?;
    Ok(Json(json!({ "ok": true })))
}

#[derive(FromRow, Serialize)]
pub struct EventRow {
    kind: String,
    description: String,
    created_at: String,
}

/// Perfil completo de um cão: dados, vacinação, dono (só primeiro nome) e histórico.
pub async fn profile(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let dog = find_dog(&state.db, id).await?;
    let owner_id = dog.owner_id;
    let (owner_name,): (String,) = sqlx::query_as("SELECT name FROM users WHERE id = ?")
        .bind(owner_id)
        .fetch_one(&state.db)
        .await?;
    let history: Vec<EventRow> =
        sqlx::query_as("SELECT kind, description, created_at FROM dog_events WHERE dog_id = ? ORDER BY id DESC")
            .bind(id)
            .fetch_all(&state.db)
            .await?;
    let view = dog_view(&state.db, dog).await?;
    Ok(Json(json!({
        "dog": view,
        "owner": { "id": owner_id, "first_name": first_name(&owner_name) },
        "is_mine": owner_id == user.id,
        "history": history,
    })))
}

#[derive(FromRow, Serialize)]
pub struct VaccineRow {
    id: i64,
    name: String,
    applied_on: String,
    next_due: Option<String>,
}

pub async fn list_vaccines(
    State(state): State<AppState>,
    _user: AuthUser,
    Path(id): Path<i64>,
) -> AppResult<Json<Vec<VaccineRow>>> {
    let rows = sqlx::query_as("SELECT id, name, applied_on, next_due FROM vaccines WHERE dog_id = ? ORDER BY applied_on DESC")
        .bind(id)
        .fetch_all(&state.db)
        .await?;
    Ok(Json(rows))
}

#[derive(Deserialize)]
pub struct VaccineInput {
    name: String,
    applied_on: String,
    next_due: Option<String>,
}

pub async fn add_vaccine(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<VaccineInput>,
) -> AppResult<Json<Value>> {
    find_own_dog(&state.db, id, user.id).await?;
    let name = required(&input.name, "vacina")?;
    let applied = rules::parse_date(&input.applied_on).ok_or_else(|| AppError::bad("Data de aplicação inválida"))?;
    if applied > today() {
        return Err(AppError::bad("A data de aplicação não pode ser no futuro"));
    }
    let next_due = input.next_due.filter(|s| !s.trim().is_empty());
    if let Some(n) = &next_due {
        let due = rules::parse_date(n).ok_or_else(|| AppError::bad("Data do reforço inválida"))?;
        if due <= applied {
            return Err(AppError::bad("O reforço precisa ser depois da aplicação"));
        }
    }
    sqlx::query("INSERT INTO vaccines (dog_id, name, applied_on, next_due) VALUES (?, ?, ?, ?)")
        .bind(id)
        .bind(&name)
        .bind(&input.applied_on)
        .bind(&next_due)
        .execute(&state.db)
        .await?;
    add_event(&state.db, id, "vacina", &format!("Vacina {name} aplicada em {}", input.applied_on)).await?;
    Ok(Json(json!({ "vaccine_status": super::vaccine_status_of(&state.db, id).await? })))
}

pub async fn delete_vaccine(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let row: Option<(i64,)> = sqlx::query_as("SELECT dog_id FROM vaccines WHERE id = ?")
        .bind(id)
        .fetch_optional(&state.db)
        .await?;
    let (dog_id,) = row.ok_or_else(|| AppError::not_found("Vacina não encontrada"))?;
    find_own_dog(&state.db, dog_id, user.id).await?;
    sqlx::query("DELETE FROM vaccines WHERE id = ?").bind(id).execute(&state.db).await?;
    Ok(Json(json!({ "ok": true })))
}

// ---------- carteira digital: documentos ----------

#[derive(FromRow, Serialize)]
pub struct DocumentRow {
    id: i64,
    kind: String,
    title: String,
    file_url: String,
    status: String,
    created_at: String,
}

/// Documentos só aparecem para o dono (são dados de saúde); para os outros, só o selo de pedigree.
pub async fn list_documents(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
) -> AppResult<Json<Vec<DocumentRow>>> {
    let dog = find_dog(&state.db, id).await?;
    if dog.owner_id != user.id && !user.is_admin {
        return Ok(Json(vec![]));
    }
    let rows = sqlx::query_as(
        "SELECT id, kind, title, file_url, status, created_at FROM dog_documents WHERE dog_id = ? ORDER BY id DESC",
    )
    .bind(id)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

#[derive(Deserialize)]
pub struct DocumentInput {
    kind: String,
    title: String,
    file_url: String,
}

pub async fn add_document(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<DocumentInput>,
) -> AppResult<Json<Value>> {
    find_own_dog(&state.db, id, user.id).await?;
    if !["pedigree", "exame", "rg", "receita", "outro"].contains(&input.kind.as_str()) {
        return Err(AppError::bad("Tipo de documento inválido"));
    }
    if !input.file_url.starts_with("/uploads/") {
        return Err(AppError::bad("Envie o arquivo antes"));
    }
    sqlx::query("INSERT INTO dog_documents (dog_id, kind, title, file_url) VALUES (?, ?, ?, ?)")
        .bind(id)
        .bind(&input.kind)
        .bind(required(&input.title, "título")?)
        .bind(&input.file_url)
        .execute(&state.db)
        .await?;
    if input.kind == "pedigree" {
        add_event(&state.db, id, "pedigree", "Pedigree enviado para verificação").await?;
    }
    Ok(Json(json!({ "ok": true })))
}

pub async fn delete_document(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let row: Option<(i64,)> = sqlx::query_as("SELECT dog_id FROM dog_documents WHERE id = ?")
        .bind(id)
        .fetch_optional(&state.db)
        .await?;
    let (dog_id,) = row.ok_or_else(|| AppError::not_found("Documento não encontrado"))?;
    find_own_dog(&state.db, dog_id, user.id).await?;
    sqlx::query("DELETE FROM dog_documents WHERE id = ?").bind(id).execute(&state.db).await?;
    Ok(Json(json!({ "ok": true })))
}
