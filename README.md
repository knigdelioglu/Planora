# Not

Not, Notion benzeri kişisel not alma ve Kanban çalışma alanı için tasarlanan **tek kullanıcılı, offline-first Flutter uygulamasıdır**. Yerel veritabanı uygulamanın birincil çalışma kaynağıdır (source of truth); ağ bağlantısı olmadan notlar, kartlar, ekler ve hatırlatıcılar tam işlevsellikle kullanılabilir. Bulut senkronizasyonu yerel deneyimi bloklamayan, arka planda çalışan ikincil bir katmandır.

> **Durum:** Üretim Sürümü Adayı (Production-Ready) — Android, iOS ve macOS platformlarında çalışan, Drift yerel veritabanı, Supabase bulut senkronizasyonu, FTS5 tam metin arama, çift cihaz çakışma çözümü, erişilebilirlik (WCAG AA) ve kapsamlı test güvencesine sahip tam özellikli sürüm.

---

## 📚 Bağlayıcı Dokümantasyon ve Mimari Referanslar

Uygulamanın tasarım, kapsam, yol haritası ve test protokolleri aşağıdaki dokümanlarla güvence altına alınmıştır:

| Doküman | Açıklama |
| --- | --- |
| **[docs/SCOPE.md](docs/SCOPE.md)** | Kapsam sınırları, tek kullanıcı modeli, desteklenen ve bilinçli olarak kapsam dışı bırakılan özellikler. |
| **[docs/UX_DESIGN.md](docs/UX_DESIGN.md)** | Ekranlar, responsive davranış, tema token'ları, etkileşimler ve WCAG AA erişilebilirlik sözleşmesi. |
| **[docs/PRODUCT_ROADMAP.md](docs/PRODUCT_ROADMAP.md)** | Faz bazlı yürütme planı, tamamlanma durumları, kalite kapıları ve Definition of Done matrisi. |
| **[docs/test_plans/DEVICE_REMINDER_TEST_PLAN.md](docs/test_plans/DEVICE_REMINDER_TEST_PLAN.md)** | Gerçek cihazlarda hatırlatıcı, alarm izinleri, bildirim ve reboot mutabakat test planı. |
| **[supabase/README.md](supabase/README.md)** | Supabase veritabanı şeması, PostgreSQL fonksiyonları, RLS güvenlik politikaları ve yerel test yönergeleri. |

### Belge Otoritesi Sırası

1. `docs/SCOPE.md` — Ne yapılacağını ve neyin yapılmayacağını belirler.
2. `docs/UX_DESIGN.md` — Kullanıcı deneyimi, ekran durumları ve UI sözleşmesini belirler.
3. `docs/PRODUCT_ROADMAP.md` — Geliştirme sırasını, gerçek durumları ve kalite kapılarını belirler.
4. `README.md` — Mimari genel görünüm, özellik seti ve geliştirici doğrulama rehberidir.

---

## 🚀 Ürün Yetenekleri ve Özellikler

### 1. Offline-First & Yerel Veri Kaynağı (Source of Truth)
- Ağ bağlantısına ihtiyaç duymadan tüm not, Kanban panosu, kart, ek dosya ve hatırlatıcı işlemleri yerel SQLite/Drift veritabanına anında transaction ile yazılır.
- UI, reaktif Drift stream'leri üzerinden beslenir; uzak sunucu yanıtı beklenmez (sıfır UI bloklanması).
- Uygulama çökmesi veya process death durumlarında WAL (Write-Ahead Logging) ve busy timeout koruması ile sıfır veri kaybı.

### 2. Zengin Not Editörü (Block-Based Note Editor)
- **Blok Tabanlı İçerik:** Paragraf, başlıklar (H1, H2, H3), madde listesi, numaralı liste, yapılacaklar/checkbox, alıntı (quote), kod bloğu, yatay ayraç (divider), bağlantı (link), görsel ve dosya ekleri.
- **Etkileşimli Araçlar:** Slash komut menüsü (`/`), metin seçimine duyarlı kayan formatlama çubuğu (selection toolbar).
- **Otomatik Kayıt:** Debounce mekanizmalı kesintisiz autosave ve arka plana geçişte anında flush garantisi.
- **Klavye Kısayolları:** Enter ile blok bölme, boş blokta Backspace ile tür dönüşümü/silme ve yön tuşlarıyla kesintisiz bloklar arası geçiş.

### 3. Yüksek Performanslı Kanban Panoları
- Çoklu pano, kolon ve kart CRUD desteği.
- Kolon içi ve kolonlar arası akıcı sürükle-bırak (Drag & Drop) ve otomatik kenar kaydırma (edge auto-scroll).
- **Fractional Indexing:** LexoRank benzeri string/kesirli indeksleme sayesinde kart taşımalarında O(1) yeniden sıralama (tüm listeyi O(N) yeniden indeksleme gerektirmez).
- **500+ Kart Performansı:** Tembel yükleme (lazy rendering) ve viewport virtualization ile 500+ kartlık panolarda <3s açılış ve akıcı 60 FPS kaydırma.

### 4. Ek Dosya (Attachment) Yaşam Döngüsü & LRU Önbellek
- Dosya byte'ları veritabanında BLOB olarak tutulmaz; yerel sandbox dizininde (`app_storage/attachments/<id>/<filename>`) saklanır.
- Drift'te yalnızca dosya yolu, dosya boyutu, MIME türü, SHA-256 sağlama toplamı (checksum) ve senkronizasyon metadata'sı tutulur.
- İndirilen uzak dosyalar için otomatik LRU (Least Recently Used) önbellek temizleme politikası.
- Uygulama başlangıcında ve transfer kesintilerinde dosya sistemi ile veritabanını eşitleyen mutabakat motoru (reconciliation).

### 5. Zamanlanmış Hatırlatıcılar & Yerel Bildirimler
- Timezone-aware yerel bildirim planlaması (`flutter_local_notifications` + `timezone`).
- Android 12+ Exact Alarm izin kontrolü ve izin verilmediğinde kesintisiz inexact alarm fallback'i.
- Cihaz yeniden başlatma (reboot) veya saat dilimi değişimlerinde veritabanı kaynaklı otomatik bildirim mutabakatı.

### 6. Hızlı Yerel Arama & Komut Paleti (FTS5 Search)
- SQLite FTS5 (Full-Text Search) altyapısı ile not başlığı, not içeriği, kart başlığı, kart açıklaması ve pano adlarında anlık arama.
- 10.000+ kelimelik veri setlerinde dahi <50ms arama tepki süresi.
- macOS `⌘K` / Windows & Linux `Ctrl+K` kısayoluyla her yerden erişilebilen global komut ve navigasyon paleti.

### 7. Supabase Senkronizasyon Motoru & Çift Cihaz Çakışma Çözümü
- **Kuyruk Tabanlı Eşitleme (Sync Queue):** Çevrimdışı yapılan her yerel değişiklik dayanıklı `sync_queue` tablosuna yazılır; bağlantı sağlandığında arka planda sunucuya aktarılır.
- **Supabase Backend & RLS:** PostgreSQL üzerinde Row Level Security (RLS) politikalarıyla tek kullanıcı veri izolasyonu; anonim veya yetkisiz erişimler veritabanı düzeyinde engellenir.
- **Eksponansiyel Geri Çekilme & Jitter:** Ağ hatalarında akıllı tekrar deneme (exponential backoff & jitter) ve sunucu onay kaybı (lost ack) durumunda idempotent kurtarma.
- **Çakışma Fark Görünümü (Conflict Diff UX):** İki cihazın aynı anda çevrimdışı değişiklik yapması durumunda veri kaybını önleyen görsel karşılaştırma ekranı; varlık bazlı diff, teknik JSON akordeonu ve 3 çözüm aksiyonu:
  1. *Bu cihazdaki sürümü koru* (Local overwrite)
  2. *Uzak sürümü kabul et* (Remote accept)
  3. *Kopya olarak iki sürümü de sakla* (Fork / duplicate)
- **Senkronizasyon Kuyruğu Ekranı:** Bekleyen, işlenen, çakışan veya başarısız operasyonların durumunu izleme ve tekil/toplu tekrar deneme arayüzü.

### 8. Tasarım Sistemi, Responsive Shell & Erişilebilirlik (WCAG AA)
- Material 3 uyumlu, modern ve göz yormayan Light & Dark tema token'ları.
- **Platforma Duyarlı Kabuk (App Shell):** Masaüstü/macOS ve geniş tabletlerde kalıcı `NavigationRail` / kenar çubuğu; mobil cihazlarda `BottomNavigationBar`.
- **Erişilebilirlik (a11y):** Minimum 48x48 dp dokunma alanları, Semantics etiketleri, ekran okuyucu uyumluluğu ve klavye odağı desteği.

---

## 🔒 Tek Kullanıcı Modeli

Bu uygulama tek bir kullanıcının kişisel üretkenliğini en üst düzeye çıkarmak için tasarlanmıştır. Bu doğrultuda mimaride bilinçli olarak şunlar **yer almaz**:
- Takım/workspace üyeliği ve davet yönetimi
- Eşzamanlı ortak düzenleme (realtime collaborative editor / CRDT)
- Rol tabanlı yetkilendirme matrisi (RBAC)

Bulut senkronizasyonunda Supabase Auth yalnızca kullanıcının kendi verisini güvenli biçimde tekil kullanıcı kimliğine bağlamak için kullanılır. İstemci kodunda asla `service_role` anahtarı barındırılmaz.

---

## 🏗️ Mimari Yapı

Uygulama **Feature-First Clean Architecture** ilkeleriyle geliştirilmiştir:

```text
UI (Flutter Widgets / Screens)
        │
        ▼
Riverpod State Notifiers & Controllers
        │
        ▼
Domain Use Cases & Entities (Saf Dart — Drift/Flutter/Supabase bağımsız)
        │
        ▼
Repository Arayüzleri (Contracts)
        │
        ├────────────────────────────────────┐
        ▼                                    ▼
Drift Yerel Veri Kaynağı (SQLite)    Uzak Ağ & Supabase Gateway
(Birincil Source of Truth)           (İkincil Sync Katmanı)
        │                                    │
        ▼                                    │
Sync Queue Transaction ──────────────────────┘
        │
        ▼
Sync Engine & Sync Coordinator (Delta Pull / Push / Conflict Policy)
```

---

## 🛠️ Teknoloji Yığını

| Katman | Teknoloji | Amaç |
| --- | --- | --- |
| **Framework** | Flutter (Dart 3.12+) | Çoklu platform istemci uygulaması (macOS, iOS, Android) |
| **State Management** | Flutter Riverpod | Reaktif durum yönetimi ve dependency injection |
| **Yerel Veritabanı** | Drift + sqlite3 (FTS5) | Tip güvenli yerel SQLite veritabanı ve reaktif stream'ler |
| **Dosya Depolama** | path_provider + file_picker | Güvenli yerel sandbox dosya yönetimi |
| **Bildirim & Alarm** | flutter_local_notifications + timezone | Yerel zamanlanmış bildirimler ve exact alarm yönetimi |
| **Bulut Backend** | Supabase (PostgreSQL + RLS + Storage) | Güvenli bulut depolama, auth ve veri senkronizasyonu |
| **Ağ & İletişim** | dio + connectivity_plus | HTTP/REST istemcisi ve bağlantı durumu izleme |
| **Sıralama Algoritması** | Fractional Indexing (LexoRank) | O(1) maliyetli düşük çakışmalı kart sıralama |

---

## 📁 Dizin Yapısı

```text
lib/
├── app/
│   ├── app.dart                        # Ana uygulama widget'ı ve Riverpod ProviderScope
│   ├── app_bootstrap.dart              # Composition root, servis başlatma & hata bariyeri
│   ├── app_shell.dart                  # Responsive navigasyon kabuğu (Desktop Rail / Mobile Bar)
│   ├── router/
│   │   └── app_router.dart             # Rota tanımları ve sayfa geçişleri
│   ├── theme/
│   │   └── app_theme.dart              # Light/Dark token'lar, tipografi ve bileşen temaları
│   └── widgets/
│       └── common_widgets.dart         # Butonlar, diyaloglar, form alanları ve erişilebilir UI
├── core/
│   ├── auth/                           # Supabase kimlik doğrulama servisleri ve oturum yönetimi
│   ├── config/                         # Ortam değişkenleri ve uygulama yapılandırması
│   ├── database/
│   │   ├── app_database.dart           # Drift veritabanı sınıfı, tablolar ve FTS5 şeması
│   │   ├── connection/native.dart      # Platforma özel SQLite native bağlantısı
│   │   └── tables/                     # Notes, Boards, Cards, Attachments, Reminders, Sync tabloları
│   ├── error/                          # Sınıflandırılmış Failure ve Error modelleri
│   ├── logging/                        # Güvenli loglama ve teşhis altyapısı
│   ├── network/                        # Bağlantı durumu ve ağ soyutlamaları
│   ├── remote/                         # Supabase REST/Postgres gateway implementasyonları
│   ├── services/
│   │   ├── file_storage_service.dart   # Ek dosya I/O, hash doğrulama ve LRU temizleme
│   │   └── notification_service.dart   # Bildirim planlama ve exact alarm yönetimi
│   ├── settings/                       # Kullanıcı ayarları kalıcılık katmanı
│   ├── sync/
│   │   ├── local_entity_store.dart     # Yerel varlık CRUD ve mutasyon soyutlaması
│   │   ├── sync_coordinator.dart       # Yaşam döngüsü ve ağ tetikleyicili senkronizasyon orkestrasyonu
│   │   ├── sync_engine.dart            # Delta pull, batch push, retry ve çakışma tespit motoru
│   │   ├── sync_models.dart            # Senkronizasyon operasyonları ve durum modelleri
│   │   └── sync_queue_repository.dart  # Dayanıklı sync queue DAO ve repository
│   └── utils/                          # Fractional indexing, saat ve yardımcı araçlar
└── features/
    ├── attachments/                    # Dosya ekleme, silme, önizleme ve liste bileşenleri
    ├── conflicts/                      # Çakışma listesi ve görsel Diff karşılaştırma ekranı
    ├── home/                           # Başlangıç ve pano/not özet ekranı
    ├── kanban/                         # Pano, kolon ve kart yönetimi; sürükle-bırak panolar
    ├── notes/                          # Blok tabanlı zengin not editörü ve not listesi
    ├── reminders/                      # Hatırlatıcı listesi ve zamanlama diyaloğu
    ├── search/                         # SQLite FTS5 küresel arama ve komut paleti (⌘K)
    └── settings/                       # Senkronizasyon kuyruğu, hesap ve uygulama ayarları

supabase/
├── migrations/
│   └── 0001_initial.sql                # PostgreSQL tabloları, RLS politikaları ve apply_entity_change RPC
└── README.md                           # Supabase kurulum ve güvenlik kılavuzu

test/
├── core/                               # Servis, sync engine, queue retry ve RLS güvenlik testleri
├── database/                           # Drift şema, foreign key, cascade ve transaction testleri
├── features/                           # Notes UX, Kanban performans, FTS5 arama, a11y ve diff testleri
├── fixtures/                           # Test veri setleri ve sentetik yük üreteçleri
├── helpers/                            # PostgreSQL RLS test harness ve fake servisler
├── integration/                        # Process death kurtarma ve çift istemcili E2E senkronizasyon testleri
└── performance/                        # Regresyon ve bellek/hız performans testleri
```

---

## 💻 Geliştirme Kurulumu ve Doğrulama Komutları

### 1. Bağımlılıkları Yükleme
```bash
flutter pub get
```

### 2. Kod Üretimi (Drift Şeması & Riverpod)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Kod Biçimlendirme Kontrolü
```bash
dart format --output=none --set-exit-if-changed .
```

### 4. Statik Kod Analizi
```bash
dart analyze
```

### 5. Birim, Veritabanı, Özellik ve Performans Testlerini Çalıştırma
```bash
flutter test test/features/ test/performance/ test/database/ test/core/
```

### 6. Çökme / Yaşam Döngüsü Dayanıklılık ve Duman Testleri
```bash
flutter test test/widget_smoke_test.dart test/integration/offline_flow_test.dart test/integration/process_death_recovery_test.dart
```

### 7. Çift İstemcili Uçtan Uca (E2E) Supabase Senkronizasyon & Çakışma Testleri
```bash
flutter test test/integration/supabase_two_client_sync_e2e_test.dart
```

---

## 📱 Platformlarda Çalıştırma

### Yerel Geliştirme (Offline Mod — Supabase Yapılandırması Olmadan)
```bash
# macOS üzerinde çalıştırma
flutter run -d macos

# Android üzerinde çalıştırma (bağlı cihaz veya emülatör)
flutter run -d android

# iOS üzerinde çalıştırma (bağlı cihaz veya simülatör)
flutter run -d ios
```

### Bulut Senkronizasyonu ile Çalıştırma (Supabase Ortam Değişkenleri)
```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://<your-project-id>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-anon-publishable-key>
```

> **Güvenlik Notu:** `service_role` anahtarını asla istemci uygulamasına tanımlamayınız. Anon/publishable key tek başına yeterlidir; güvenlik Supabase üzerindeki Row Level Security (RLS) politikaları ile sağlanır.

---

## 🛡️ Kalite, Güvenlik ve Mimari İlkeler

- **UI Katmanında Doğrudan I/O Yasağı:** Widget'lar doğrudan dosya sistemine, veritabanına veya bildirim API'sine erişemez; tüm akış Domain Use Case ve Repository sınırlarından geçer.
- **Veritabanında Dosya Saklama Yasağı:** Ek dosyalar hiçbir zaman veritabanında BLOB olarak tutulmaz; yalnızca metadata ve URI saklanır.
- **O(N) Sıralama Maliyetinden Kaçınma:** Her kart taşıma işleminde tüm liste güncellenmez; Fractional Indexing ile yalnızca ilgili kaydın sıralama değeri güncellenir.
- **Ağ Hatalarında Veri Bütünlüğü:** Ağ isteği başarısız olduğunda yerel işlem geri alınmaz; kuyrukta tutularak eksponansiyel geri çekilme ile yeniden denenir.
- **Kesintisiz Çoklu Platform Desteği:** Android, iOS ve macOS platformlarının her birinde yerel izinler, arka plan yaşam döngüsü ve pencere/ekran boyutları optimize edilmiştir.
- **Erişilebilirlik Güvencesi:** Tüm etkileşimli bileşenler en az 48x48 dp dokunma alanına sahiptir ve Semantics ağacında açıklayıcı etiketler taşır.

---

## 📄 Lisans ve Kullanım

Bu proje özel kullanım için geliştirilmiştir. İzinsiz kopyalanamaz veya dağıtılamaz.
