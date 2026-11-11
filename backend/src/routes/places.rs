use axum::{
    extract::{Query, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;

use super::required;
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    rules, AppState,
};

#[derive(FromRow, Serialize)]
pub struct Place {
    id: i64,
    name: String,
    kind: String,
    address: String,
    lat: f64,
    lng: f64,
    #[sqlx(skip)]
    distance_m: i64,
}

#[derive(Deserialize)]
pub struct NearbyQuery {
    lat: Option<f64>,
    lng: Option<f64>,
    limit: Option<i64>,
}

/// Parques e pontos de encontro mais próximos (5 por padrão).
/// Usa a posição enviada na URL ou, se não houver, a última posição do usuário.
pub async fn nearby(State(state): State<AppState>, user: AuthUser, Query(q): Query<NearbyQuery>) -> AppResult<Json<Vec<Place>>> {
    let (Some(lat), Some(lng)) = (q.lat.or(user.lat), q.lng.or(user.lng)) else {
        return Err(AppError::bad("Ative a localização para ver os parques próximos"));
    };
    let mut places: Vec<Place> = sqlx::query_as("SELECT id, name, kind, address, lat, lng FROM places")
        .fetch_all(&state.db)
        .await?;
    for p in &mut places {
        p.distance_m = rules::distance_m(lat, lng, p.lat, p.lng).round() as i64;
    }
    places.sort_by_key(|p| p.distance_m);
    places.truncate(q.limit.unwrap_or(rules::DEFAULT_PLACES).clamp(1, 50) as usize);
    Ok(Json(places))
}

#[derive(Deserialize)]
pub struct PlaceInput {
    name: String,
    kind: String,
    #[serde(default)]
    address: String,
    lat: f64,
    lng: f64,
}

/// Qualquer dono pode sugerir um novo ponto de encontro.
pub async fn create(State(state): State<AppState>, user: AuthUser, Json(input): Json<PlaceInput>) -> AppResult<Json<Value>> {
    if !["parque", "praca", "ponto_encontro"].contains(&input.kind.as_str()) {
        return Err(AppError::bad("Tipo deve ser parque, praca ou ponto_encontro"));
    }
    let id = sqlx::query("INSERT INTO places (name, kind, address, lat, lng, created_by) VALUES (?, ?, ?, ?, ?, ?)")
        .bind(required(&input.name, "nome")?)
        .bind(&input.kind)
        .bind(input.address.trim())
        .bind(input.lat)
        .bind(input.lng)
        .bind(user.id)
        .execute(&state.db)
        .await?
        .last_insert_rowid();
    Ok(Json(json!({ "id": id })))
}

/// Um anúncio de patrocinador ao acaso. Usuários premium não veem anúncios.
pub async fn random_ad(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Value>> {
    if user.is_premium {
        return Ok(Json(json!({ "ad": null })));
    }
    let ad: Option<(i64, String, String, String)> =
        sqlx::query_as("SELECT id, sponsor, message, link FROM ads ORDER BY RANDOM() LIMIT 1")
            .fetch_optional(&state.db)
            .await?;
    Ok(Json(json!({
        "ad": ad.map(|(id, sponsor, message, link)| json!({ "id": id, "sponsor": sponsor, "message": message, "link": link }))
    })))
}
