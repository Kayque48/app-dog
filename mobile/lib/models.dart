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
