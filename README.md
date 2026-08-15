# Not

Not, Notion benzeri kişisel not alma ve Kanban çalışma alanı için tasarlanan **tek kullanıcılı, offline-first Flutter uygulamasıdır**. Yerel veri tabanı uygulamanın birincil çalışma kaynağıdır; ağ bağlantısı olmadan notlar, kartlar, ekler ve hatırlatıcılar kullanılabilir. Bulut senkronizasyonu yerel deneyimi bloklamayan ikincil bir katmandır.

> Durum: Mimari iskelet. Bu repo ürün kodunun geliştirilmesi için başlangıç yapısını, sınırları ve teknik kararları içerir.

## Tasarım ve UX

Uygulamanın ekran, navigasyon, buton, form, Kanban, not editörü, hatırlatıcı, dosya/ek, arama, ayarlar, offline/sync durumları, responsive davranış, dark/light theme ve erişilebilirlik spesifikasyonu:

**[docs/UX_DESIGN.md](docs/UX_DESIGN.md)**

Bu belge UI geliştirmede bağlayıcı tasarım referansıdır. Yeni ekranlar ve ortak componentler burada tanımlanan design token, responsive ve etkileşim kurallarına uymalıdır.

## Scope ve ürün sınırları

Uygulamanın hangi özellikleri kapsadığı, hangi ürün yönlerinin özellikle kapsam dışında tutulduğu, tek kullanıcı sınırı, platform kapsamı, offline/sync davranışı, MVP sınırları ve scope değişiklik prosedürü:

**[docs/SCOPE.md](docs/SCOPE.md)**

Bu belge ürün geliştirmede bağlayıcı kapsam referansıdır. Yeni bir özellik mevcut scope içinde açıkça yer almıyorsa implementation'a alınmadan önce kapsam etkisi değerlendirilmelidir.

## Ürün kapsamı

- Notlar ve zengin içerik için ölçeklenebilir feature alanı
- Kanban panoları, kolonlar ve sürükle-bırak kart sıralaması
- Offline-first optimistic UI
- Fractional indexing ile düşük çakışmalı kart sıralaması
- Yerel SQLite/Drift veri kaynağı
- Kalıcı yerel ek dosya deposu; veritabanında yalnız URI + metadata
- Android/iOS/macOS yerel zamanlanmış bildirim altyapısı
- Dayanıklı sync queue ile Supabase/PostgreSQL + Storage senkronizasyonu
- Bağlantı geri geldiğinde retry/backoff tabanlı eşitleme
- Tek kullanıcı modeli: collaboration, workspace üyeliği ve rol/yetki sistemi yok

## Tek kullanıcı kararı

Bu uygulama tek kişi tarafından kullanılacaktır. Bu nedenle mimaride bilinçli olarak şunlar **yoktur**:

- takım/workspace üyeliği,
- paylaşım ve canlı ortak düzenleme,
- RBAC/rol matrisi,
- kullanıcılar arası conflict-resolution protokolü,
- davet ve organizasyon yönetimi.

Bulut senkronizasyonu açıldığında Supabase Auth yalnızca uzak veriyi güvenli biçimde tek hesaba bağlamak için güvenlik sınırı olarak kullanılabilir. İstemciye `service_role` anahtarı gömülmez.

## Mimari

**Feature-First Clean Architecture** kullanılır.

Her feature kendi `presentation`, `domain` ve `data` katmanlarına ayrılır. Domain katmanı Flutter widget'larından, Drift'ten, Supabase'ten ve platform bildirim API'lerinden bağımsız tutulur.

```text
UI / Riverpod Controller
        |
        v
Domain Use Case
        |
        v
Repository Interface
        |
        +--------------------+
        |                    |
        v                    v
Drift Local Data         Remote Data Source
(Source of Truth)        (Supabase)
        |
        v
Sync Queue -> Sync Coordinator -> retry/backoff/conflict policy
```

### Offline-first temel kuralı

1. Kullanıcı işlemi UI'da optimistic olarak uygulanır.
2. İşlem önce yerel veritabanına transaction ile yazılır.
3. Aynı transaction içinde gerekli sync operation kuyruğa eklenir.
4. UI, Drift stream'lerinden yerel source-of-truth veriyi izler.
5. Ağ varsa Sync Coordinator kuyruğu uzak sunucuya aktarır.
6. Ağ yoksa kullanıcı akışı etkilenmez; işlem kuyrukta kalır.
7. Başarılı uzak yazımdan sonra sync kaydı tamamlanır.

## Kritik teknik kararlar

### 1. Kart sıralaması

Kartlar `1, 2, 3...` biçiminde topluca yeniden indekslenmez. Kolon içi ve kolonlar arası taşımalarda **fractional indexing / LexoRank benzeri sıralama anahtarı** kullanılır.

Her kart için sıralama değeri yalnız taşınan kayıtta değiştirilir. Uzun süreli kullanımda anahtar yoğunluğu kritik eşiğe ulaşırsa kontrollü ve seyrek bir rebalance işlemi yapılabilir.

### 2. Dosya ve ekler

Dosya byte'ları SQLite BLOB alanında tutulmaz.

```text
app_storage/
└── attachments/
    └── <uuid>/
        └── original.ext
```

Drift yalnızca `localPath`, `remotePath`, `mimeType`, `sizeBytes`, checksum ve sync metadata saklar. Kopyalama/hash alma gibi pahalı I/O işlemleri UI akışından ayrılır.

### 3. Hatırlatıcılar

Hatırlatıcı kayıtları önce Drift'e yazılır, sonra `NotificationService` üzerinden işletim sistemine planlanır. Zaman bilgisi timezone-aware saklanır. Uygulama açılışında ve gerekli yaşam döngüsü olaylarında DB ile OS tarafındaki planlar uzlaştırılır.

Android exact alarm izin/kısıtları ve iOS/macOS notification izinleri platform katmanında ele alınır. Domain katmanı platform API'si bilmez.

### 4. Senkronizasyon

Senkronizasyon için yalnız `connectivity_plus` sonucuna güvenilmez; bağlantı türü internet erişimi garantisi değildir. Ağ durumu tetikleyici olarak kullanılır, gerçek uzak istek sonucu doğruluk kaynağıdır.

Önerilen sync operation alanları:

- `operationId`
- `entityType`
- `entityId`
- `operationType`
- `payloadJson`
- `baseVersion`
- `createdAt`
- `attemptCount`
- `nextAttemptAt`
- `status`

Tek kullanıcı modelinde başlangıç conflict politikası: **version + updatedAt kontrollü last-write-wins**, kritik alanlarda server version kontrolü. Kart ranking değerleri bağımsız alan olarak ele alınır. İleride ihtiyaç oluşursa entity bazlı merge stratejileri eklenebilir.

## Teknoloji yığını

| Alan | Teknoloji |
| --- | --- |
| İstemci | Flutter |
| State | Riverpod |
| Yerel DB | Drift + sqlite3 |
| Dosyalar | file_picker + path_provider + uuid + path |
| Bildirim | flutter_local_notifications + timezone |
| Bulut | Supabase PostgreSQL + Storage |
| Ağ | dio + connectivity_plus |
| Sıralama | Fractional indexing helper |

`sqlite3_flutter_libs` kullanılmaz; Drift'in modern `sqlite3` 3.x hattı esas alınır.

## Dizin yapısı

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/app_router.dart
│   └── theme/app_theme.dart
├── core/
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── connection/native.dart
│   │   └── tables/
│   │       ├── attachments_table.dart
│   │       ├── board_columns_table.dart
│   │       ├── boards_table.dart
│   │       ├── cards_table.dart
│   │       ├── notes_table.dart
│   │       ├── reminders_table.dart
│   │       └── sync_queue_table.dart
│   ├── error/
│   ├── network/
│   ├── services/
│   ├── sync/
│   └── utils/
└── features/
    ├── kanban/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── notes/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── attachments/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── reminders/
        ├── data/
        ├── domain/
        └── presentation/
```

## Veri modeli ilkeleri

Tüm sync edilebilir entity'lerde en azından aşağıdaki metadata düşünülür:

- UUID primary key
- `createdAt`
- `updatedAt`
- `version`
- `deletedAt` veya tombstone işareti
- gerekiyorsa `syncState`

Silme işlemleri uzak cihaz/sunucu eşitlemesi tamamlanmadan fiziksel `DELETE` yapmak yerine tombstone ile temsil edilebilir.

## Başlangıç veri akışı örneği

Kullanıcının karta dosya ekleyip hatırlatıcı tanımlaması ve kartı başka kolona taşıması:

```text
Widget
  -> Controller (optimistic state)
  -> Domain use case
      -> FileStorageService
      -> NotificationService
      -> Repository
          -> Drift transaction
          -> SyncQueue insert
  -> Drift stream UI'ı doğrular
  -> SyncCoordinator uygun olduğunda Supabase'e yollar
```

## Geliştirme kurulumu

Repo iskeleti Flutter kaynak yapısını içerir. Native platform klasörleri Flutter SDK ile üretilmelidir:

```bash
flutter create . --platforms=android,ios,macos --project-name not_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

> `flutter create .` çalıştırılırken mevcut `lib/`, `README.md`, `.gitignore`, `pubspec.yaml` ve mimari dosyaların üzerine yazılmamasına dikkat edilmelidir. Gerekirse native platform klasörleri ayrı geçici projede üretilip taşınmalıdır.

Çalıştırma:

```bash
flutter run -d macos
# veya bağlı cihaz/emülatör
flutter devices
flutter run -d <device-id>
```

## Ortam değişkenleri

Supabase yapılandırması kaynak koda commit edilmez. Örnek çalışma:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your_publishable_key
```

Gerçek secret/service-role anahtarları istemci uygulamasına konmaz.

## Kalite sınırları

- Widget -> doğrudan FilePicker/notification/DB çağrısı yok.
- Dosya BLOB'u SQLite'a yazılmaz.
- Her kart hareketinde O(N) re-index yok.
- Remote API, UI'ın source-of-truth'u değildir.
- Ağ isteği başarısız olduğunda yerel kullanıcı işlemi geri alınmaz; sync state hata olarak işaretlenir ve retry uygulanır.
- Veritabanı şema değişiklikleri migration ile yapılır.
- Domain testleri platform bağımlılığı olmadan çalışabilmelidir.
- Repository ve platform servisleri interface üzerinden mock/fake edilebilir olmalıdır.

## İlk geliştirme fazları

1. Flutter native platform bootstrap + temel app shell
2. Drift şeması, migration altyapısı ve repository sözleşmeleri
3. Kanban CRUD + fractional ranking + optimistic UI
4. Notes domain ve editör altyapısı
5. Attachment sandbox + async file I/O + cache politikası
6. Reminder scheduler + timezone + permission/reconciliation
7. Sync queue + Supabase delta sync + retry/backoff
8. Conflict testleri, offline/online geçiş testleri ve migration testleri
9. Performans, büyük dosya ve uzun Kanban kolonları için profiling
10. Release hardening ve platform paketleme

## Lisans

Bu repo şu anda özel kullanım içindir. Açık kaynak lisansı tanımlanmamıştır.
