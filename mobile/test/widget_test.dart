import 'package:alllove/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata datas e distâncias', () {
    expect(formatDate('2026-01-31'), '31/01/2026');
    expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
    expect(formatDistance(450), '450 m');
    expect(formatDistance(1500), '1.5 km');
    expect(formatPrice(8990), 'R\$ 89,90');
    expect(formatPrice(123456), 'R\$ 1.234,56');
    expect(formatPrice(8990), 'R\$ 89,90');
    expect(formatPrice(123456), 'R\$ 1.234,56');
  });

  test('lê o cão vindo da API', () {
    final dog = Dog.fromJson({
      'id': 1,
      'owner_id': 2,
      'name': 'Mel',
      'breed': 'Shih Tzu',
      'birth_date': '2021-03-15',
      'sex': 'femea',
      'in_heat': false,
      'temperament': 'calmo',
      'bites': false,
      'likes': 'bolinha',
      'dislikes': 'chinelo',
      'photo_url': null,
      'removed_at': null,
      'age_years': 5,
      'vaccine_status': {
        'up_to_date': false,
        'missing': [],
        'overdue': ['V8'],
      },
    });
    expect(dog.ageText, '5 anos');
    expect(dog.vaccineStatus.description, 'Atrasadas: V8');
  });
}
