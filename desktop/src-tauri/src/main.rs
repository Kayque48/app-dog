// Esconde a janela de console no Windows em modo release.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    alllove_desktop_lib::run()
}
