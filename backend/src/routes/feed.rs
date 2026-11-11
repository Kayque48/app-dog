use axum::{
    extract::{Multipart, Path, Query, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;

use super::find_own_dog;
use crate::{
    auth::AuthUser,
    error::{AppError, AppResult},
    AppState,
};

/// Recebe uma imagem (campo `file`) e devolve a URL pública dela.
pub async fn upload(State(state): State<AppState>, _user: AuthUser, mut multipart: Multipart) -> AppResult<Json<Value>> {
    while let Some(field) = multipart.next_field().await.map_err(|e| AppError::bad(e.to_string()))? {
        if field.name() != Some("file") {
            continue;
        }
        // Alguns clientes mandam application/octet-stream; nesse caso usamos a extensão do nome.
        let from_type = field.content_type().and_then(|t| t.strip_prefix("image/")).map(str::to_lowercase);
        let from_name = field.file_name().and_then(|n| n.rsplit('.').next()).map(str::to_lowercase);
        let ext = match from_type.or(from_name).as_deref() {
            Some("jpeg" | "jpg") => "jpg",
            Some("png") => "png",
            Some("webp") => "webp",
            Some("gif") => "gif",
            _ => return Err(AppError::bad("Envie uma imagem JPG, PNG, WEBP ou GIF")),
        };
        let bytes = field.bytes().await.map_err(|e| AppError::bad(e.to_string()))?;
        if bytes.len() > 5 * 1024 * 1024 {
            return Err(AppError::bad("Imagem muito grande (máximo 5 MB)"));
        }
        let file_name = format!("{}.{ext}", uuid::Uuid::new_v4());
        tokio::fs::write(state.upload_dir.join(&file_name), &bytes)
            .await
            .map_err(|e| AppError::Internal(e.to_string()))?;
        return Ok(Json(json!({ "url": format!("/uploads/{file_name}") })));
    }
    Err(AppError::bad("Nenhum arquivo enviado (campo 'file')"))
}

#[derive(FromRow, Serialize)]
pub struct PostRow {
    id: i64,
    image_url: String,
    caption: String,
    created_at: String,
    dog_id: i64,
    dog_name: String,
    dog_breed: String,
    dog_photo_url: Option<String>,
    owner_id: i64,
    likes: i64,
    liked_by_me: bool,
}

#[derive(Deserialize)]
pub struct FeedQuery {
    page: Option<i64>,
}

/// Feed de fotos, mais recentes primeiro, 20 por página.
pub async fn feed(State(state): State<AppState>, user: AuthUser, Query(q): Query<FeedQuery>) -> AppResult<Json<Vec<PostRow>>> {
    let page = q.page.unwrap_or(0).max(0);
    let rows = sqlx::query_as(
        "SELECT p.id, p.image_url, p.caption, p.created_at,
                d.id AS dog_id, d.name AS dog_name, d.breed AS dog_breed, d.photo_url AS dog_photo_url,
                d.owner_id,
                (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id) AS likes,
                EXISTS (SELECT 1 FROM post_likes l WHERE l.post_id = p.id AND l.user_id = ?) AS liked_by_me
         FROM posts p
         JOIN dogs d ON d.id = p.dog_id
         JOIN users u ON u.id = d.owner_id
         WHERE u.banned_at IS NULL AND u.deleted_at IS NULL AND d.removed_at IS NULL
         ORDER BY p.id DESC LIMIT 20 OFFSET ?",
    )
    .bind(user.id)
    .bind(page * 20)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

#[derive(Deserialize)]
pub struct PostInput {
    dog_id: i64,
    image_url: String,
    #[serde(default)]
    caption: String,
}

pub async fn create_post(State(state): State<AppState>, user: AuthUser, Json(input): Json<PostInput>) -> AppResult<Json<Value>> {
    find_own_dog(&state.db, input.dog_id, user.id).await?;
    if !input.image_url.starts_with("/uploads/") {
        return Err(AppError::bad("Envie a foto antes de publicar"));
    }
    let id = sqlx::query("INSERT INTO posts (dog_id, image_url, caption) VALUES (?, ?, ?)")
        .bind(input.dog_id)
        .bind(&input.image_url)
        .bind(input.caption.trim())
        .execute(&state.db)
        .await?
        .last_insert_rowid();
    Ok(Json(json!({ "id": id })))
}

pub async fn delete_post(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let row: Option<(i64,)> = sqlx::query_as(
        "SELECT d.owner_id FROM posts p JOIN dogs d ON d.id = p.dog_id WHERE p.id = ?",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?;
    let (owner,) = row.ok_or_else(|| AppError::not_found("Publicação não encontrada"))?;
    if owner != user.id && !user.is_admin {
        return Err(AppError::forbidden("Você só pode apagar suas publicações"));
    }
    sqlx::query("DELETE FROM post_likes WHERE post_id = ?").bind(id).execute(&state.db).await?;
    sqlx::query("DELETE FROM posts WHERE id = ?").bind(id).execute(&state.db).await?;
    Ok(Json(json!({ "ok": true })))
}

/// Curte ou descurte uma publicação.
pub async fn toggle_like(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let removed = sqlx::query("DELETE FROM post_likes WHERE post_id = ? AND user_id = ?")
        .bind(id)
        .bind(user.id)
        .execute(&state.db)
        .await?
        .rows_affected();
    if removed == 0 {
        sqlx::query("INSERT INTO post_likes (post_id, user_id) SELECT id, ? FROM posts WHERE id = ?")
            .bind(user.id)
            .bind(id)
            .execute(&state.db)
            .await?;
    }
    let (likes,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM post_likes WHERE post_id = ?")
        .bind(id)
        .fetch_one(&state.db)
        .await?;
    Ok(Json(json!({ "liked": removed == 0, "likes": likes })))
}
