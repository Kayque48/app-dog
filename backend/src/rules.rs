//! Regras de negócio puras (sem banco de dados), fáceis de testar.

use chrono::NaiveDate;
use serde::Serialize;

/// Raio padrão do Descobrir, pedido pelo cliente: 500 metros.
pub const DEFAULT_RADIUS_M: f64 = 500.0;
/// Quantidade de pontos de encontro exibidos ("cinco pontos de encontro").
pub const DEFAULT_PLACES: i64 = 5;

/// Vacinas obrigatórias para o cão poder usar o Descobrir.
/// Cada item é uma lista de nomes aceitos (V8 ou V10 valem como polivalente).
pub const REQUIRED_VACCINES: &[(&str, &[&str])] = &[
    ("Polivalente (V8 ou V10)", &["V8", "V10"]),
    ("Antirrábica", &["Antirrábica"]),
];

/// Motivos de denúncia citados na entrevista.
pub const REPORT_REASONS: &[&str] = &[
    "obscenidade",
    "perfil_falso",
    "pede_localizacao",
    "agressividade",
    "informacao_falsa",
    "processo_judicial",
    "outro",
];

/// Valida um CPF pelos dígitos verificadores. Aceita com ou sem pontuação.
/// Devolve o CPF só com números quando é válido.
pub fn normalize_cpf(input: &str) -> Option<String> {
    let digits: Vec<u32> = input.chars().filter_map(|c| c.to_digit(10)).collect();
    if digits.len() != 11 || digits.iter().all(|&d| d == digits[0]) {
        return None;
    }
    let check = |len: usize| {
        let sum: u32 = digits[..len]
            .iter()
            .enumerate()
            .map(|(i, d)| d * (len as u32 + 1 - i as u32))
            .sum();
        let rest = (sum * 10) % 11;
        if rest == 10 { 0 } else { rest }
    };
    if check(9) != digits[9] || check(10) != digits[10] {
        return None;
    }
    Some(digits.iter().map(|d| char::from_digit(*d, 10).unwrap()).collect())
}

/// Telefone brasileiro com DDD: 10 ou 11 dígitos.
pub fn normalize_phone(input: &str) -> Option<String> {
    let digits: String = input.chars().filter(|c| c.is_ascii_digit()).collect();
    (digits.len() == 10 || digits.len() == 11).then_some(digits)
}

/// CEP com 8 dígitos.
pub fn normalize_cep(input: &str) -> Option<String> {
    let digits: String = input.chars().filter(|c| c.is_ascii_digit()).collect();
    (digits.len() == 8).then_some(digits)
}

/// Distância em metros entre dois pontos (fórmula de Haversine).
pub fn distance_m(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    const R: f64 = 6_371_000.0;
    let (p1, p2) = (lat1.to_radians(), lat2.to_radians());
    let dp = (lat2 - lat1).to_radians();
    let dl = (lng2 - lng1).to_radians();
    let a = (dp / 2.0).sin().powi(2) + p1.cos() * p2.cos() * (dl / 2.0).sin().powi(2);
    2.0 * R * a.sqrt().asin()
}

/// Idade em anos completos.
pub fn age_years(birth: NaiveDate, today: NaiveDate) -> i64 {
    use chrono::Datelike;
    let mut age = today.year() - birth.year();
    if (today.month(), today.day()) < (birth.month(), birth.day()) {
        age -= 1;
    }
    age.max(0) as i64
}

pub fn parse_date(s: &str) -> Option<NaiveDate> {
    NaiveDate::parse_from_str(s, "%Y-%m-%d").ok()
}

/// Registro de vacina usado no cálculo da situação vacinal.
pub struct VaccineRecord<'a> {
    pub name: &'a str,
    pub applied_on: &'a str,
    pub next_due: Option<&'a str>,
}

#[derive(Debug, Serialize, PartialEq)]
pub struct VaccineStatus {
    /// `true` quando não há vacina obrigatória faltando nem vacina atrasada.
    pub up_to_date: bool,
    pub missing: Vec<String>,
    pub overdue: Vec<String>,
}

/// Calcula se a carteira de vacinação está em dia.
/// Para cada vacina vale o registro mais recente: se a data do reforço já passou, está atrasada.
pub fn vaccine_status(records: &[VaccineRecord], today: NaiveDate) -> VaccineStatus {
    use std::collections::BTreeMap;

    let mut latest: BTreeMap<String, &VaccineRecord> = BTreeMap::new();
    for r in records {
        let key = r.name.to_lowercase();
        match latest.get(&key) {
            Some(cur) if cur.applied_on >= r.applied_on => {}
            _ => {
                latest.insert(key, r);
            }
        }
    }

    let overdue: Vec<String> = latest
        .values()
        .filter(|r| r.next_due.and_then(parse_date).is_some_and(|d| d < today))
        .map(|r| r.name.to_string())
        .collect();

    let missing: Vec<String> = REQUIRED_VACCINES
        .iter()
        .filter(|(_, accepted)| !accepted.iter().any(|n| latest.contains_key(&n.to_lowercase())))
        .map(|(label, _)| label.to_string())
        .collect();

    VaccineStatus { up_to_date: missing.is_empty() && overdue.is_empty(), missing, overdue }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn d(s: &str) -> NaiveDate {
        parse_date(s).unwrap()
    }

    #[test]
    fn cpf() {
        assert_eq!(normalize_cpf("529.982.247-25").as_deref(), Some("52998224725"));
        assert_eq!(normalize_cpf("52998224724"), None);
        assert_eq!(normalize_cpf("111.111.111-11"), None);
        assert_eq!(normalize_cpf("123"), None);
    }

    #[test]
    fn phone_and_cep() {
        assert_eq!(normalize_phone("(11) 98765-4321").as_deref(), Some("11987654321"));
        assert_eq!(normalize_phone("98765-4321"), None);
        assert_eq!(normalize_cep("01310-100").as_deref(), Some("01310100"));
    }

    #[test]
    fn distance() {
        // Parque Ibirapuera -> MASP: aproximadamente 3 km.
        let m = distance_m(-23.5874, -46.6576, -23.5614, -46.6559);
        assert!((2800.0..3100.0).contains(&m), "{m}");
        assert!(distance_m(-23.5, -46.6, -23.5, -46.6) < 0.001);
    }

    #[test]
    fn age() {
        assert_eq!(age_years(d("2020-06-10"), d("2026-06-09")), 5);
        assert_eq!(age_years(d("2020-06-10"), d("2026-06-10")), 6);
    }

    #[test]
    fn vaccines() {
        let today = d("2026-11-11");
        let ok = [
            VaccineRecord { name: "V10", applied_on: "2026-01-10", next_due: Some("2027-01-10") },
            VaccineRecord { name: "Antirrábica", applied_on: "2026-01-10", next_due: Some("2027-01-10") },
        ];
        assert!(vaccine_status(&ok, today).up_to_date);

        let late = [
            VaccineRecord { name: "V8", applied_on: "2024-01-10", next_due: Some("2025-01-10") },
            VaccineRecord { name: "Antirrábica", applied_on: "2026-01-10", next_due: None },
        ];
        let s = vaccine_status(&late, today);
        assert!(!s.up_to_date);
        assert_eq!(s.overdue, vec!["V8"]);
        assert!(s.missing.is_empty());

        // Um reforço mais novo substitui o registro antigo atrasado.
        let renewed = [
            VaccineRecord { name: "V8", applied_on: "2024-01-10", next_due: Some("2025-01-10") },
            VaccineRecord { name: "V8", applied_on: "2026-02-01", next_due: Some("2027-02-01") },
            VaccineRecord { name: "Antirrábica", applied_on: "2026-01-10", next_due: None },
        ];
        assert!(vaccine_status(&renewed, today).up_to_date);

        let s = vaccine_status(&[], today);
        assert_eq!(s.missing.len(), 2);
    }
}
