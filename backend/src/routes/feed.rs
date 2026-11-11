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

/// Recebe uma imagem, vídeo ou PDF (campo `file`) e devolve a URL pública dele.
pub async fn upload(State(state): State<AppState>, _user: AuthUser, mut multipart: Multipart) -> AppResult<Json<Value>> {
    while let Some(field) = multipart.next_field().await.map_err(|e| AppError::bad(e.to_string()))? {
        if field.name() != Some("file") {
            continue;
        }
        // Alguns clientes mandam application/octet-stream; nesse caso usamos a extensão do nome.
        let from_type = field
            .content_type()
            .and_then(|t| t.split_once('/'))
            .map(|(_, sub)| sub.to_lowercase())
            .filter(|s| s != "octet-stream");
        let from_name = field.file_name().and_then(|n| n.rsplit('.').next()).map(str::to_lowercase);
        // (extensão, limite em MB)
        let (ext, max_mb) = match from_type.or(from_name).as_deref() {
            Some("jpeg" | "jpg") => ("jpg", 5),
            Some("png") => ("png", 5),
            Some("webp") => ("webp", 5),
            Some("gif") => ("gif", 5),
            Some("mp4") => ("mp4", 25),
            Some("webm") => ("webm", 25),
            Some("quicktime" | "mov") => ("mov", 25),
            Some("pdf") => ("pdf", 10),
            _ => return Err(AppError::bad("Envie uma imagem (JPG, PNG, WEBP, GIF), vídeo (MP4, WEBM, MOV) ou PDF")),
        };
        let bytes = field.bytes().await.map_err(|e| AppError::bad(e.to_string()))?;
        if bytes.len() > max_mb * 1024 * 1024 {
            return Err(AppError::bad(format!("Arquivo muito grande (máximo {max_mb} MB)")));
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
    media_type: String,
    caption: String,
    created_at: String,
    dog_id: i64,
    dog_name: String,
    dog_breed: String,
    dog_photo_url: Option<String>,
    owner_id: i64,
    likes: i64,
    liked_by_me: bool,
    comments: i64,
}

#[derive(Deserialize)]
pub struct FeedQuery {
    page: Option<i64>,
}

/// Feed de fotos, mais recentes primeiro, 20 por página.
pub async fn feed(State(state): State<AppState>, user: AuthUser, Query(q): Query<FeedQuery>) -> AppResult<Json<Vec<PostRow>>> {
    let page = q.page.unwrap_or(0).max(0);
    let rows = sqlx::query_as(
        "SELECT p.id, p.image_url, p.media_type, p.caption, p.created_at,
                d.id AS dog_id, d.name AS dog_name, d.breed AS dog_breed, d.photo_url AS dog_photo_url,
                d.owner_id,
                (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id) AS likes,
                EXISTS (SELECT 1 FROM post_likes l WHERE l.post_id = p.id AND l.user_id = ?) AS liked_by_me,
                (SELECT COUNT(*) FROM post_comments c WHERE c.post_id = p.id) AS comments
         FROM posts p
         JOIN dogs d ON d.id = p.dog_id
         JOIN users u ON u.id = d.owner_id
         WHERE u.banned_at IS NULL AND u.deleted_at IS NULL AND d.removed_at IS NULL
         ORDER BY p.created_at DESC, p.id DESC LIMIT 20 OFFSET ?",
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
        return Err(AppError::bad("Envie a foto ou o vídeo antes de publicar"));
    }
    let lower = input.image_url.to_lowercase();
    let media_type = if [".mp4", ".webm", ".mov"].iter().any(|e| lower.ends_with(e)) {
        "video"
    } else if lower.ends_with(".pdf") {
        return Err(AppError::bad("Publique uma foto ou um vídeo"));
    } else {
        "image"
    };
    let id = sqlx::query("INSERT INTO posts (dog_id, image_url, media_type, caption) VALUES (?, ?, ?, ?)")
        .bind(input.dog_id)
        .bind(&input.image_url)
        .bind(media_type)
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
    sqlx::query("DELETE FROM post_comments WHERE post_id = ?").bind(id).execute(&state.db).await?;
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

// ---------- comentários ----------

#[derive(FromRow, Serialize)]
pub struct CommentRow {
    id: i64,
    text: String,
    created_at: String,
    user_id: i64,
    author: String,
    /// foto do primeiro cão do autor, para o avatar
    author_photo: Option<String>,
}

pub async fn list_comments(State(state): State<AppState>, _user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Vec<CommentRow>>> {
    let mut rows: Vec<CommentRow> = sqlx::query_as(
        "SELECT c.id, c.text, c.created_at, u.id AS user_id, u.name AS author,
                (SELECT d.photo_url FROM dogs d WHERE d.owner_id = u.id AND d.removed_at IS NULL ORDER BY d.id LIMIT 1) AS author_photo
         FROM post_comments c JOIN users u ON u.id = c.user_id
         WHERE c.post_id = ? AND u.banned_at IS NULL AND u.deleted_at IS NULL
         ORDER BY c.id",
    )
    .bind(id)
    .fetch_all(&state.db)
    .await?;
    for r in &mut rows {
        r.author = super::first_name(&r.author);
    }
    Ok(Json(rows))
}

#[derive(Deserialize)]
pub struct CommentInput {
    text: String,
}

pub async fn add_comment(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<i64>,
    Json(input): Json<CommentInput>,
) -> AppResult<Json<Value>> {
    let text = super::required(&input.text, "comentário")?;
    if text.chars().count() > 500 {
        return Err(AppError::bad("Comentário muito longo (máximo 500 caracteres)"));
    }
    let added = sqlx::query("INSERT INTO post_comments (post_id, user_id, text) SELECT id, ?, ? FROM posts WHERE id = ?")
        .bind(user.id)
        .bind(&text)
        .bind(id)
        .execute(&state.db)
        .await?
        .rows_affected();
    if added == 0 {
        return Err(AppError::not_found("Publicação não encontrada"));
    }
    Ok(Json(json!({ "ok": true })))
}

pub async fn delete_comment(State(state): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Value>> {
    let row: Option<(i64,)> = sqlx::query_as("SELECT user_id FROM post_comments WHERE id = ?")
        .bind(id)
        .fetch_optional(&state.db)
        .await?;
    let (author,) = row.ok_or_else(|| AppError::not_found("Comentário não encontrado"))?;
    if author != user.id && !user.is_admin {
        return Err(AppError::forbidden("Você só pode apagar seus comentários"));
    }
    sqlx::query("DELETE FROM post_comments WHERE id = ?").bind(id).execute(&state.db).await?;
    Ok(Json(json!({ "ok": true })))
}
