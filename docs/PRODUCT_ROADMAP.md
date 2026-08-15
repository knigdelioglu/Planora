# Not — Ürünleşme Yol Haritası

> Durum: Ürün geliştirme için bağlayıcı yürütme planı  
> Başlangıç noktası: Mevcut mimari ve kaynak kod iskeleti  
> Hedef: macOS, iOS ve Android üzerinde güvenilir şekilde çalışan, tek kullanıcılı, offline-first ürün sürümü  
> İlişkili belgeler: `README.md`, `docs/SCOPE.md`, `docs/UX_DESIGN.md`

Bu belge `Not` uygulamasının mevcut repo durumundan ürün seviyesine ulaşmasına kadar gereken geliştirme, doğrulama ve yayın süreçlerini sıralı fazlara böler.

Bu yol haritası bir özellik istek listesi değildir. Her fazın:

- amacı,
- kapsamı,
- teknik işleri,
- UX işleri,
- veri/migration etkileri,
- test ve doğrulama gereksinimleri,
- çıkış kriterleri

açıkça tanımlanmıştır.

Bir fazın çıkış kriterleri karşılanmadan sonraki faz **tamamlanmış** kabul edilmez.

---

# 0. Yürütme kuralları ve belge otoritesi

Geliştirme boyunca karar önceliği aşağıdaki sıradadır:

1. `docs/SCOPE.md` — ürünün neyi yapıp yapmayacağını belirler.
2. `docs/UX_DESIGN.md` — ekran, component ve kullanıcı davranışlarını belirler.
3. `docs/PRODUCT_ROADMAP.md` — geliştirme sırası ve kalite kapılarını belirler.
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

# 1. Mevcut durum — Baseline

Repo şu anda ürün değil, mimari açıdan hazırlanmış bir başlangıç iskeletidir.

## Mevcut olanlar

- Flutter/Dart proje metadata ve bağımlılık tanımları
- `lib/main.dart`
- app/router/theme başlangıç yapısı
- Feature-First Clean Architecture klasör yapısı
- Drift database tanımı
- temel tablolar:
  - boards
  - board columns
  - cards
  - notes
  - attachments
  - reminders
  - sync queue
- yerel DB connection katmanı
- network abstraction
- dosya storage abstraction
- notification abstraction
- sync coordinator iskeleti
- fractional indexing helper başlangıcı
- Kanban domain/repository/use-case/controller iskeleti
- notes / attachments / reminders feature sınırları
- `.gitignore`
- `.env.example`
- bağlayıcı `SCOPE.md`
- bağlayıcı `UX_DESIGN.md`

## Henüz ürün seviyesinde olmayanlar

- native Android/iOS/macOS proje bootstrap'ının doğrulanması
- dependency wiring / composition root
- Drift generated kod ve migration test altyapısının doğrulanması
- gerçek repository implementasyonlarının tamamı
- tam CRUD akışları
- gerçek note editor
- tamamlanmış Kanban UI
- güvenilir attachment lifecycle
- gerçek notification scheduler
- Supabase backend şeması ve güvenlik politikaları
- auth + sync entegrasyonu
- conflict resolution
- yerel full-text search
- cache eviction
- lifecycle reconciliation
- production error handling
- telemetry/diagnostics politikası
- release signing
- mağaza metadata
- release QA

Bu nedenle mevcut durum **Phase 0 / Architecture Skeleton** olarak kabul edilir.

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

| Faz | Başlık | Ana çıktı |
| --- | --- | --- |
| 0 | Baseline | Mimari ve dokümantasyon iskeleti |
| 1 | Platform Bootstrap | Android/iOS/macOS üzerinde çalışan temiz uygulama |
| 2 | Composition Root & Foundations | Gerçek dependency wiring ve app lifecycle |
| 3 | Persistence Core | Production-ready Drift + migration + transaction altyapısı |
| 4 | Design System & App Shell | UX sözleşmesine uygun ortak UI sistemi |
| 5 | Notes Core | Tam çalışan offline not akışı |
| 6 | Kanban Core | Tam çalışan offline Kanban ve fractional ranking |
| 7 | Attachments | Güvenilir yerel dosya lifecycle ve cache |
| 8 | Reminders | OS seviyesinde güvenilir yerel reminder sistemi |
| 9 | Search & Navigation | Yerel global arama ve command/navigation deneyimi |
| 10 | Cloud Foundation | Supabase şema, auth ve güvenlik tabanı |
| 11 | Sync Engine | Delta sync, queue, retry, tombstone ve dosya sync |
| 12 | Conflict & Recovery | Çok cihaz conflict ve veri kurtarma güvenliği |
| 13 | Platform Hardening | Android/iOS/macOS özel yaşam döngüsü ve izin davranışları |
| 14 | Quality Hardening | Test, performans, güvenlik, erişilebilirlik, hata dayanıklılığı |
| 15 | Beta / Release Candidate | Gerçek cihaz kabul testi ve release freeze |
| 16 | Product Release | İmzalı ürün paketleri ve dağıtım |
| 17 | Post-Release Operations | Stabilizasyon, migration disiplini ve bakım |

Faz sırası bağımlılık sırasıdır. Bazı alt işler paralel yürütülebilir ancak kalite kapıları korunur.

---

# Faz 1 — Platform Bootstrap

## Amaç

Mevcut Dart/Flutter kaynak iskeletini gerçek Android, iOS ve macOS projeleriyle güvenli biçimde birleştirmek ve üç platformda minimum uygulama kabuğunu çalıştırmak.

## İşler

### Flutter/native proje

- `android/`, `ios/`, `macos/` native klasörlerini oluştur.
- mevcut `lib/`, `pubspec.yaml`, `.gitignore` ve dokümantasyonu koru.
- bundle/application identifiers belirle.
- Android minSdk/targetSdk politikasını sabitle.
- iOS deployment target belirle.
- macOS deployment target belirle.
- app display name ve internal package name tutarlılığını sağla.

### Native permissions başlangıcı

Henüz özellikler tamamlanmasa da ileride gerekecek izin noktalarını belgeleyerek hazırla:

- local notifications
- Android exact alarms
- file picker erişimi
- platform storage davranışları

Gereksiz izin ekleme.

### Build yapılandırması

- debug/profile/release ayrımını kur.
- secret'ların source control'e girmediğini doğrula.
- `--dart-define` veya güvenli config strategy standardını belirle.

## Çıkış kriteri

- macOS debug build açılıyor.
- Android debug build açılıyor.
- iOS simulator/device debug build açılıyor.
- uygulama temel shell ekranına crash olmadan geliyor.
- platform klasörlerinin hiçbirinde secret commit edilmiyor.

---

# Faz 2 — Composition Root, Dependency Wiring ve App Lifecycle

## Amaç

Şu anda placeholder olan provider/repository bağlantılarını gerçek dependency graph'a dönüştürmek.

## İşler

### Composition root

Tek bir bootstrap katmanında oluştur:

- `AppDatabase`
- repository implementations
- file storage service
- notification service
- network info
- sync coordinator
- config
- clock/time abstractions gerekiyorsa

Presentation katmanında `UnimplementedError` tabanlı production provider bırakma.

### Lifecycle

Uygulama başlatılırken deterministik sıra:

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

- blank screen gösterme,
- crash loop oluşturma,
- recovery/fatal startup ekranı göster,
- tekrar deneme ve güvenli hata raporu sağla.

## Çıkış kriteri

- production path'te `UnimplementedError` provider kalmaz.
- app dependency graph merkezi ve test edilebilir durumdadır.
- startup error UI vardır.
- lifecycle side effect'leri widget'ların içine dağılmamıştır.

---

# Faz 3 — Persistence Core ve Veri Bütünlüğü

## Amaç

Drift veritabanını ürünün güvenilir yerel source-of-truth'u haline getirmek.

## Şema işleri

Her sync edilebilir entity için gerekli metadata standardını kesinleştir:

- UUID
- `createdAt`
- `updatedAt`
- `version`
- `deletedAt` / tombstone
- gerekiyorsa sync state

Foreign key ve index'leri doğrula.

## Repository altyapısı

- notes CRUD
- boards CRUD
- columns CRUD
- cards CRUD
- attachments CRUD
- reminders CRUD
- sync queue DAO/repository

UI doğrudan Drift DAO kullanmamalı.

## Transaction sınırları

Özellikle şu işlemler atomik olmalı:

- kart taşıma + sync enqueue
- note mutation + sync enqueue
- attachment metadata + owner relation + sync enqueue
- reminder mutation + sync enqueue
- tombstone + sync enqueue

## Migration sistemi

Schema v1 sonrası tüm değişiklikler explicit migration ile yapılır.

Kurallar:

- destructive reset production çözümü değildir,
- migration ileri yönde deterministic olmalı,
- DB açılışı migration hatasını kontrollü ele almalı,
- migration test fixture'ları saklanmalı.

## Veri bütünlüğü

Test edilmesi gerekenler:

- cascade/restrict davranışı
- tombstone ilişkileri
- attachment owner kaydı
- reminder owner kaydı
- silinmiş kartın board stream'inde görünmemesi
- orphan kayıt oluşmaması

## Çıkış kriteri

- tüm temel entity repository'leri yerel DB üzerinde çalışır.
- transaction sınırları tanımlıdır.
- migration altyapısı testlidir.
- uygulama process restart sonrası veriyi doğru geri yükler.

---

# Faz 4 — Design System ve Uygulama Kabuğu

## Amaç

`UX_DESIGN.md` içindeki görsel sözleşmeyi reusable Flutter component sistemine çevirmek.

## Design tokens

Tek kaynaktan tanımla:

- light/dark colors
- typography
- spacing
- radius
- elevation
- icon sizing
- animation durations
- breakpoints

Magic number'ları ekranlara dağıtma.

## Ortak componentler

En az:

- PrimaryButton
- SecondaryButton
- TonalButton
- DangerButton
- IconActionButton
- AppTextField
- SearchField
- AppCheckbox
- AppChip
- SegmentedControl
- EmptyState
- ErrorState
- Skeleton loaders
- AppSnackbar
- ConfirmDialog
- ResponsiveSideSheet
- AppScaffold
- SyncStatusIndicator

## Responsive shell

### macOS / geniş tablet

- persistent sidebar/navigation rail
- içerik workspace
- gerektiğinde right-side detail sheet

### telefon

- bottom navigation
- tam ekran edit/detail akışı
- bottom sheet uygun yerlerde

## Dark mode

Light theme sonrası mekanik inversion yapılmaz; UX belgesindeki dark token'lar uygulanır.

## Çıkış kriteri

- app shell üç platformda responsive.
- ortak componentler UX dokümanına uyuyor.
- feature ekranları kendi bağımsız button/theme implementasyonlarını üretmiyor.

---

# Faz 5 — Notes Core

## Amaç

Not uygulamasının birinci ana ürün ayağını tam offline kullanılabilir hale getirmek.

## Notes list

- not listesi
- son kullanılanlar
- favoriler
- çöp kutusu
- oluşturma
- silme
- geri yükleme
- permanent delete gerekiyorsa scope sınırına uygun güvenli akış

## Note editor

İlk ürün kapsamındaki blokları uygula:

- paragraph
- heading
- bullet list
- numbered list
- checkbox
- quote
- divider
- code block
- link
- image
- file attachment

## Editor veri modeli

Editor için tek bir kontrolsüz büyük text blob yerine uzun vadeli migration'ı mümkün kılan açık bir içerik formatı tanımla.

Gereksinimler:

- forward compatibility
- bilinmeyen block type'ı yüzünden tüm notun açılamaz hale gelmemesi
- deterministic serialization
- autosave
- debounce
- crash-safe persistence

## Autosave

- manuel Save zorunlu değil.
- kullanıcı yazarken UI beklemez.
- local persistence belirli debounce ile çalışır.
- uygulama arka plana giderken pending write flush edilir.

## UX

- slash command
- selection toolbar
- empty note state
- autosave/sync göstergesi
- keyboard shortcuts
- mobile keyboard ergonomisi

## Çıkış kriteri

- uçak modunda not oluşturma/düzenleme/silme/geri yükleme çalışır.
- uygulama kapanıp açıldığında içerik kaybolmaz.
- desteklenen block formatları round-trip kayıpsızdır.
- uzun notlarda editor kullanılabilir performanstadır.

---

# Faz 6 — Kanban Core

## Amaç

Offline-first Kanban deneyimini tam ürün davranışına getirmek.

## Board

- pano oluşturma
- yeniden adlandırma
- silme
- boş durum

## Columns

- oluşturma
- yeniden adlandırma
- sıralama
- silme davranışı
- kart bulunan kolonda güvenli silme UX'i

## Cards

- oluşturma
- title
- description
- düzenleme
- silme
- reminder ilişkilendirme noktası
- attachment ilişkilendirme noktası

## Drag & drop

Destekle:

- kolon içi taşıma
- kolonlar arası taşıma
- optimistic UI
- drag placeholder
- edge auto-scroll
- keyboard/accessibility alternatifi

## Fractional indexing

Üretim stratejisini kesinleştir.

Temel kurallar:

- her taşıma tüm listeyi O(N) re-index etmemeli,
- yalnız gerekli kart/rank değişmeli,
- eşit veya aşırı yakın rank durumları algılanmalı,
- kontrollü rebalance mekanizması bulunmalı,
- ranking deterministik olarak sıralanmalı.

`double` tabanlı geçici yaklaşım uzun vadeli conflict davranışı açısından yeterli değilse stable sortable key/string rank modeline geçiş bu fazda yapılır; sync sonrasına bırakılmaz.

## Çıkış kriteri

- internet olmadan tam board CRUD çalışır.
- drag/drop restart sonrası doğru sırada kalır.
- 500+ kartlık sentetik board üzerinde kabul edilebilir UI performansı vardır.
- rank edge-case testleri geçer.

---

# Faz 7 — Attachment Lifecycle

## Amaç

Dosyaların UI thread'i ve DB sağlığını bozmadan güvenli biçimde yönetilmesi.

## Yerel storage

Standart yapı:

```text
app_storage/
└── attachments/
    └── <attachment-id>/
        └── <filename>
```

## Akış

1. user file selection
2. validation
3. unique attachment id
4. sandbox copy
5. size/hash metadata
6. DB transaction
7. owner relation
8. sync enqueue
9. background remote upload ileride

## I/O

Büyük dosya işlemlerinde:

- UI isolate/thread bloklanmamalı,
- gereksiz full-memory read yapılmamalı,
- progress sunulmalı,
- iptal mümkünse desteklenmeli.

## Güvenlik

- user filename path olarak kör kullanılmamalı,
- path traversal engellenmeli,
- allowed sandbox root dışına silme yapılamamalı,
- MIME uzantı uyumsuzluğu kritik işlemlerde dikkate alınmalı.

## Cache policy

İki sınıfı ayır:

1. kullanıcının bu cihazda oluşturduğu/eklediği kalıcı yerel kaynak
2. başka cihazdan indirilmiş yeniden indirilebilir cache

LRU eviction yalnız güvenle yeniden indirilebilir cache üzerinde uygulanır.

## Çıkış kriteri

- attachment ekleme offline çalışır.
- DB'de BLOB yoktur.
- file missing/corrupt durumları kontrollüdür.
- silme orphan file bırakmaz veya reconciliation bunu temizler.

---

# Faz 8 — Reminders ve Yerel Bildirimler

## Amaç

İnternet gerektirmeyen, cihaz koşullarına göre mümkün olan en güvenilir reminder sistemi.

## Core model

Reminder DB record şunları taşımalı:

- entity relation
- timezone-aware schedule
- OS notification identifier
- enabled state
- scheduling status
- last reconciliation metadata

## Scheduling

- create
- reschedule
- cancel
- permission denied state
- exact alarm unavailable state

## Reconciliation

DB source-of-truth kabul edilerek gerektiğinde OS planı ile karşılaştır.

Tetikleyiciler:

- app startup
- reminder mutation
- timezone change handling
- ilgili platform lifecycle olayları
- Android reboot sonrası desteklenen yeniden planlama yolu

## UX

- izin istenmeden önce açıklayıcı pre-permission UI
- permission denied durumunda Settings yönlendirmesi
- geçmiş saate reminder oluşturmayı engelle veya açık UX ile düzelt
- timezone değişiminde sessiz veri bozulması olmasın

## Çıkış kriteri

- offline reminder oluşturma çalışır.
- app kapalıyken bildirim tetiklenir.
- düzenleme/iptal OS schedule'ını günceller.
- restart/reconciliation senaryoları doğrulanır.

---

# Faz 9 — Search, Global Navigation ve Command Experience

## Amaç

Veri büyüdüğünde uygulamanın kullanılabilir kalmasını sağlamak.

## Yerel arama

Aranabilir:

- note title
- note content
- card title
- card description
- board name

## Teknoloji

Veri hacmi arttığında `%LIKE%` taramalarına bağımlı kalmamak için SQLite FTS uygunluğu değerlendirilecek ve gerekiyorsa bu fazda FTS index kurulacaktır.

## UX

- global search
- sonuçları entity type'a göre gruplama
- keyboard navigation
- macOS `⌘K` command palette
- recent search gerekiyorsa yalnız scope içinde basit local history

## Çıkış kriteri

- tamamen offline arama çalışır.
- makul büyük veri setinde typing sırasında UI takılmaz.
- silinmiş/tombstone kayıtlar sonuçlara sızmaz.

---

# Faz 10 — Cloud Foundation: Supabase, Auth ve Güvenlik

## Amaç

Offline ürün çalışırken bulut devamlılığı için güvenli backend temelini kurmak.

## Supabase şeması

Yerel entity modelini kör kopyalamak yerine sync ihtiyaçlarına göre açık schema oluştur.

En az:

- user ownership
- entity ids
- versions
- timestamps
- tombstones
- attachment remote metadata

## Auth

Tek kullanıcı ürün sınırına uygun minimal akış:

- sign in / initial account connection
- session persistence
- sign out
- session expired handling

Auth uygulamanın yerel kullanımını gereksiz yere bloke etmemeli.

## RLS

Her uzak veri yalnız authenticated owner tarafından erişilebilir olmalıdır.

Test et:

- user A user B verisini okuyamaz
- update edemez
- storage object erişim sınırları doğru

## Secret policy

- `service_role` client'a girmez.
- privileged backend key mobil/desktop binary içine gömülmez.
- publishable/anon key tek başına güvenlik sınırı değildir; RLS zorunludur.

## Çıkış kriteri

- backend schema migration/versioning kontrollüdür.
- auth session güvenlidir.
- RLS testleri geçer.
- local-only ürün akışı backend outage sırasında çalışır.

---

# Faz 11 — Sync Engine

## Amaç

Yerel source-of-truth ile bulut arasında güvenilir, tekrar çalıştırılabilir ve veri kaybettirmeyen senkronizasyon kurmak.

## Queue state machine

Önerilen durumlar:

- pending
- processing
- retryWaiting
- failedRecoverable
- completed
- blockedConflict

## Gereksinimler

- idempotency
- retry with exponential backoff + jitter
- attempt limit yerine recoverable/manual states
- process crash sonrası devam
- duplicate send güvenliği
- operation ordering
- entity dependency ordering gerektiğinde

## Push

Local mutation -> local commit -> queue -> remote.

UI remote response beklememeli.

## Pull

- cursor/version tabanlı delta pull
- full data download her sync cycle'da yapılmaz
- remote tombstones uygulanır
- local dirty state üzerine kör overwrite yapılmaz

## Attachment sync

Metadata ve binary transfer birbirinden ayrılır.

- resumability desteklenebiliyorsa kullan
- progress
- retry
- checksum validation
- download cache

## Connectivity

`connectivity_plus` yalnız tetikleyicidir.

“Wi-Fi bağlı” = “internet/Supabase erişilebilir” varsayımı yapılmaz.

Gerçek request sonucu authoritative'dir.

## Çıkış kriteri

- offline değişiklik online olunca otomatik gider.
- process kill sırasında queue kaybolmaz.
- aynı operation tekrar gönderildiğinde duplicate entity yaratılmaz.
- server outage veri kaybına yol açmaz.
- iki cihaz arasında temel veri devamlılığı çalışır.

---

# Faz 12 — Conflict Resolution ve Recovery

## Amaç

Tek kullanıcı olsa dahi iki cihazın aynı veriyi çevrimdışı değiştirmesi halinde sessiz veri kaybını önlemek.

## Conflict detection

Entity mutation sırasında en az:

- base version
- current server version
- local updated time
- remote updated time

karşılaştırılabilir olmalı.

## Otomatik çözülebilecek durumlar

Örneğin farklı alan değişiklikleri güvenli merge edilebiliyorsa entity-specific merge uygulanabilir.

## Manuel conflict

Sessiz overwrite güvenli değilse:

- local version
- remote version
- modified timestamps
- kullanıcıya anlaşılır diff/preview
- “Bu sürümü kullan”
- “Diğer sürümü kullan”
- mümkünse “Kopya olarak sakla”

## Kanban conflicts

Rank/move conflict'leri içerik edit conflict'lerinden ayrı değerlendirilir.

Amaç:

- kart kaybolmaması,
- birden fazla kolonda görünmemesi,
- deterministic final position.

## Recovery

- failed queue inspector
- retry
- recoverable error details
- corrupted/missing attachment state
- sync reset yapılacaksa veri kaybetmeyen kontrollü prosedür

## Çıkış kriteri

- iki cihaz aynı kaydı offline değiştirince sessiz kayıp yoktur.
- conflict UI UX sözleşmesine uygundur.
- queue corruption veya partial failure için recovery yolu vardır.

---

# Faz 13 — Platform Hardening

## Amaç

Flutter ortak codebase'in platform gerçeklerinden kaynaklanan edge-case'lerini kapatmak.

## Android

- Doze davranışı
- exact alarm permission/availability
- reboot reconciliation
- notification channels
- scoped storage sınırları
- back navigation
- process death recovery

## iOS

- notification permission lifecycle
- background execution varsayımlarının sınırlandırılması
- file picker security-scoped URL gerekiyorsa doğru lifecycle
- app termination sonrası local notification davranışı
- dynamic type

## macOS

- desktop window sizing
- min window constraints
- keyboard shortcuts
- menu integration gerekiyorsa
- drag/drop ergonomisi
- hover/focus states
- notification permissions

## Responsive QA

En az:

- küçük telefon
- standart telefon
- büyük telefon/tablet
- portrait/landscape gerekli yerlerde
- küçük Mac window
- geniş desktop window

## Çıkış kriteri

Her hedef platform “Flutter'da açılıyor” seviyesinde değil, kendi input/lifecycle modelinde kullanılabilir durumdadır.

---

# Faz 14 — Quality Hardening

Bu faz ürün release kararının temel kalite kapısıdır.

## 14.1 Test piramidi

### Unit

Özellikle:

- rank generation
- rebalance
- note serialization
- repository business rules
- sync state transitions
- retry/backoff
- conflict detection
- cache policy
- reminder validation

### Database

- migrations
- foreign keys
- transactions
- tombstones
- FTS index
- concurrent-ish mutation scenarios

### Widget

- core screens
- empty/error/loading states
- responsive breakpoints
- accessibility semantics

### Integration

- note create -> restart -> reload
- card move -> restart -> same rank
- attachment -> restart -> open
- reminder schedule -> edit -> cancel
- offline mutation -> reconnect -> sync
- two-device conflict simulation

### Platform/manual

Gerçek Android/iPhone/Mac cihaz üzerinde notification ve lifecycle testleri.

## 14.2 Performance

Profile edilmesi gereken yollar:

- app startup
- database opening
- long notes
- 500+ card boards
- large attachment copy
- global search
- sync burst
- large local dataset

Kurallar:

- UI jank profiler ile incelenir.
- büyük I/O main isolate'ı gereksiz bloke etmez.
- listelerde virtualization kullanılır.
- gereksiz full rebuild azaltılır.

## 14.3 Memory/disk

- attachment cache büyümesi
- temp file cleanup
- orphan cleanup
- DB WAL davranışı
- image decode memory

## 14.4 Security review

- secrets
- RLS
- path traversal
- unsafe file opening
- logs içinde token/kişisel içerik
- local DB/data exposure riskleri
- sign-out davranışı

## 14.5 Accessibility

- screen reader semantics
- focus order
- keyboard navigation
- touch target
- contrast
- text scaling
- reduced motion davranışı

## 14.6 Error UX

Test et:

- disk full
- permission denied
- missing file
- DB migration failure
- backend unavailable
- expired session
- sync conflict
- notification denied
- no exact alarm capability

## Çıkış kriteri

Release blocker sınıfında açık hata yoktur.

P0 tanımı:

- veri kaybı
- veri bozulması
- güvenlik ihlali
- app açılamaması
- temel offline akışın bozulması

P0 = 0 zorunludur.

P1 hatalar ürün release kararında açıkça değerlendirilmeden yayın yapılamaz.

---

# Faz 15 — Beta ve Release Candidate

## Amaç

Development build'den kullanıcı tarafından günlük kullanılabilecek release candidate'a geçmek.

## Feature freeze

Bu faz başladıktan sonra:

- yeni core özellik eklenmez,
- yalnız blocker bug, UX düzeltme ve release işi yapılır,
- scope genişletilmez.

## Gerçek veri testi

Sentetik test dışında gerçek günlük kullanım senaryoları uygulanır:

- onlarca not
- uzun notlar
- birden fazla board
- çok kart
- gerçek PDF/görseller
- reminder'lar
- uçak modu
- ağ gidip gelmesi
- aynı hesapla iki cihaz

## Soak test

Uygulama birkaç günlük gerçek kullanım döngüsünde:

- data growth
- queue accumulation
- cache
- notification reliability
- migration olmayan restart davranışı

açısından gözlenir.

## Release candidate checklist

- version/build numbering
- changelog
- app icons
- splash/startup visual
- permission copy
- privacy metni gerekiyorsa
- store screenshots
- support/contact yolu gerekiyorsa
- license/third-party notices

## Çıkış kriteri

RC build üzerinde P0=0 ve kabul edilmeyen P1=0.

Core user journeys gerçek cihazlarda tamamlanıyor.

---

# Faz 16 — Product Release

## Amaç

Uygulamayı development artifact değil gerçek ürün paketi olarak üretmek.

## macOS

Dağıtım modeline göre:

- signed `.app`
- notarization gerekiyorsa
- DMG/PKG veya Mac App Store paketi
- Gatekeeper doğrulaması

## iOS

- distribution signing
- archive
- TestFlight son doğrulama
- App Store submission seçildiyse metadata/privacy gereksinimleri

## Android

- release signing key güvenli saklama
- AAB/APK release artifact
- Play Console release seçildiyse store metadata/policy kontrolleri

## Release artifact doğrulaması

Debug ortamından bağımsız olarak release build'de:

- DB açılıyor
- notification çalışıyor
- file picker çalışıyor
- auth çalışıyor
- sync çalışıyor
- production config doğru
- debug-only endpoint/flag yok

## Çıkış kriteri

En az hedeflenen dağıtım kanalında kullanıcıya kurulabilir, imzalı ve release-mode çalışan paket vardır.

Bu nokta **ürün aşaması**dır.

---

# Faz 17 — Post-Release Operations ve Bakım

Ürün yayınlanınca geliştirme bitmez; ancak bu faz yeni özellik roadmap'i değildir.

## Stabilizasyon

- crash/regression düzeltmeleri
- sync failure analizi
- platform OS update uyumluluğu
- dependency/security updates

## Migration disiplini

Ürün verisi oluştuktan sonra schema değişiklikleri çok daha risklidir.

Her migration için:

1. old-version fixture
2. migration test
3. data preservation assertion
4. rollback mümkün değilse recovery plan

zorunludur.

## Dependency updates

Paketler otomatik olarak son sürüme kör yükseltilmez.

Özellikle:

- Drift/sqlite
- local notifications
- timezone
- Supabase
- Riverpod

upgrade'leri release note + migration/API impact incelemesiyle yapılır.

## Scope disiplini

Yeni ürün fikirleri doğrudan koda girmez.

Önce:

- `SCOPE.md`
- gerekirse `UX_DESIGN.md`
- ardından yeni roadmap fazı

güncellenir.

---

# 4. Çapraz çalışma akışları

Aşağıdaki işler tek bir faza ait değildir ve proje boyunca uygulanır.

## 4.1 Architecture governance

Her feature için:

```text
presentation
    ↓
domain
    ↓
repository interface
    ↓
data implementation
    ↓
local / remote infrastructure
```

Domain katmanı Flutter UI, Drift veya Supabase SDK'sına bağlanmamalıdır.

## 4.2 Error model

Exception'lar UI'a ham biçimde sızdırılmamalı.

Katmanlar arasında sınıflandırılmış failure modeli kullanılmalı:

- validation
- storage
- database
- permission
- network
- auth
- sync
- conflict
- unknown

## 4.3 Logging

Loglar:

- secret içermemeli,
- full note body gibi özel kullanıcı verisini varsayılan olarak yazmamalı,
- production log level kontrollü olmalı.

## 4.4 Feature flags

Tamamlanmamış özellikler ana kullanıcı akışını bozuyorsa UI'da yarım bırakmak yerine build/config flag arkasında tutulabilir.

## 4.5 Documentation

Önemli mimari kararlar README veya ilgili docs altında güncellenir.

Ancak her küçük refactor için doküman churn yaratılmaz.

---

# 5. Kritik kullanıcı yolculukları

Ürün release öncesi aşağıdaki akışların tamamı çalışmalıdır.

## Journey A — Tamamen offline not

1. internet kapalı
2. uygulama açılır
3. not oluşturulur
4. içerik yazılır
5. uygulama kapatılır
6. tekrar açılır
7. not eksiksiz görünür

## Journey B — Offline Kanban

1. board oluştur
2. kolon oluştur
3. kart oluştur
4. kartları yeniden sırala
5. başka kolona taşı
6. process restart
7. sıralama korunur

## Journey C — Attachment

1. offline dosya ekle
2. not içinde görünür
3. uygulamayı yeniden aç
4. dosyayı aç
5. bağlantı gelince upload
6. ikinci cihazda metadata görünür
7. dosya talep edilince indirilir

## Journey D — Reminder

1. offline reminder oluştur
2. uygulamayı kapat
3. planlanan saatte OS bildirimi gelir
4. reminder düzenlenir
5. eski schedule iptal olur

## Journey E — Sync

1. cihaz A offline edit
2. bağlantı gelir
3. sync tamamlanır
4. cihaz B pull yapar
5. aynı içerik görünür

## Journey F — Conflict

1. A ve B aynı kaydı offline değiştirir
2. ikisi de online olur
3. veri sessizce kaybolmaz
4. otomatik güvenli merge veya conflict UX çalışır

## Journey G — Backend outage

1. Supabase ulaşılamaz
2. kullanıcı not/kart oluşturmaya devam eder
3. local data güvenlidir
4. queue bekler
5. backend dönünce sync devam eder

## Journey H — Upgrade

1. eski uygulama sürümünde veri vardır
2. yeni sürüm kurulur
3. DB migration olur
4. veri ve attachment ilişkileri korunur

Bu yolculuklardan herhangi biri release blocker ise ürün hazır değildir.

---

# 6. Test matrisi

| Alan | Unit | DB | Widget | Integration | Gerçek cihaz |
| --- | --- | --- | --- | --- | --- |
| Notes | ✓ | ✓ | ✓ | ✓ | ✓ |
| Kanban | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ranking | ✓ | ✓ | — | ✓ | — |
| Attachments | ✓ | ✓ | ✓ | ✓ | ✓ |
| Reminders | ✓ | ✓ | ✓ | ✓ | **zorunlu** |
| Search | ✓ | ✓ | ✓ | ✓ | — |
| Sync | **zorunlu** | ✓ | ✓ | **zorunlu** | ✓ |
| Conflict | **zorunlu** | ✓ | ✓ | **zorunlu** | ✓ |
| Migrations | — | **zorunlu** | — | ✓ | — |
| Responsive UI | — | — | **zorunlu** | ✓ | ✓ |

`✓` ilgili test türünün uygulanması gereken alan olduğunu ifade eder.

---

# 7. Release blocker kriterleri

Aşağıdakilerden biri varsa ürün yayınlanmaz:

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

- [ ] `SCOPE.md` ile uyumlu
- [ ] `UX_DESIGN.md` ile uyumlu
- [ ] domain sınırı doğru
- [ ] local persistence tamam
- [ ] offline davranış tamam
- [ ] hata durumları tamam
- [ ] loading/empty states tamam
- [ ] gerekiyorsa sync state tamam
- [ ] gerekiyorsa migration tamam
- [ ] uygun unit testler tamam
- [ ] uygun DB/integration testler tamam
- [ ] accessibility semantics tamam
- [ ] responsive davranış tamam
- [ ] platform farkları kontrol edildi
- [ ] debug placeholder / TODO production path'te kalmadı
- [ ] kullanıcı verisi açısından destructive edge-case incelendi

---

# 9. Definition of Done — Product

`Not` ancak aşağıdaki şartların tümü sağlandığında ürün seviyesinde kabul edilir:

- [ ] macOS, iOS ve Android release build üretilebiliyor
- [ ] Notes core tamam
- [ ] Kanban core tamam
- [ ] attachment lifecycle tamam
- [ ] reminders tamam
- [ ] local search tamam
- [ ] offline-first tüm ana akışlarda doğrulandı
- [ ] Supabase sync tamam
- [ ] conflict/recovery tamam
- [ ] migration testleri tamam
- [ ] gerçek cihaz notification testleri tamam
- [ ] security/RLS review tamam
- [ ] responsive UX tamam
- [ ] accessibility kontrolü tamam
- [ ] performans profiling tamam
- [ ] release candidate soak test tamam
- [ ] P0 açık hata sayısı = 0
- [ ] kabul edilmemiş P1 açık hata sayısı = 0
- [ ] signing/release config tamam
- [ ] kullanıcıya kurulabilir release artifact mevcut

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

Amaç Notion'un tamamını kopyalamak değil; tanımlanan kişisel çalışma akışını çok güvenilir yapmaktır.

---

# 11. Önerilen uygulama sırası — kısa görünüm

Kodlama ekibi veya coding agent uzun belge yerine sıra görmek istediğinde aşağıdaki sıra kullanılır:

```text
0. Baseline
1. Native bootstrap
2. Dependency wiring + lifecycle
3. Drift + repositories + migrations
4. Design system + responsive shell
5. Notes
6. Kanban + ranking
7. Attachments
8. Reminders
9. Search
10. Supabase + Auth + RLS
11. Sync queue + delta sync
12. Conflict + recovery
13. Platform hardening
14. Quality/performance/security/a11y
15. Beta + RC
16. Signed product release
17. Post-release maintenance
```

Bu sıra değiştirilirse bağımlılıklar yeniden değerlendirilmelidir. Özellikle sync motorunun sağlam yerel veri modeli tamamlanmadan, UI polish'in design system kurulmadan veya release paketlemenin kalite hardening tamamlanmadan öne alınması önerilmez.
