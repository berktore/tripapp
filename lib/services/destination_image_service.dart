import 'dart:convert';

import 'package:http/http.dart' as http;

class DestinationImageService {
  static final Map<String, String?> _cache = {};

  static String _searchTerm(String destination) {
    switch (destination.trim().toLowerCase()) {
      case 'adana':
        return 'Adana Taşköprü Turkey';
      case 'kapadokya':
      case 'cappadocia':
        return 'Cappadocia Göreme fairy chimneys hot air balloons Turkey';
      case 'antalya':
        return 'Antalya Kaleiçi old town Turkey';
      case 'istanbul':
        return 'Istanbul Bosphorus Turkey';
      case 'santorini':
        return 'Santorini Greece Oia blue domes';
      case 'roma':
      case 'rome':
        return 'Rome Colosseum Italy';
      case 'paris':
        return 'Paris Eiffel Tower France';
      case 'new york':
        return 'New York Manhattan skyline USA';
      case 'kyoto':
        return 'Kyoto Japan traditional temple';
      case 'bali':
        return 'Bali Indonesia rice terraces';
      default:
        return '$destination landmark';
    }
  }

  static List<String> _acceptedTitleWords(String destination) {
    switch (destination.trim().toLowerCase()) {
      case 'adana':
        return ['taşköprü', 'taskopru', 'adana'];
      case 'kapadokya':
      case 'cappadocia':
        return ['cappadocia', 'kapadokya', 'göreme', 'goreme', 'uchisar'];
      case 'antalya':
        return ['antalya', 'kaleiçi', 'kaleici'];
      case 'istanbul':
        return ['istanbul', 'constantinople'];
      case 'santorini':
        return ['santorini'];
      case 'roma':
      case 'rome':
        return ['rome', 'roma', 'colosseum'];
      case 'paris':
        return ['paris', 'eiffel'];
      case 'new york':
        return ['new york', 'manhattan'];
      case 'kyoto':
        return ['kyoto'];
      case 'bali':
        return ['bali'];
      default:
        return [destination.toLowerCase()];
    }
  }

  static Future<String?> getImageUrl(String destination) async {
    final key = destination.trim().toLowerCase();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];

    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': 'filetype:bitmap ${_searchTerm(destination)}',
      'gsrnamespace': '6',
      'gsrlimit': '20',
      'prop': 'imageinfo',
      'iiprop': 'url',
      'iiurlwidth': '1400',
      'format': 'json',
      'origin': '*',
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'TripApp/1.0'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        _cache[key] = null;
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = data['query']?['pages'] as Map<String, dynamic>?;
      if (pages == null) {
        _cache[key] = null;
        return null;
      }

      final accepted = _acceptedTitleWords(destination);
      for (final value in pages.values) {
        final page = value as Map<String, dynamic>;
        final title = (page['title'] ?? '').toString().toLowerCase();
        if (!accepted.any(title.contains)) continue;

        final infos = page['imageinfo'] as List<dynamic>?;
        if (infos == null || infos.isEmpty) continue;

        final info = infos.first as Map<String, dynamic>;
        final url = (info['thumburl'] ?? info['url'])?.toString();
        if (url != null && url.startsWith('https://')) {
          _cache[key] = url;
          return url;
        }
      }
    } catch (_) {
      // A network failure leaves the destination without a dynamic image.
    }

    _cache[key] = null;
    return null;
  }
}
