//! Casca nativa do app desktop. Toda a interface fica em Svelte (pasta `src/`)
//! e conversa direto com a API do All Love por HTTP.

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        // Abre links externos (mapa, WhatsApp) no navegador padrão.
        .plugin(tauri_plugin_opener::init())
        .run(tauri::generate_context!())
        .expect("erro ao iniciar o All Love");
}
