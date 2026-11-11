//! Autenticação por token (Bearer) e hash de senha com Argon2.

use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use axum::{extract::FromRequestParts, http::request::Parts};
use rand::RngCore;

use crate::{error::AppError, AppState};

pub fn hash_password(password: &str) -> String {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .expect("falha ao gerar hash")
        .to_string()
}

pub fn verify_password(password: &str, hash: &str) -> bool {
    PasswordHash::new(hash)
        .map(|h| Argon2::default().verify_password(password.as_bytes(), &h).is_ok())
        .unwrap_or(false)
}

pub fn new_token() -> String {
    let mut bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut bytes);
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

pub async fn create_session(state: &AppState, user_id: i64) -> Result<String, AppError> {
    let token = new_token();
    sqlx::query("INSERT INTO sessions (token, user_id) VALUES (?, ?)")
        .bind(&token)
        .bind(user_id)
        .execute(&state.db)
        .await?;
    Ok(token)
}

/// Usuário logado. Usar como parâmetro de um handler exige o header
/// `Authorization: Bearer <token>`. Contas bloqueadas são recusadas aqui.
pub struct AuthUser {
    pub id: i64,
    pub is_admin: bool,
    pub is_premium: bool,
    pub lat: Option<f64>,
    pub lng: Option<f64>,
}

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let token = parts
            .headers
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or_else(|| AppError::Unauthorized("Faça login para continuar".into()))?;

        let row: Option<(i64, bool, bool, Option<f64>, Option<f64>, Option<String>, Option<String>)> = sqlx::query_as(
            "SELECT u.id, u.is_admin, u.is_premium, u.lat, u.lng, u.banned_at, u.ban_reason
             FROM sessions s JOIN users u ON u.id = s.user_id
             WHERE s.token = ? AND u.deleted_at IS NULL",
        )
        .bind(token)
        .fetch_optional(&state.db)
        .await?;

        let (id, is_admin, is_premium, lat, lng, banned_at, ban_reason) =
            row.ok_or_else(|| AppError::Unauthorized("Sessão inválida, faça login novamente".into()))?;

        if banned_at.is_some() {
            return Err(AppError::forbidden(format!(
                "Conta bloqueada permanentemente. Motivo: {}",
                ban_reason.unwrap_or_default()
            )));
        }
        Ok(AuthUser { id, is_admin, is_premium, lat, lng })
    }
}

/// Igual a `AuthUser`, mas só aceita administradores (moderação).
pub struct AdminUser(pub AuthUser);

impl FromRequestParts<AppState> for AdminUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let user = AuthUser::from_request_parts(parts, state).await?;
        if !user.is_admin {
            return Err(AppError::forbidden("Apenas administradores"));
        }
        Ok(AdminUser(user))
    }
}
