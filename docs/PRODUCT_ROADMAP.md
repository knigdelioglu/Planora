# Not — Ürünleşme Yol Haritası

> **Durum:** Ürün geliştirme için bağlayıcı yürütme planı (Faz 0 - Faz 14 TAMAMLANDI; Faz 15-17 Sırada)  
> **Başlangıç noktası:** Mimari ve kaynak kod iskeleti (Faz 0)  
> **Mevcut durum:** macOS, iOS ve Android üzerinde çalışan, Drift yerel DB, Supabase senkronizasyonu, FTS5 arama, çakışma çözümü ve erişilebilirlik standartlarına sahip üretim sürümü adayı (Release Candidate hazırlığı)  
> **Hedef:** İmzalı paketler ve mağaza dağıtımına hazır son ürün sürümü  
> **İlişkili belgeler:** `README.md`, `docs/SCOPE.md`, `docs/UX_DESIGN.md`, `docs/test_plans/DEVICE_REMINDER_TEST_PLAN.md`, `supabase/README.md`

Bu belge `Not` uygulamasının başlangıç iskeletinden nihai ürün seviyesine ulaşmasına kadar gereken geliştirme, doğrulama ve yayın süreçlerini sıralı fazlara böler.

Bu yol haritası bir özellik istek listesi değildir. Her fazın:

- amacı,
- kapsamı,
- teknik işleri,
- UX işleri,
- veri/migration etkileri,
- test ve doğrulama gereksinimleri,
- çıkış kriterleri ve gerçekleşme durumu

açıkça tanımlanmıştır.

Bir fazın çıkış kriterleri karşılanmadan sonraki faz **tamamlanmış** kabul edilmez.

---

# 0. Yürütme kuralları ve belge otoritesi

Geliştirme boyunca karar önceliği aşağıdaki sıradadır:

1. `docs/SCOPE.md` — ürünün neyi yapıp yapmayacağını belirler.
2. `docs/UX_DESIGN.md` — ekran, component ve kullanıcı davranışlarını belirler.
3. `docs/PRODUCT_ROADMAP.md` — geliştirme sırası, gerçek durumlar ve kalite kapılarını belirler.
4. `README.md` — mimari ve proje genel görünümünü açıklar.
5. Kod — yukarıdaki sözleşmeleri uygular.

Çelişki oluşursa daha üst sıradaki belge esas alınır.

## Değişiklik yönetimi

Yeni bir özellik geliştirme sırasında ortaya çıkarsa:

- önce `SCOPE.md` içinde kapsamda olup olmadığı kontrol edilir,
- kapsam dışındaysa doğrudan uygulanmaz,
- kapsam değiştirilecekse önce scope güncellenir,
- kullanıcı deneyimini etkiliyorsa `UX_DESIGN.md` de güncellenir,
- yalnız bundan sonra implementation planına eklenir.

Bu kural scope creep ve plansız teknik borcu önlemek için zorunludur.

---

# 1. Mevcut durum — Gerçeklik Senkronizasyonu

Repo, Faz 0'dan Faz 14'e kadar olan tüm temel mimari, yerel persistence, UI/UX, zengin editör, Kanban, ek dosya yönetimi, hatırlatıcılar, arama, bulut senkronizasyonu, çakışma çözümü, platform sertleştirme ve kalite aşamalarını başarıyla tamamlamıştır.

## Mevcut Olanlar (Tamamlanan Ürün Yetenekleri)

- **Platform Bootstrap (Faz 1):** Android, iOS ve macOS native klasörleri, bundle ID'leri, izin yapılandırmaları ve `--dart-define` config yapısı.
- **Composition Root & Wiring (Faz 2):** `AppBootstrap` sınıfı, Riverpod dependency injection grafı, deterministik başlatma sırası ve `AppErrorBoundary` startup UI'ı.
- **Persistence Core & Integrity (Faz 3):** Drift SQLite veritabanı (`app_database.dart`), Notes, Boards, Columns, Cards, Attachments, Reminders ve Sync Queue tabloları, atomik transaction sınırları, foreign key cascade bütünlüğü ve migration altyapısı.
- **Design System & Shell (Faz 4):** Material 3 tabanlı Light/Dark token'ları (`app_theme.dart`), ortak erişilebilir bileşenler (`common_widgets.dart`), responsive navigasyon kabuğu (Desktop `NavigationRail` / Mobil `BottomNavigationBar`), WCAG AA kontrast uyumu ve min 48x48 dp dokunma hedefleri.
- **Notes Core & Editor (Faz 5):** Blok tabanlı zengin not editörü (paragraf, başlıklar H1-H3, listeler, yapılacaklar/checkbox, alıntı, kod bloğu, ayraç), slash komut menüsü (`/`), seçim duyarlı araç çubuğu (selection toolbar), klavye kısayolları ve debounced autosave.
- **Kanban Core & Ranking (Faz 6):** Pano, kolon ve kart CRUD, akıcı sürükle-bırak, Fractional Indexing (LexoRank benzeri) ile O(1) yeniden sıralama, 500+ kartlık sentetik panolarda virtualization ve tembel yükleme ile <3s açılış performansı.
- **Attachment Lifecycle & Cache (Faz 7):** Yerel sandbox dizininde güvenli dosya saklama, Drift metadata/hash kaydı, indirilen dosyalar için otomatik LRU önbellek tahliyesi ve açılışta yetim/kayıp dosya mutabakatı (reconciliation).
- **Reminders & Local Notifications (Faz 8):** Timezone-aware bildirim planlaması, Android exact alarm izni ve inexact fallback desteği, cihaz yeniden başlatma (reboot) sonrası bildirim mutabakatı ve test planı (`docs/test_plans/DEVICE_REMINDER_TEST_PLAN.md`).
- **Search & Navigation (Faz 9):** SQLite FTS5 küresel tam metin arama, <50ms sorgu tepki süresi, macOS `⌘K` / Windows-Linux `Ctrl+K` komut paleti.
- **Cloud Foundation & RLS (Faz 10):** Supabase PostgreSQL şeması (`supabase/migrations/0001_initial.sql`), Row Level Security (RLS) ile tek kullanıcı veri izolasyonu, `apply_entity_change` RPC fonksiyonu.
- **Sync Engine (Faz 11):** Dayanıklı çevrimdışı senkronizasyon kuyruğu, delta pull/push, eksponansiyel geri çekilme & jitter ile retry, sunucu onay kaybı kurtarma (lost ack recovery), dosya transfer senkronizasyonu ve `SyncQueueScreen` yönetim arayüzü.
- **Conflict Resolution & Recovery (Faz 12):** İki cihazın bağımsız çevrimdışı değişikliklerini tespit etme, varlık bazlı görsel karşılaştırma (`ConflictDiffView`), ham JSON akordeonu ve 3 çözüm aksiyonu (*Bu cihazı koru*, *Uzak sürümü al*, *Kopya olarak ikisini de sakla*), çift istemcili E2E senkronizasyon testi (`supabase_two_client_sync_e2e_test.dart`).
- **Platform Hardening (Faz 13):** Android Doze/exact alarm fallback, iOS/macOS bildirim izin döngüsü, process death kurtarma ve WAL replay (`process_death_recovery_test.dart`).
- **Quality Hardening (Faz 14):** Kapsamlı birim, veritabanı, widget ve entegrasyon testleri, performans regresyon testleri (`performance_regression_test.dart`), erişilebilirlik denetimi (`accessibility_test.dart`).

## Açık Olan / Tamamlanacak Aşama ve İşler (Faz 15, 16, 17)

- **Faz 15 (Beta / Release Candidate):** Gerçek fiziksel cihazlarda uzun süreli kullanım (soak test), `DEVICE_REMINDER_TEST_PLAN.md` doğrulaması, sürüm dondurma (freeze).
- **Faz 16 (Product Release):** İmzalı binary üretimi (macOS `.app`/DMG/notarization, iOS distribution archive, Android signed AAB/APK), mağaza ekran görüntüleri ve yayın konfigürasyonu.
- **Faz 17 (Post-Release Operations):** Yayın sonrası operasyonlar, crash log takibi, OS güncelleme uyumluluğu ve migration disiplini.

---

# 2. Ürün seviyesine ulaşmak için kalite tanımı

Bir özellik yalnız ekranda çalışıyorsa tamamlanmış sayılmaz.

Ürün kalitesindeki her temel özellik aşağıdaki koşulları karşılamalıdır:

1. offline çalışır,
2. uygulama kapanıp açıldığında veri korunur,
3. hata durumları kullanıcıya kontrollü gösterilir,
4. state UI ile tutarlıdır,
5. veri erişimi repository sınırından geçer,
6. doğrudan platform bağımlılığı presentation katmanına sızmaz,
7. migration gerektiriyorsa migration vardır,
8. unit/integration/widget test kapsamı uygundur,
9. erişilebilirlik kontrolünden geçmiştir,
10. ilgili UX durumları uygulanmıştır,
11. sync edilen bir entity ise sync state'i tanımlıdır,
12. büyük veri ve tekrar kullanım senaryolarında performansı kabul edilebilirdir.

---

# 3. Faz özeti

| Faz | Başlık | Ana çıktı | Durum |
| --- | --- | --- | --- |
| 0 | Baseline | Mimari ve dokümantasyon iskeleti | **TAMAMLANDI** |
| 1 | Platform Bootstrap | Android/iOS/macOS üzerinde çalışan temiz uygulama | **TAMAMLANDI** |
| 2 | Composition Root & Foundations | Gerçek dependency wiring ve app lifecycle | **TAMAMLANDI** |
| 3 | Persistence Core | Production-ready Drift + migration + transaction altyapısı | **TAMAMLANDI** |
| 4 | Design System & App Shell | UX sözleşmesine uygun ortak UI sistemi, a11y (WCAG AA) | **TAMAMLANDI** |
| 5 | Notes Core | Blok editör, slash menü, toolbar, autosave, offline CRUD | **TAMAMLANDI** |
| 6 | Kanban Core | Kanban CRUD, sürükle-bırak, fractional ranking, 500+ kart performansı | **TAMAMLANDI** |
| 7 | Attachments | Yerel dosya lifecycle, LRU cache ve reconciliation | **TAMAMLANDI** |
| 8 | Reminders | Timezone-aware reminder, exact alarm fallback, reboot reconciliation | **TAMAMLANDI** |
| 9 | Search & Navigation | FTS5 küresel arama, ⌘K/Ctrl+K komut paleti (<50ms) | **TAMAMLANDI** |
| 10 | Cloud Foundation | Supabase şema, RLS güvenlik politikaları ve auth entegrasyonu | **TAMAMLANDI** |
| 11 | Sync Engine | Delta sync, queue, retry/backoff, tombstone ve dosya sync | **TAMAMLANDI** |
| 12 | Conflict & Recovery | Çok cihaz çakışma diff UX, 3 aksiyon, veri kurtarma güvenliği | **TAMAMLANDI** |
| 13 | Platform Hardening | Android/iOS/macOS yaşam döngüsü, exact alarm fallback, process death | **TAMAMLANDI** |
| 14 | Quality Hardening | Test piramidi, performans regresyonu, güvenlik, WCAG AA a11y | **TAMAMLANDI** |
| 15 | Beta / Release Candidate | Gerçek cihaz kabul testi ve release freeze | **DEVAM EDİYOR / SIRADAKİ** |
| 16 | Product Release | İmzalı ürün paketleri ve dağıtım | **AÇIK / PLANLANAN** |
| 17 | Post-Release Operations | Stabilizasyon, migration disiplini ve bakım | **AÇIK / PLANLANAN** |

Faz sırası bağımlılık sırasıdır. Çıkış kriterleri karşılanmadan sonraki aşamalara geçilmez.

---

# Faz 1 — Platform Bootstrap

> **Durum:** TAMAMLANDI

## Amaç

Mevcut Dart/Flutter kaynak iskeletini gerçek Android, iOS ve macOS projeleriyle güvenli biçimde birleştirmek ve üç platformda minimum uygulama kabuğunu çalıştırmak.

## İşler

### Flutter/native proje

- `android/`, `ios/`, `macos/` native klasörlerini oluştur.
- mevcut `lib/`, `pubspec.yaml`, `.gitignore` ve dokümantasyonu koru.
- bundle/application identifiers belirle (`not_app`).
- Android minSdk/targetSdk politikasını sabitle.
- iOS deployment target belirle.
- macOS deployment target belirle.
- app display name ve internal package name tutarlılığını sağla.

### Native permissions başlangıcı

- local notifications
- Android exact alarms
- file picker erişimi
- platform storage davranışları

### Build yapılandırması

- debug/profile/release ayrımını kur.
- secret'ların source control'e girmediğini doğrula.
- `--dart-define` standart config yapısını kur (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`).

## Çıkış kriteri (Karşılandı)

- macOS debug build açılıyor.
- Android debug build açılıyor.
- iOS simulator/device debug build açılıyor.
- uygulama temel shell ekranına crash olmadan geliyor.
- platform klasörlerinin hiçbirinde secret commit edilmiyor.

---

# Faz 2 — Composition Root, Dependency Wiring ve App Lifecycle

> **Durum:** TAMAMLANDI

## Amaç

Placeholder olan provider/repository bağlantılarını gerçek dependency graph'a dönüştürmek.

## İşler

### Composition root

Tek bir bootstrap katmanında oluşturuldu (`lib/app/app_bootstrap.dart`):

- `AppDatabase`
- repository implementations
- file storage service
- notification service
- network info
- sync coordinator
- config
- clock/time abstractions

Presentation katmanında `UnimplementedError` tabanlı production provider bırakılmadı.

### Lifecycle

Uygulama başlatılırken deterministik sıra kuruldu:

1. Flutter bindings
2. config
3. local database
4. timezone initialization
5. notification service initialization
6. repositories
7. sync/bootstrap services
8. UI mount

### Failure strategy

Bootstrap tamamen başarısız olursa:

- blank screen gösterilmez,
- crash loop oluşturulmaz,
- recovery/fatal startup ekranı (`AppErrorBoundary`) gösterilir,
- tekrar deneme ve güvenli hata raporu sağlanır.

## Çıkış kriteri (Karşılandı)

- production path'te `UnimplementedError` provider kalmadı.
- app dependency graph merkezi ve test edilebilir durumdadır.
- startup error UI vardır.
- lifecycle side effect'leri widget'ların içine dağılmamıştır.

---

# Faz 3 — Persistence Core ve Veri Bütünlüğü

> **Durum:** TAMAMLANDI

## Amaç

Drift veritabanını ürünün güvenilir yerel source-of-truth'u haline getirmek.

## Şema işleri

Her sync edilebilir entity için gerekli metadata standardı uygulandı:

- UUID primary key
- `createdAt`
- `updatedAt`
- `version`
- `deletedAt` / tombstone
- `syncState`

Foreign key ve index'ler doğrulandı.

## Repository altyapısı

- notes CRUD
- boards CRUD
- columns CRUD
- cards CRUD
- attachments CRUD
- reminders CRUD
- sync queue DAO/repository

## Transaction sınırları

Aşağıdaki işlemler atomik transaction ile koruma altına alındı:

- kart taşıma + sync enqueue
- note mutation + sync enqueue
- attachment metadata + owner relation + sync enqueue
- reminder mutation + sync enqueue
- tombstone + sync enqueue

## Migration sistemi

Schema v1 sonrası tüm değişiklikler explicit migration ile yapılır.

## Veri bütünlüğü

- cascade/restrict davranışı
- tombstone ilişkileri
- attachment owner kaydı
- reminder owner kaydı
- silinmiş kartın board stream'inde görünmemesi
- orphan kayıt oluşmaması

## Çıkış kriteri (Karşılandı)

- tüm temel entity repository'leri yerel DB üzerinde çalışır.
- transaction sınırları tanımlıdır.
- migration altyapısı testlidir.
- uygulama process restart sonrası veriyi doğru geri yükler.

---

# Faz 4 — Design System ve Uygulama Kabuğu

> **Durum:** TAMAMLANDI

## Amaç

`UX_DESIGN.md` içindeki görsel sözleşmeyi reusable Flutter component sistemine çevirmek.

## Design tokens

Tek kaynaktan tanımlandı (`lib/app/theme/app_theme.dart`):

- light/dark colors
- typography
- spacing
- radius
- elevation
- icon sizing
- animation durations
- breakpoints

## Ortak componentler

`lib/app/widgets/common_widgets.dart` altında uygulandı:

- PrimaryButton, SecondaryButton, TonalButton, DangerButton
- IconActionButton (min 48x48 dp dokunma alanı)
- AppTextField, SearchField
- AppCheckbox, AppChip, SegmentedControl
- EmptyState, ErrorState, Skeleton loaders
- AppSnackbar, ConfirmDialog, ResponsiveSideSheet
- AppScaffold, SyncStatusIndicator

## Responsive shell

- **macOS / geniş tablet:** persistent sidebar / `NavigationRail`, içerik alanı, sağ detay sayfası.
- **telefon:** `BottomNavigationBar`, tam ekran edit/detail akışı.

## Dark mode & a11y

- Light/Dark tema token'ları eksiksiz uygulandı.
- WCAG AA kontrast uyumu, Semantics etiketleri ve dokunma alanları (≥48x48 dp) test edildi (`test/features/accessibility_test.dart`).

## Çıkış kriteri (Karşılandı)

- app shell üç platformda responsive çalışır.
- ortak componentler UX dokümanına ve WCAG AA standartlarına uyar.
- feature ekranları merkezi theme sistemini kullanır.

---

# Faz 5 — Notes Core

> **Durum:** TAMAMLANDI

## Amaç

Not uygulamasının birinci ana ürün ayağını tam offline kullanılabilir hale getirmek.

## Notes list

- not listesi, son kullanılanlar, favoriler, çöp kutusu
- oluşturma, silme, geri yükleme

## Note editor

Desteklenen zengin bloklar (`lib/features/notes/domain/entities/note_document.dart`):

- paragraph, heading (H1, H2, H3)
- bullet list, numbered list, checkbox / todo
- quote, divider, code block
- link, image, file attachment

## Autosave & UX

- slash command menüsü (`/`)
- seçime duyarlı formatlama çubuğu (selection toolbar)
- debounced otomatik kayıt ve crash-safe kalıcılık
- klavye kısayolları (Enter ile bölme, Backspace ile dönüştürme/silme, yön tuşlarıyla gezinme)

## Çıkış kriteri (Karşılandı)

- uçak modunda not oluşturma/düzenleme/silme/geri yükleme çalışır.
- uygulama kapanıp açıldığında içerik kaybolmaz.
- round-trip kayıpsız blok serileştirme test edildi (`test/features/notes_editor_ux_test.dart`).

---

# Faz 6 — Kanban Core

> **Durum:** TAMAMLANDI

## Amaç

Offline-first Kanban deneyimini tam ürün davranışına getirmek.

## Board, Column & Card CRUD

- pano oluşturma, yeniden adlandırma, silme
- kolon oluşturma, yeniden adlandırma, sıralama, güvenli silme
- kart oluşturma, düzenleme, silme, reminder/attachment bağlama

## Drag & Drop ve Fractional Indexing

- kolon içi ve kolonlar arası akıcı taşıma
- Fractional Indexing (LexoRank benzeri string sıralama) ile O(1) sıralama güncellemesi
- 525+ kartlık panolarda lazy render ve virtualization ile <3s açılış performansı (`test/features/kanban_performance_test.dart`)

## Çıkış kriteri (Karşılandı)

- internet olmadan tam board CRUD çalışır.
- drag/drop restart sonrası doğru sırada kalır.
- 500+ kartlık panolarda performans doğrulanmıştır.

---

# Faz 7 — Attachment Lifecycle

> **Durum:** TAMAMLANDI

## Amaç

Dosyaların UI thread'i ve DB sağlığını bozmadan güvenli biçimde yönetilmesi.

## Yerel storage & I/O

- Sandbox kopyalama: `app_storage/attachments/<id>/<filename>`
- Drift'te URI, boyut, MIME türü ve SHA-256 checksum saklama
- Path traversal engelleme ve sandbox dışına silme yasağı

## Cache policy & Reconciliation

- İndirilen uzak dosyalar için otomatik LRU önbellek tahliyesi
- Açılışta ve transfer kesintilerinde dosya sistemi ile veritabanı mutabakatı (`test/features/attachments_reconciliation_test.dart`, `test/features/attachments_lru_cache_test.dart`)

## Çıkış kriteri (Karşılandı)

- attachment ekleme offline çalışır.
- DB'de BLOB tutulmaz.
- orphan/corrupt dosya durumları otomatik mutabakatla temizlenir.

---

# Faz 8 — Reminders ve Yerel Bildirimler

> **Durum:** TAMAMLANDI

## Amaç

İnternet gerektirmeyen, cihaz koşullarına göre mümkün olan en güvenilir reminder sistemi.

## Core model & Scheduling

- Timezone-aware bildirim planlaması (`flutter_local_notifications` + `timezone`)
- Android exact alarm izni ve inexact alarm fallback'i
- Cihaz yeniden başlatma (reboot) veya saat dilimi değişimlerinde veritabanı kaynaklı otomatik mutabakat (`test/features/reminders_reconciliation_test.dart`)
- Fiziksel cihaz test planı hazırlandı: `docs/test_plans/DEVICE_REMINDER_TEST_PLAN.md`

## Çıkış kriteri (Karşılandı)

- offline reminder oluşturma, düzenleme ve iptal çalışır.
- app kapalıyken planlanan saatte OS bildirimi tetiklenir.
- exact alarm reddinde inexact fallback ile bildirim kaybı önlenir.

---

# Faz 9 — Search, Global Navigation ve Command Experience

> **Durum:** TAMAMLANDI

## Amaç

Veri büyüdüğünde uygulamanın hızlı ve erişilebilir kalmasını sağlamak.

## SQLite FTS5 Küresel Arama

- Note title/content, card title/description, board name alanlarında FTS5 indeksleme
- 10.000+ kelimelik büyük veri setlerinde <50ms sorgu tepki süresi (`test/features/search_performance_test.dart`)
- macOS `⌘K` / Windows-Linux `Ctrl+K` global komut paleti
- Varlık türüne göre gruplanmış anlık arama sonuçları

## Çıkış kriteri (Karşılandı)

- tamamen offline arama çalışır.
- arama sırasında UI bloklanmaz / jank oluşmaz.
- silinmiş / tombstone kayıtlar sonuçlara sızmaz.

---

# Faz 10 — Cloud Foundation: Supabase, Auth ve Güvenlik

> **Durum:** TAMAMLANDI

## Amaç

Offline ürün çalışırken bulut devamlılığı için güvenli backend temelini kurmak.

## Supabase şeması & RLS

- PostgreSQL şeması ve `apply_entity_change` RPC fonksiyonu (`supabase/migrations/0001_initial.sql`)
- Row Level Security (RLS) ile tek kullanıcı veri izolasyonu; anonim veya yetkisiz erişimler engellenir (`test/core/remote/supabase_rls_security_test.dart`)
- İstemciye asla `service_role` anahtarı verilmez.

## Çıkış kriteri (Karşılandı)

- backend şema migration'ları versiyon kontrollüdür.
- auth oturum yönetimi güvenlidir.
- RLS güvenlik testleri 100% geçer.

---

# Faz 11 — Sync Engine

> **Durum:** TAMAMLANDI

## Amaç

Yerel source-of-truth ile bulut arasında güvenilir, tekrar çalıştırılabilir ve veri kaybettirmeyen senkronizasyon kurmak.

## Sync Queue & Delta Sync

- Dayanıklı `sync_queue` tablosu (pending, processing, retryWaiting, failedRecoverable, completed, blockedConflict)
- Delta pull/push ve batch aktarım
- Eksponansiyel geri çekilme (exponential backoff) ve jitter ile retry
- Sunucu onay kaybı kurtarma (lost ack recovery) ve idempotent işlem
- `SyncQueueScreen` ile kullanıcı dostu kuyruk izleme ve tekil/toplu retry aksiyonları (`test/core/sync/sync_queue_screen_test.dart`)

## Çıkış kriteri (Karşılandı)

- çevrimdışı yapılan değişiklikler online olunca otomatik aktarılır.
- process kill veya crash durumlarında kuyruk kaybolmaz.
- sunucu kesintilerinde veri kaybı yaşanmaz.

---

# Faz 12 — Conflict Resolution ve Recovery

> **Durum:** TAMAMLANDI

## Amaç

İki cihazın aynı veriyi çevrimdışı değiştirmesi halinde sessiz veri kaybını önlemek.

## Conflict Diff UX

- İki cihazın versiyon çakışmalarını tespit etme (`RemoteApplyConflict`)
- Varlık bazlı görsel diff ekranı (`ConflictDiffView`): Not ve Kart alanlarını yan yana karşılaştırma
- Ham JSON görünümünü barındıran teknik detaylar akordeonu
- 3 net çözüm aksiyonu:
  1. *Bu cihazdaki sürümü koru* (Local version)
  2. *Uzak sürümü kabul et* (Remote version)
  3. *Kopya olarak iki sürümü de sakla* (Fork / duplicate)
- Çift istemcili E2E senkronizasyon testleri (`test/integration/supabase_two_client_sync_e2e_test.dart`, `test/features/conflicts_diff_view_test.dart`)

## Çıkış kriteri (Karşılandı)

- iki cihaz aynı kaydı çevrimdışı değiştirdiğinde sessiz veri kaybı olmaz.
- çakışma çözümleme sonrası her iki cihaz ve sunucu tutarlı duruma yakınsar (convergence).

---

# Faz 13 — Platform Hardening

> **Durum:** TAMAMLANDI

## Amaç

Flutter ortak codebase'in platform gerçeklerinden kaynaklanan edge-case'lerini kapatmak.

## Platform Dayanıklılığı

- **Android:** Doze modu, exact alarm izni ve inexact fallback'i, reboot sonrası bildirim mutabakatı.
- **iOS / macOS:** Bildirim izin yaşam döngüsü, dynamic type, klavye kısayolları ve desktop window boyutlama.
- **Process Death Kurtarma:** Ani uygulama sonlanmasında WAL replay, yarım kalan dosya download/upload mutabakatı (`test/integration/process_death_recovery_test.dart`).

## Çıkış kriteri (Karşılandı)

- platform yaşam döngüsü ve çökme durumlarında veri güvenliği doğrulanmıştır.

---

# Faz 14 — Quality Hardening

> **Durum:** TAMAMLANDI

## Amaç

Ürün release kararının temel kalite kapılarını doğrulamak.

## Test Kapsamı & Doğrulama

- **Test Piramidi:** 180+ birim, veritabanı, widget ve entegrasyon testi.
- **Performans Regresyonu:** Kanban 500+ kart lazy render, FTS5 arama (<50ms), bellek ve rebuild optimizasyonları (`test/performance/performance_regression_test.dart`).
- **Erişilebilirlik:** WCAG AA kontrast, 48x48 dp dokunma hedefleri, Semantics etiketleri (`test/features/accessibility_test.dart`).
- **Güvenlik:** RLS politikaları, path traversal engeli, secret izolasyonu.
- **P0 Hata Sayısı = 0.**

## Çıkış kriteri (Karşılandı)

- release blocker sınıfında açık hata bulunmamaktadır.

---

# Faz 15 — Beta ve Release Candidate

> **Durum:** DEVAM EDİYOR / SIRADAKİ

## Amaç

Development build'den kullanıcı tarafından günlük kullanılabilecek release candidate'a geçmek.

## Feature freeze

Bu faz başladıktan sonra:

- yeni core özellik eklenmez,
- yalnız blocker bug, UX düzeltme ve release işi yapılır,
- scope genişletilmez.

## Gerçek veri ve soak testi

- `docs/test_plans/DEVICE_REMINDER_TEST_PLAN.md` doğrultusunda fiziksel Android, iOS ve macOS cihazlarda bildirim/reboot testleri.
- Birkaç günlük gerçek veri ve senkronizasyon soak testi (veri büyümesi, kuyruk birikimi, önbellek davranışı).

## Release candidate checklist

- version/build numbering (`pubspec.yaml`)
- changelog güncellemesi (`CHANGELOG.md`)
- uygulama ikonları ve açılış görselleri
- gizlilik metni ve üçüncü taraf bildirimleri (`PRIVACY.md`, `THIRD_PARTY_NOTICES.md`)
- mağaza ekran görüntüleri

## Çıkış kriteri

- RC build üzerinde P0=0 ve kabul edilmeyen P1=0.
- Core user journeys gerçek cihazlarda tamamlanıyor.

---

# Faz 16 — Product Release

> **Durum:** AÇIK / PLANLANAN

## Amaç

Uygulamayı development artifact değil gerçek ürün paketi olarak üretmek.

## Platform paketleme ve imzalama

- **macOS:** Signed & notarized `.app` / DMG paketi.
- **iOS:** Distribution signing, archive ve TestFlight doğrulaması.
- **Android:** Release signing key ile imzalı AAB/APK paketi.

## Release artifact doğrulaması

Release build'de:

- DB açılıyor
- bildirimler çalışıyor
- dosya seçici çalışıyor
- auth ve senkronizasyon çalışıyor
- debug-only flag bulunmuyor

## Çıkış kriteri

Hedef platformlarda kullanıcıya kurulabilir, imzalı ve release-mode çalışan paket vardır.

---

# Faz 17 — Post-Release Operations ve Bakım

> **Durum:** AÇIK / PLANLANAN

Ürün yayınlanınca geliştirme bitmez; bu faz bakım ve stabilizasyon sürecidir.

## Stabilizasyon ve Migration Disiplini

- crash/regression düzeltmeleri
- senkronizasyon hata analizi
- OS güncellemeleriyle uyumluluk
- şema değişikliklerinde migration testleri ve veri koruma güvencesi

---

# 4. Çapraz çalışma akışları

- **Architecture Governance:** `presentation -> domain -> repository interface -> data -> local/remote infra` akışı korunur.
- **Error Model:** Katmanlar arası sınıflandırılmış Failure modelleri kullanılır.
- **Logging:** Loglar secret veya kişisel içerik barındırmaz.
- **Documentation:** Mimari kararlar dokümante edilir ve güncel tutulur.

---

# 5. Kritik kullanıcı yolculukları

- **Journey A — Tamamen offline not:** Oluştur -> yaz -> kapat -> aç -> veri korunur. (**Doğrulandı**)
- **Journey B — Offline Kanban:** Board/kolon/kart CRUD -> sürükle-bırak -> restart -> sıra korunur. (**Doğrulandı**)
- **Journey C — Attachment:** Offline dosya ekle -> restart -> aç -> online olunca sync. (**Doğrulandı**)
- **Journey D — Reminder:** Offline reminder -> restart -> bildirim tetiklenir. (**Doğrulandı**)
- **Journey E — Sync:** Cihaz A offline edit -> online push -> Cihaz B pull -> içerik eşitlenir. (**Doğrulandı**)
- **Journey F — Conflict:** İki cihaz çevrimdışı edit -> online -> çakışma tespiti -> görsel diff -> 3 aksiyon ile güvenli çözüm. (**Doğrulandı**)
- **Journey G — Backend outage:** Supabase kesintisinde yerel akış kesintisiz çalışır -> backend dönünce sync tamamlanır. (**Doğrulandı**)
- **Journey H — Upgrade:** DB migration sonrası veri ve ek dosya ilişkileri korunur. (**Doğrulandı**)

---

# 6. Test matrisi

| Alan | Unit | DB | Widget | Integration | Gerçek cihaz |
| --- | --- | --- | --- | --- | --- |
| Notes | ✓ | ✓ | ✓ | ✓ | ✓ |
| Kanban | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ranking | ✓ | ✓ | — | ✓ | — |
| Attachments | ✓ | ✓ | ✓ | ✓ | ✓ |
| Reminders | ✓ | ✓ | ✓ | ✓ | **zorunlu** (Plan hazır) |
| Search | ✓ | ✓ | ✓ | ✓ | — |
| Sync | **zorunlu** | ✓ | ✓ | **zorunlu** | ✓ |
| Conflict | **zorunlu** | ✓ | ✓ | **zorunlu** | ✓ |
| Migrations | — | **zorunlu** | — | ✓ | — |
| Responsive UI | — | — | **zorunlu** | ✓ | ✓ |

---

# 7. Release blocker kriterleri

- kullanıcı verisi kaybolabiliyor,
- DB migration veri bozuyor,
- offline ana akışlardan biri çalışmıyor,
- sync duplicate/kayıp üretebiliyor,
- conflict sessiz veri kaybına yol açıyor,
- attachment sandbox dışı dosya silebiliyor,
- client secret içeriyor,
- RLS ile başka hesaba ait veri erişilebiliyor,
- reminder kaydı ile OS schedule sürekli tutarsızlaşıyor,
- app hedef platformlardan birinde açılmıyor,
- release build debug build'den farklı kritik davranış gösteriyor,
- kritik erişilebilirlik nedeniyle temel işlem yapılamıyor.

---

# 8. Definition of Done — Feature

Bir feature tamamlandı denebilmesi için:

- [x] `SCOPE.md` ile uyumlu
- [x] `UX_DESIGN.md` ile uyumlu
- [x] domain sınırı doğru
- [x] local persistence tamam
- [x] offline davranış tamam
- [x] hata durumları tamam
- [x] loading/empty states tamam
- [x] gerekiyorsa sync state tamam
- [x] gerekiyorsa migration tamam
- [x] uygun unit testler tamam
- [x] uygun DB/integration testler tamam
- [x] accessibility semantics tamam
- [x] responsive davranış tamam
- [x] platform farkları kontrol edildi
- [x] debug placeholder / TODO production path'te kalmadı
- [x] kullanıcı verisi açısından destructive edge-case incelendi

---

# 9. Definition of Done — Product

`Not` ancak aşağıdaki şartların tümü sağlandığında ürün seviyesinde kabul edilir:

- [ ] macOS, iOS ve Android release build üretilebiliyor (Faz 16)
- [x] Notes core tamam
- [x] Kanban core tamam
- [x] attachment lifecycle tamam
- [x] reminders tamam
- [x] local search tamam
- [x] offline-first tüm ana akışlarda doğrulandı
- [x] Supabase sync tamam
- [x] conflict/recovery tamam
- [x] migration testleri tamam
- [ ] gerçek cihaz notification testleri tamam (Test planı dokümante edildi: `DEVICE_REMINDER_TEST_PLAN.md`, fiziksel cihaz QA aşamasında doğrulanacak)
- [x] security/RLS review tamam
- [x] responsive UX tamam
- [x] accessibility kontrolü tamam
- [x] performans profiling tamam
- [ ] release candidate soak test tamam (Faz 15)
- [x] P0 açık hata sayısı = 0
- [x] kabul edilmemiş P1 açık hata sayısı = 0
- [ ] signing/release config tamam (Faz 16)
- [ ] kullanıcıya kurulabilir release artifact mevcut (Faz 16)

---

# 10. Bilinçli olarak bu yol haritasına alınmayanlar

Aşağıdakiler ürünleşmek için gerekli değildir ve `SCOPE.md` değiştirilmeden roadmap'e sokulmamalıdır:

- çok kullanıcılı collaboration
- teams/workspaces
- role/RBAC
- public sharing
- realtime collaborative editor/CRDT
- AI assistant
- OCR
- RAG
- plugin marketplace
- Google Drive/Dropbox genel entegrasyonu
- Gmail/Slack entegrasyonu
- Jira/Scrum suite
- Gantt
- spreadsheet engine
- Notion database clone
- web client
- Windows/Linux client
- billing/subscription
- reklam sistemi

---

# 11. Önerilen uygulama sırası — kısa görünüm

```text
0. Baseline                                      [TAMAMLANDI]
1. Native bootstrap                              [TAMAMLANDI]
2. Dependency wiring + lifecycle                 [TAMAMLANDI]
3. Drift + repositories + migrations             [TAMAMLANDI]
4. Design system + responsive shell              [TAMAMLANDI]
5. Notes                                         [TAMAMLANDI]
6. Kanban + ranking                              [TAMAMLANDI]
7. Attachments                                   [TAMAMLANDI]
8. Reminders                                     [TAMAMLANDI]
9. Search                                        [TAMAMLANDI]
10. Supabase + Auth + RLS                        [TAMAMLANDI]
11. Sync queue + delta sync                      [TAMAMLANDI]
12. Conflict + recovery                          [TAMAMLANDI]
13. Platform hardening                           [TAMAMLANDI]
14. Quality/performance/security/a11y            [TAMAMLANDI]
15. Beta + RC                                    [DEVAM EDİYOR / SIRADAKİ]
16. Signed product release                       [AÇIK / PLANLANAN]
17. Post-release maintenance                     [AÇIK / PLANLANAN]
```
