import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/services/opening_hours.dart';

void main() {
  group('OpeningHours.parse', () {
    test('24/7 her zaman açıktır', () {
      final hours = OpeningHours.parse('24/7');

      expect(hours, isNotNull);
      expect(hours!.isOpenAt(DateTime(2026, 3, 2, 3, 15)), isTrue);
      expect(hours.isOpenAt(DateTime(2026, 3, 7, 23, 59)), isTrue);
    });

    test('hafta içi aralığı doğru uygular', () {
      final hours = OpeningHours.parse('Mo-Fr 09:00-18:00');

      expect(hours, isNotNull);
      // 2 Mart 2026 Pazartesi
      expect(hours!.isOpenAt(DateTime(2026, 3, 2, 8, 59)), isFalse);
      expect(hours.isOpenAt(DateTime(2026, 3, 2, 9, 0)), isTrue);
      expect(hours.isOpenAt(DateTime(2026, 3, 2, 17, 59)), isTrue);
      expect(hours.isOpenAt(DateTime(2026, 3, 2, 18, 0)), isFalse);
      // 8 Mart 2026 Pazar
      expect(hours.isOpenAt(DateTime(2026, 3, 8, 12, 0)), isFalse);
    });

    test('kapalı günleri ve çoklu aralıkları okur', () {
      final hours = OpeningHours.parse(
        'Mo,We,Fr 09:00-12:00,13:00-17:00; Sa 10:00-14:00; Su off',
      );

      expect(hours, isNotNull);
      // 2 Mart Pazartesi
      expect(hours!.isOpenAt(DateTime(2026, 3, 2, 12, 30)), isFalse);
      expect(hours.isOpenAt(DateTime(2026, 3, 2, 13, 30)), isTrue);
      // 3 Mart Salı belirtilmemiş -> kapalı
      expect(hours.isOpenAt(DateTime(2026, 3, 3, 10, 0)), isFalse);
      // 7 Mart Cumartesi
      expect(hours.isOpenAt(DateTime(2026, 3, 7, 10, 0)), isTrue);
      // 8 Mart Pazar
      expect(hours.isOpenAt(DateTime(2026, 3, 8, 10, 0)), isFalse);
    });

    test('gün belirtilmemiş aralığı tüm günlere uygular', () {
      final hours = OpeningHours.parse('09:00-17:00');

      expect(hours, isNotNull);
      expect(hours!.isOpenAt(DateTime(2026, 3, 2, 10, 0)), isTrue);
      expect(hours.isOpenAt(DateTime(2026, 3, 8, 10, 0)), isTrue);
    });

    test('boş veya ayrıştırılamayan değerlerde null döner', () {
      expect(OpeningHours.parse(null), isNull);
      expect(OpeningHours.parse(''), isNull);
      expect(OpeningHours.parse('yalnızca randevu ile'), isNull);
      expect(OpeningHours.parse('Mo-Fr sunrise-sunset'), isNull);
    });
  });
}
