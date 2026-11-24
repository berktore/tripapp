import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/services/place_scoring_service.dart';

void main() {
  const service = PlaceScoringService();

  test('kültür tarzı tarihî mekânı doğa mekânından yüksek puanlar', () {
    final museumScore = service.score(
      category: 'Müze',
      tags: const {'tourism': 'museum'},
      styles: const ['Kültür'],
      budget: 'Orta',
    );

    final parkScore = service.score(
      category: 'Park',
      tags: const {'leisure': 'park'},
      styles: const ['Kültür'],
      budget: 'Orta',
    );

    expect(museumScore, greaterThan(parkScore));
  });

  test('doğa tarzı park ve bahçeyi öne çıkarır', () {
    final parkScore = service.score(
      category: 'Park',
      tags: const {'leisure': 'park'},
      styles: const ['Doğa'],
      budget: 'Orta',
    );

    final museumScore = service.score(
      category: 'Müze',
      tags: const {'tourism': 'museum'},
      styles: const ['Doğa'],
      budget: 'Orta',
    );

    expect(parkScore, greaterThan(museumScore));
  });

  test('gastronomi tarzı restoranı kafeden yüksek puanlar', () {
    final restaurantScore = service.score(
      category: 'Restoran',
      tags: const {'amenity': 'restaurant'},
      styles: const ['Gastronomi'],
      budget: 'Orta',
    );

    final cafeScore = service.score(
      category: 'Kafe',
      tags: const {'amenity': 'cafe'},
      styles: const ['Gastronomi'],
      budget: 'Orta',
    );

    expect(restaurantScore, greaterThan(cafeScore));
  });

  test('bütçe tercihi puana yansır', () {
    final economicalPark = service.score(
      category: 'Park',
      tags: const {'leisure': 'park'},
      styles: const [],
      budget: 'Ekonomik',
    );

    final luxuriousPark = service.score(
      category: 'Park',
      tags: const {'leisure': 'park'},
      styles: const [],
      budget: 'Lüks',
    );

    expect(economicalPark, greaterThan(luxuriousPark));
  });

  test('gece hayatı tercihi barı öne çıkarır', () {
    final barScore = service.score(
      category: 'Gece Hayatı',
      tags: const {'amenity': 'bar'},
      styles: const ['Gece hayatı'],
      budget: 'Orta',
    );
    final museumScore = service.score(
      category: 'Müze',
      tags: const {'tourism': 'museum'},
      styles: const ['Gece hayatı'],
      budget: 'Orta',
    );

    expect(barScore, greaterThan(museumScore));
  });

  test('bilinmeyen kategori çökmez ve taban puan döner', () {
    final score = service.score(
      category: 'Bilinmeyen Tür',
      tags: const {},
      styles: const [],
      budget: 'Orta',
    );

    expect(score, greaterThan(0));
  });
}
