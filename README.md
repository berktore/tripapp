# TripApp

Gerçek mekân verisiyle çalışan, **hesap gerektirmeyen** seyahat planlayıcı.
Flutter ile Android, iOS ve Web hedeflenir.

> Bu sürümde "yapay zekâ" olarak adlandırılan planlama, açıklanabilir kural tabanlı bir
> puanlama ve dağıtım hattıdır. Ücretli LLM/API kullanılmaz; her durak gerçek bir
> sağlayıcıdan gelir.

---

## 1. Öne çıkanlar

- **Gerçek veri:** Mekânlar, yapılandırıldığında Geoapify Places API üzerinden gelir;
  anahtar yoksa OpenStreetMap (Overpass API) ve Wikipedia GeoSearch yedekleri devreye girer.
  Uydurma mekân/isim/koordinat yoktur.
- **Konum çözümleme:** Open-Meteo geocoding (anahtarsız) ile şehir arama; seçilen sonucun
  koordinatı ve ülke kodu planlamaya taşınır. Türkçe egzonimler (Londra, Venedik, Münih)
  için Nominatim yedeği ve takma ad eşlemesi vardır.
- **Açıklanabilir planlama:** Seyahat tarzı, bütçe, kategori çeşitliliği, coğrafi yakınlık
  ve `opening_hours` verisi kullanılır. Öğle yemeği 12:30'a, kahvaltı 09:00'a yerleşir.
- **Harita ve yol tarifi:** Kayıtlı planın durakları `flutter_map` + OSM karolarıyla
  gösterilir; tek dokunuşla harici yol tarifi açılır.
- **Hava durumu:** Open-Meteo tahmini (16 gün) plan detayında gösterilir.
- **Planlar:** Kaydetme, silme, favorilere ekleme, panoya kopyalayarak paylaşma,
  durak kaldırma, önbelleği temizleme ve profil özeti.
- **Çevrimdışı dayanıklılık:** Sağlayıcı yanıtları 72 saat TTL ile cihazda önbelleklenir;
  ağ hatasında süresi geçmiş önbellekle çalışmaya devam edilir.

---

## 2. Veri kaynakları ve lisanslar

| Veri | Kaynak | Anahtar | Lisans / koşul |
| --- | --- | --- | --- |
| Mekânlar (birincil) | [Geoapify Places](https://apidocs.geoapify.com/docs/places/) | Geoapify anahtarı | Ücretsiz kota, Geoapify + OSM atfı |
| Mekânlar (birincil) | [OpenStreetMap Overpass API](https://overpass-api.de/) | Yok | ODbL; atıf zorunlu |
| Mekânlar (yedek) | [Wikipedia GeoSearch](https://www.mediawiki.org/wiki/Extension:GeoData) | Yok | CC BY-SA; atıf zorunlu |
| Şehir arama | [Open-Meteo Geocoding](https://open-meteo.com/en/docs/geocoding-api) | Yok | Ücretsiz kullanım koşulları |
| Konum yedeği | [Nominatim](https://nominatim.org/) | Yok | ODbL; kullanım politikası |
| Hava durumu | [Open-Meteo](https://open-meteo.com/) | Yok | Ücretsiz kullanım koşulları |
| Görseller | Wikimedia Commons / Unsplash | Yok | İlgili lisanslar |

Arayüzde OSM ve Wikipedia atıfları gösterilir (plan detayı ve harita).

> **Yayın öncesi:** Overpass ve Nominatim kullanım politikaları gereği `User-Agent`
> başlığına iletişim adresi eklenmeli (`lib/services/overpass_place_provider.dart`,
> `lib/services/nominatim_service.dart`). Yüksek trafikte kendi Overpass/Nominatim
> örneğinizi veya önbellekli bir proxy kullanın.

---

## 3. Mimari

```
lib/
  core/                  AppException (sınıflandırılmış hatalar), logDebug
  models/                Place, DestinationRef, TripPlan/ItineraryDay/ItineraryStop
  services/
    place_provider.dart          Sağlayıcı sözleşmesi
    overpass_place_provider.dart OSM birincil sağlayıcı (tek sorgu, sıralı yedek sunucu)
    wikipedia_place_provider.dart Wikipedia yedek sağlayıcı
    fallback_place_provider.dart Birincil -> yedek zinciri
    nominatim_service.dart       Türkçe egzonim/ülke filtreli konum çözümleme
    place_cache.dart             SharedPreferences tabanlı TTL önbelleği
    opening_hours.dart           OSM opening_hours yorumlayıcısı
    place_filter_service.dart    Tekilleştirme + haversine
    place_scoring_service.dart   Açıklanabilir puanlama
    itinerary_distribution_service.dart  Günlere dağıtım
    destination_places_service.dart      Uçtan uca plan üretimi
    weather_service.dart         Open-Meteo tahmini
    trip_storage.dart            Yerel gezi deposu (bozuk kayda dayanıklı)
  screens/               Ana sayfa, Keşfet, Planlayıcı, Planlarım, Harita, Profil
  theme/                 Renkler + Inter/Plus Jakarta Sans tipografi
```

### Plan üretim hattı

1. **Konum:** Seçilen sonuçta koordinat varsa doğrudan kullanılır; yoksa Nominatim.
2. **Mekân verisi:** Önbellek (72 saat) → Overpass (tek sorgu, 8 km / yemek 5 km) →
   Wikipedia yedeği.
3. **Temizleme:** Geçersiz koordinat, boş isim/kategori ve mükerrer OSM kimlikleri ayıklanır.
4. **Puanlama:** Kategori taban puanı + tarz eşleşmesi + bütçe + OSM etiketleri.
5. **Dağıtım:** Yüksek puanlı ve coğrafi olarak farklı başlangıç noktaları; kategori
   tekrarına ceza; gün başına en fazla 4 durak.
6. **Sıralama:** En yüksek puanlı durakla başlayıp en yakın komşu ile devam.
7. **Öğün ve saat:** Öğle yemeği 12:30; `opening_hours` kapalıysa aynı gün içinde
   yer değiştirme.
8. **Kayıt:** `TripPlan` olarak SharedPreferences'a yazılır; durak koordinatları ve
   kaynak bilgisi korunur.

---

## 4. Kurulum

Gereksinim: Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
flutter run                 # bağlı cihaz/emülatör
flutter run -d chrome       # web
flutter build apk --debug   # Android paketi
```

iOS klasörü hazırdır ancak **macOS/Xcode olmadan derlenemez**; bu depoda iOS derlemesi
henüz doğrulanmamıştır.

### Geoapify API anahtarı

Geoapify anahtarını kaynak koda yazmayın. Web geliştirmede uygulamayı şöyle başlatın:

```bash
flutter run -d chrome --dart-define=GEOAPIFY_API_KEY=anahtarin
```

Anahtar verilmezse uygulama Overpass ve Wikipedia yedeklerini kullanır. Yayın öncesinde
Geoapify panelinden anahtarı uygulamanızın alan adıyla sınırlandırın.

---

## 5. Testler

```bash
flutter analyze
flutter test
```

Canlı sağlayıcı kontrolleri varsayılan olarak atlanır:

```bash
flutter test test/live_providers_test.dart --dart-define=LIVE=true
```

Kapsam:

- `opening_hours_test.dart` — 24/7, gün aralıkları, çoklu saat aralıkları, kapalı günler
- `place_filter_service_test.dart` — tekilleştirme, geçersiz koordinat, mesafe
- `place_scoring_service_test.dart` — tarz/bütçe etkisi
- `itinerary_distribution_service_test.dart` — kapasite, tek atama, coğrafi kümeleme
- `trip_storage_test.dart` — JSON gidiş-dönüş, bozuk kayıt toleransı, favori, durak silme
- `place_providers_test.dart` — Wikipedia ayrıştırma/atıf, yedek zinciri
- `widget_test.dart` — planlayıcı doğrulama akışı

---

## 6. Bilinen sınırlar ve sonraki adımlar

- **Overpass gecikmesi:** Ücretsiz genel sunucular yoğun saatlerde 30-75 saniye yanıt
  verebilir. İlk plan yavaş, sonraki planlar önbellekten hızlıdır. Ölçek için kendi
  Overpass örneği/proxy veya anahtarlı ücretsiz bir sağlayıcı (ör. Geoapify) eklenebilir.
- **Yerelleştirme:** Arayüz metinleri şimdilik Türkçe; `en` yerel ayarı altyapıda var
  ancak çeviri dosyaları henüz yok.
- **Düzenleme:** Plan tarih/tarz düzenlemesi yeniden planlama gerektirir; bu sürümde
  durak kaldırma, favori, paylaşma ve silme vardır.
- **Arka uç:** Hesap, senkronizasyon ve çoklu cihaz yoktur (bilinçli olarak sıfır bütçe
  ve gizlilik tercihi). Gerekirse FastAPI + SQLite/Postgres ile eklenebilir.
- **Yayın imzası:** Android sürüm imzası hâlâ debug anahtarıyla yapılandırılmıştır;
  mağaza öncesi kendi keystore'unuzla değiştirilmelidir.
- **Kullanılmayan ekran:** `lib/screens/antalya_map_screen.dart` eski, sabit verili bir
  deneme ekranıdır ve hiçbir akışa bağlı değildir; yayın öncesi kaldırılması önerilir.

---

## 7. Gizlilik

- Hesap, izleme veya reklam yoktur.
- Planlar ve önbellek yalnızca cihazda (SharedPreferences) tutulur.
- Ağ istekleri yalnızca yukarıdaki ücretsiz sağlayıcılara yapılır.
- Profil ekranından mekân önbelleği temizlenebilir.
