/// OSM `opening_hours` etiketinin küçük ama işlevsel bir yorumlayıcısı.
///
/// Desteklenen biçimler:
/// - `24/7`
/// - `Mo-Fr 09:00-18:00`
/// - `Sa 10:00-14:00; Su off`
/// - `09:00-17:00` (tüm günler)
/// - `Mo,We,Fr 09:00-12:00,13:00-17:00`
///
/// Desteklenmeyen/ayrıştırılamayan değerlerde `null` döner; bu durumda
/// mekân "bilinmiyor" kabul edilir ve planlamadan çıkarılmaz.
class OpeningHours {
  OpeningHours._(this._rangesByWeekday);

  /// 1 = Pazartesi ... 7 = Pazar
  final Map<int, List<_TimeRange>> _rangesByWeekday;

  static const Map<String, int> _dayNames = {
    'mo': 1,
    'tu': 2,
    'we': 3,
    'th': 4,
    'fr': 5,
    'sa': 6,
    'su': 7,
  };

  static OpeningHours? parse(String? raw) {
    if (raw == null) return null;

    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;

    if (value.contains('24/7')) {
      return OpeningHours._({
        for (var day = 1; day <= 7; day++)
          day: const [_TimeRange(0, 24 * 60)],
      });
    }

    final ranges = <int, List<_TimeRange>>{};
    var parsedAnything = false;
    final timePattern = RegExp(
      r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})',
    );

    for (final rawRule in value.split(';')) {
      final rule = rawRule.trim();
      if (rule.isEmpty) continue;

      final firstToken = rule.split(RegExp(r'\s+')).first;
      final days = _parseDays(firstToken);
      final matches = timePattern.allMatches(rule).toList();

      if (matches.isEmpty) {
        if (rule.contains('off') || rule.contains('closed')) {
          for (final day in days) {
            ranges[day] = [];
            parsedAnything = true;
          }
        }
        continue;
      }

      for (final match in matches) {
        final start =
            int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
        final end =
            int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);

        if (end <= start) continue;

        for (final day in days) {
          final dayRanges = ranges.putIfAbsent(day, () => []);
          dayRanges.add(_TimeRange(start, end));
        }
        parsedAnything = true;
      }
    }

    if (!parsedAnything) return null;
    return OpeningHours._(ranges);
  }

  /// Belirtilen an açık mı?
  ///
  /// Gün hiç belirtilmemişse kapalı kabul edilir (OSM geleneği).
  bool isOpenAt(DateTime dateTime) {
    final ranges = _rangesByWeekday[dateTime.weekday];
    if (ranges == null || ranges.isEmpty) return false;

    final minutes = dateTime.hour * 60 + dateTime.minute;
    return ranges.any(
      (range) => minutes >= range.start && minutes < range.end,
    );
  }

  static List<int> _parseDays(String token) {
    final cleaned = token.replaceAll(RegExp(r'[^a-z,\-]'), '');
    if (cleaned.isEmpty) return const [1, 2, 3, 4, 5, 6, 7];

    final days = <int>{};

    for (final part in cleaned.split(',')) {
      if (part.contains('-')) {
        final ends = part.split('-');
        if (ends.length != 2) continue;

        final start = _dayNames[ends[0]];
        final end = _dayNames[ends[1]];
        if (start == null || end == null) continue;

        if (start <= end) {
          for (var day = start; day <= end; day++) {
            days.add(day);
          }
        } else {
          for (var day = start; day <= 7; day++) {
            days.add(day);
          }
          for (var day = 1; day <= end; day++) {
            days.add(day);
          }
        }
      } else {
        final day = _dayNames[part];
        if (day != null) days.add(day);
      }
    }

    return days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days.toList();
  }
}

class _TimeRange {
  const _TimeRange(this.start, this.end);

  final int start;
  final int end;
}
