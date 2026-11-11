import 'package:flutter/material.dart';

/// Textos exibidos para os valores usados pela API.
const temperaments = {
  'calmo': 'Calmo / mansinho',
  'brincalhao': 'Brincalhão',
  'timido': 'Tímido',
  'agressivo': 'Agressivo',
};

const sexes = {'macho': 'Macho', 'femea': 'Fêmea'};

const reportReasons = {
  'obscenidade': 'Obscenidade',
  'perfil_falso': 'Perfil falso / se passando por outra pessoa',
  'pede_localizacao': 'Pedindo localização ou dados pessoais',
  'agressividade': 'Cão agressivo / mordeu',
  'informacao_falsa': 'Informações falsas sobre o cão',
  'processo_judicial': 'Dono em processo judicial envolvendo animais',
  'outro': 'Outro',
};

const vaccineNames = ['V8', 'V10', 'Antirrábica', 'Gripe canina', 'Giárdia', 'Leishmaniose'];

const placeKinds = {'parque': 'Parque', 'praca': 'Praça', 'ponto_encontro': 'Ponto de encontro'};

class VaccineStatus {
  VaccineStatus.fromJson(Map<String, dynamic> j)
    : upToDate = j['up_to_date'],
      missing = List<String>.from(j['missing']),
      overdue = List<String>.from(j['overdue']);

  final bool upToDate;
  final List<String> missing;
  final List<String> overdue;

  String get description {
    if (upToDate) return 'Vacinação em dia';
    return [
      if (overdue.isNotEmpty) 'Atrasadas: ${overdue.join(', ')}',
      if (missing.isNotEmpty) 'Faltando: ${missing.join(', ')}',
    ].join(' • ');
  }
}

class Dog {
  Dog.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      ownerId = j['owner_id'],
      name = j['name'],
      breed = j['breed'],
      birthDate = j['birth_date'],
      sex = j['sex'],
      inHeat = j['in_heat'],
      temperament = j['temperament'],
      bites = j['bites'],
      likes = j['likes'],
      dislikes = j['dislikes'],
      photoUrl = j['photo_url'],
      removed = j['removed_at'] != null,
      ageYears = j['age_years'],
      vaccineStatus = VaccineStatus.fromJson(j['vaccine_status']),
      weightKg = (j['weight_kg'] as num?)?.toDouble(),
      color = j['color'] ?? '',
      bio = j['bio'] ?? '',
      activityLevel = j['activity_level'] ?? 'medio',
      lookingFor = j['looking_for'] ?? 'amizade',
      microchip = j['microchip'] ?? '',
      neutered = j['neutered'] ?? false,
      allergies = j['allergies'] ?? '',
      healthNotes = j['health_notes'] ?? '',
      pedigreeVerified = j['pedigree_verified'] ?? false,
      distanceM = j['distance_m'],
      ownerFirstName = j['owner_first_name'],
      wantsToMeetYou = j['wants_to_meet_you'] ?? false;

  final int id;
  final int ownerId;
  final String name;
  final String breed;
  final String birthDate;
  final String sex;
  final bool inHeat;
  final String temperament;
  final bool bites;
  final String likes;
  final String dislikes;
  final String? photoUrl;
  final bool removed;
  final int ageYears;
  final VaccineStatus vaccineStatus;
  final double? weightKg;
  final String color;
  final String bio;
  final String activityLevel;
  final String lookingFor;
  final String microchip;
  final bool neutered;
  final String allergies;
  final String healthNotes;
  final bool pedigreeVerified;

  // Só preenchidos no Descobrir.
  final int? distanceM;
  final String? ownerFirstName;
  final bool wantsToMeetYou;

  String get ageText => ageYears == 1 ? '1 ano' : (ageYears == 0 ? 'Filhote' : '$ageYears anos');

  Map<String, dynamic> toJson() => {
    'name': name,
    'breed': breed,
    'birth_date': birthDate,
    'sex': sex,
    'in_heat': inHeat,
    'temperament': temperament,
    'bites': bites,
    'likes': likes,
    'dislikes': dislikes,
    'photo_url': photoUrl,
    'weight_kg': weightKg,
    'color': color,
    'bio': bio,
    'activity_level': activityLevel,
    'looking_for': lookingFor,
    'microchip': microchip,
    'neutered': neutered,
    'allergies': allergies,
    'health_notes': healthNotes,
  };
}

String formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  return km == km.roundToDouble() ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
}

/// "2026-01-31" -> "31/01/2026"
String formatDate(String? iso) {
  if (iso == null || iso.length < 10) return iso ?? '';
  final p = iso.substring(0, 10).split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------- eventos ----------

const eventKinds = {
  'desfile': ('Desfile', Icons.checkroom),
  'corrida': ('Corrida', Icons.directions_run),
  'festa': ('Festa', Icons.celebration),
  'encontro': ('Encontro', Icons.groups),
  'concurso': ('Concurso', Icons.emoji_events),
  'adocao': ('Adoção', Icons.volunteer_activism),
  'competicao': ('Competição', Icons.fitness_center),
};

const _week = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
const _month = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];

/// Data de um evento ("2026-11-14 15:00") em pedaços para os cartões.
class EventDate {
  EventDate(String startsAt) : _d = DateTime.parse(startsAt.replaceFirst(' ', 'T'));
  final DateTime _d;

  String get week => _week[_d.weekday - 1];
  String get day => _d.day.toString().padLeft(2, '0');
  String get month => _month[_d.month - 1];
  String get time => '${_d.hour.toString().padLeft(2, '0')}:${_d.minute.toString().padLeft(2, '0')}';

  int get daysLeft {
    final now = DateTime.now();
    return DateTime(_d.year, _d.month, _d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  String get countdown => daysLeft <= 0 ? 'hoje!' : (daysLeft == 1 ? 'amanhã' : 'em $daysLeft dias');
  bool get soon => daysLeft <= 2;
}

// ---------- perfil, carteira, serviços e loja ----------

const activityLevels = {'baixo': 'Sossegado', 'medio': 'Moderado', 'alto': 'Elétrico'};
const lookingForLabels = {'amizade': 'Amizade', 'cruzamento': 'Cruzamento', 'ambos': 'Amizade e cruzamento'};
const docKinds = {'pedigree': 'Pedigree', 'exame': 'Exame', 'rg': 'RG animal', 'receita': 'Receita', 'outro': 'Outro'};

const providerKinds = {
  'veterinario': ('Veterinários', Icons.medical_services),
  'banho_tosa': ('Banho e tosa', Icons.shower),
  'pet_shop': ('Pet shops', Icons.storefront),
  'adestrador': ('Adestradores', Icons.school),
  'passeador': ('Passeadores', Icons.directions_walk),
  'hotel': ('Hotéis e creches', Icons.hotel),
  'criador': ('Criadores', Icons.workspace_premium),
  'adocao': ('Adoção', Icons.volunteer_activism),
};

const productCategories = {
  'roupas': ('Roupas', Icons.checkroom),
  'alimentos': ('Alimentos', Icons.restaurant),
  'brinquedos': ('Brinquedos', Icons.sports_baseball),
  'acessorios': ('Acessórios', Icons.pets),
  'higiene': ('Higiene', Icons.soap),
};

/// 8990 -> "R$ 89,90"
String formatPrice(int cents) {
  final reais = cents ~/ 100;
  final centavos = (cents % 100).toString().padLeft(2, '0');
  final milhar = reais.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return 'R\$ $milhar,$centavos';
}
