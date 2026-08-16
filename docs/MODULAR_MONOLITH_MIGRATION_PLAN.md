# Modular Monolith + Feature-First Katmanlı Mimariye Geçiş Planı

## 1. Amaç

Bu belge, `not` uygulamasının mevcut **feature-first Clean Architecture** yapısını bozmadan daha güçlü modül sınırlarına sahip bir **modular monolith + feature-first katmanlı mimariye** dönüştürme planıdır.

Geçiş bir yeniden yazım değildir. Çalışan ürün davranışı, offline-first veri akışı, Drift/SQLite şeması, Supabase senkronizasyonu ve mevcut kullanıcı deneyimi korunarak mimari sınırlar kademeli biçimde sertleştirilecektir.

Temel hedef:

```text
App / Composition Root
        |
        +-------------------------------+
        |               |               |
        v               v               v
      Notes           Kanban         Reminders        ...
   +----------+     +----------+     +----------+
   | public   |     | public   |     | public   |
   | present. |     | present. |     | present. |
   | applic.  |     | applic.  |     | applic.  |
   | domain   |     | domain   |     | domain   |
   | data     |     | data     |     | data     |
   +----------+     +----------+     +----------+
        |               |               |
        +---------------+---------------+
                        |
                        v
              Shared infrastructure
        DB engine / network / logging / sync
          feature-domain bilgisi içermez
```

## 2. Mevcut durum

Mevcut repo doğru yönde kurulmuştur:

- `lib/features/<feature>/data`
- `lib/features/<feature>/domain`
- `lib/features/<feature>/presentation`
- repository interface / implementation ayrımı
- `AppBootstrap` composition root
- Riverpod üzerinden dependency wiring
- offline-first local source-of-truth
- ortak sync queue ve Supabase gateway

Ancak strict modular monolith açısından aşağıdaki sınır ihlalleri bulunmaktadır.

### 2.1. Merkezî persistence ownership

`lib/core/database/app_database.dart` bütün feature tablolarını ve bunlara ait migration/index bilgisini sahiplenmektedir.

Sonuç: Notes, Kanban, Attachments ve Reminders'ın persistence sınırları fiziksel olarak `core` altında birleşmektedir.

### 2.2. `LocalEntityStore` feature internallerini biliyor

`lib/core/sync/local_entity_store.dart` aşağıdaki entity tiplerini ve alanlarını tek tek bilmektedir:

- note
- board
- column
- card
- attachment
- reminder

Bu nedenle `core/sync`, feature'lardan bağımsız bir altyapı katmanı değildir.

### 2.3. Search diğer feature'ların internallerine giriyor

`DriftSearchRepository` doğrudan Notes/Kanban tablolarını okumakta ve Notes domain tiplerini import etmektedir.

Search bağımsız bir modül olmak yerine diğer modüllerin persistence/domain ayrıntılarına bağlıdır.

### 2.4. Kanban başka feature repository'lerini orkestre ediyor

`LifecycleKanbanRepository` doğrudan `AttachmentsRepository` ve `RemindersRepository` kullanmaktadır.

Bir kart/pano silme use-case'inin birden fazla modülü etkilemesi doğaldır; ancak bu orchestration Kanban'ın data katmanında olmamalıdır.

### 2.5. Presentation-to-presentation bağımlılık

Notes editörü Reminders presentation widget'larını doğrudan kullanmaktadır.

Bu yaklaşım feature izolasyonunu zayıflatır ve UI parçalarının sahipliğini belirsizleştirir.

### 2.6. Mimari sınırlar otomatik doğrulanmıyor

Mevcut lint kuralları Dart kod kalitesini koruyor fakat aşağıdaki bağımlılık kuralları CI tarafından uygulanmıyor:

- `core -> features` yasak
- `domain -> data/presentation` yasak
- `feature A -> feature B/data` yasak
- `feature A -> feature B/presentation` yasak
- başka bir feature'ın private/internal tiplerini import etmek yasak

---

## 3. Hedef mimari kuralları

### 3.1. Modül sınırı

Her işlevsel feature bağımsız bir modüldür:

- `notes`
- `kanban`
- `attachments`
- `reminders`
- `search`
- `conflicts`
- gerektiğinde ileride eklenecek yeni feature'lar

`home` ve `settings` için ürün davranışına göre aynı kurallar uygulanır; yalnızca basit UI-only feature'larda gereksiz katman oluşturulmaz.

### 3.2. Feature dizin standardı

Hedef yapı:

```text
lib/features/<feature>/
├── public/
│   ├── <feature>_facade.dart
│   ├── <feature>_events.dart
│   └── <feature>_models.dart       # yalnız gerekiyorsa
├── presentation/
│   ├── screens/
│   ├── widgets/
│   └── controllers/
├── application/
│   ├── usecases/
│   ├── services/
│   └── ports/
├── domain/
│   ├── entities/
│   ├── value_objects/
│   ├── repositories/
│   └── policies/
└── data/
    ├── local/
    │   ├── tables/
    │   ├── dao/
    │   └── mappers/
    ├── remote/
    └── repositories/
```

Bütün klasörlerin her feature'da zorunlu olması gerekmez. Kullanılmayan katman/klasör oluşturulmaz.

### 3.3. Katman bağımlılık yönü

İzin verilen temel yön:

```text
presentation
     |
     v
application
     |
     v
domain

 data --------> domain
```

Kurallar:

1. `domain` Flutter, Drift, Supabase, Riverpod veya platform API'si bilmez.
2. `application` UI widget'ı bilmez.
3. `presentation` doğrudan Drift/Supabase kullanmaz.
4. `data`, domain repository portlarını implement eder.
5. Cross-feature kullanım yalnız hedef modülün `public/` sözleşmesi veya uygulama seviyesindeki orchestration üzerinden yapılır.
6. Bir feature başka feature'ın `data/`, `presentation/` veya internal domain implementation dosyalarını import edemez.

### 3.4. Shared core sınırı

`core` yalnız gerçekten feature-agnostic parçaları içerebilir:

```text
core/
├── error/
├── logging/
├── network/
├── utils/
└── contracts/       # gerçekten ortak primitive sözleşmeler
```

`core` herhangi bir feature import edemez.

Feature bilgisi taşıyan kod `core` altında tutulmaz.

### 3.5. Composition root

Concrete implementation wiring yalnız `app/` altında yapılır.

`AppBootstrap` aşağıdakileri yapabilir:

- database assembly
- module facade/repository oluşturma
- adapter registration
- sync registration
- event handler wiring
- lifecycle başlatma/durdurma

Feature'lar `AppBootstrap`'ı bilmez.

---

## 4. Modül sahipliği matrisi

| Kaynak / davranış | Sahip modül |
| --- | --- |
| Note entity, document, note table, note repository | Notes |
| Board, column, card, rank policy ve tabloları | Kanban |
| Attachment metadata/table/file lifecycle | Attachments |
| Reminder entity/table/scheduling use-case | Reminders |
| Search index/query contract | Search |
| Conflict entity/resolution contract | Conflicts |
| Sync queue, retry/backoff primitive | Shared sync infrastructure |
| Entity'nin sync payload üretimi/uygulanması | İlgili feature adapter'ı |
| Supabase transport | Shared remote infrastructure |
| SQLite connection/lifecycle | Shared DB infrastructure |
| Cross-feature workflow | App/Application orchestration |

Önemli ayrım: **ortak veritabanı kullanılmaya devam eder; ancak tablo ve entity davranışının sahibi ilgili modüldür.** Modular monolith ayrı veritabanı gerektirmez.

---

# 5. Geçiş fazları

## Faz 0 — Baseline ve mimari koruma noktası

### Amaç

Refactor başlamadan önce mevcut davranışın referans durumunu sabitlemek.

### İşler

- Mevcut feature/import haritasını çıkart.
- Cross-feature import listesini kaydet.
- Mevcut repository sözleşmelerini listele.
- Mevcut Drift schema version ve migration davranışını baseline olarak kaydet.
- Offline flow, sync, delete lifecycle, search rebuild ve reminder reconcile davranışlarını regression kapsamına al.
- Mimari migration boyunca ürün davranışı değişikliği yapılmayacağını açık kural haline getir.

### Çıkış kriteri

- Davranış baseline'ı kayıtlı.
- Refactor öncesi mevcut test durumu biliniyor.
- Her sonraki fazda hangi regresyonların kontrol edileceği belli.

---

## Faz 1 — Architecture boundary sözleşmelerini kur

### Amaç

Kod taşımadan önce hedef bağımlılık kurallarını tanımlamak.

### İşler

- Her feature için dışarı açılması gereken minimum API'yi belirle.
- Gereken feature'larda `public/` katmanı oluştur.
- Cross-feature çağrılar için facade/port modellerini tanımla.
- `application/` katmanını yalnız gerçek use-case/orchestration ihtiyacı olan feature'lara ekle.
- Domain repository interface'lerini koru; UI'ın concrete implementation görmesini engelle.

Örnek:

```text
features/attachments/public/attachments_facade.dart
features/reminders/public/reminders_facade.dart
features/kanban/public/kanban_facade.dart
features/notes/public/notes_facade.dart
```

### Kural

Bu fazda mümkün olduğunca davranış değiştirilmez; yalnız yeni sınırlar oluşturulur ve mevcut çağrılar kademeli olarak yeni API'lere yönlendirilir.

### Çıkış kriteri

- Başka bir feature'ı kullanmak için resmi public contract mevcut.
- Yeni cross-feature kod private/internal dosyalara bağlanmıyor.

---

## Faz 2 — Persistence ownership'i feature'lara taşı

### Amaç

Tablo tanımlarının sahipliğini ilgili feature'a vermek.

### Taşınacak başlıca dosyalar

```text
core/database/tables/notes_table.dart
    -> features/notes/data/local/tables/notes_table.dart

core/database/tables/boards_table.dart
core/database/tables/board_columns_table.dart
core/database/tables/cards_table.dart
    -> features/kanban/data/local/tables/

core/database/tables/attachments_table.dart
    -> features/attachments/data/local/tables/

core/database/tables/reminders_table.dart
    -> features/reminders/data/local/tables/

core/database/tables/conflicts_table.dart
    -> features/conflicts/data/local/tables/
```

Sync infrastructure tabloları shared infrastructure'da kalabilir:

- `sync_queue`
- `sync_meta`

App settings ürün modeline göre Settings modülüne veya shared app infrastructure'a taşınır.

### Veritabanı assembly

Tek bir `AppDatabase` kalabilir. Ancak rolü yalnız database assembly/migration lifecycle olmalıdır.

Önerilen konum:

```text
lib/app/infrastructure/database/app_database.dart
```

veya eşdeğer, açıkça composition/infrastructure rolünü gösteren bir konum.

`AppDatabase` feature tablolarını register edebilir; fakat feature business logic'i içermez.

### Kritik kural

Bu refactor sırasında SQL tablo adları değiştirilmez. Yalnız Dart source ownership taşınır. Gereksiz schema migration oluşturulmaz.

### Çıkış kriteri

- Feature tabloları ilgili feature altında.
- `core/database/tables` altında feature-owned tablo kalmamış.
- Mevcut SQLite verileri kaybolmadan uygulama açılabiliyor.
- Migration testleri geçiyor.

---

## Faz 3 — `LocalEntityStore` monolitini adapter registry'ye dönüştür

### Amaç

`core/sync` katmanından feature bilgisini tamamen çıkarmak.

### Yeni sözleşme

Örnek:

```dart
abstract interface class SyncEntityAdapter {
  String get entityType;

  Future<int> localVersion(String entityId);
  Future<Map<String, Object?>?> payloadFor(String entityId);
  Future<void> applyRemote(RemoteEntity entity);
}
```

Her feature kendi adapter'ını sağlar:

```text
features/notes/data/sync/note_sync_adapter.dart
features/kanban/data/sync/board_sync_adapter.dart
features/kanban/data/sync/column_sync_adapter.dart
features/kanban/data/sync/card_sync_adapter.dart
features/attachments/data/sync/attachment_sync_adapter.dart
features/reminders/data/sync/reminder_sync_adapter.dart
```

Shared sync katmanı yalnız registry bilir:

```text
SyncEngine
   -> SyncAdapterRegistry
        -> SyncEntityAdapter
```

### AppBootstrap görevi

Adapter'lar `AppBootstrap` içinde register edilir.

### Sonuç

Yeni bir feature senkronize edilebilir olduğunda `SyncEngine` veya merkezi `switch(entityType)` değiştirilmez.

### Çıkış kriteri

- `core/sync` altında `note`, `card`, `board`, `reminder`, `attachment` alan bilgisi yok.
- Merkezi entity switch kaldırılmış.
- Her sync edilebilir feature kendi serialization/apply davranışına sahip.
- Push/pull/conflict regression testleri geçiyor.

---

## Faz 4 — Search modülünü diğer feature internallerinden ayır

### Amaç

Search'ün Notes/Kanban persistence ayrıntılarını bilmesini engellemek.

### Hedef model

Her aranabilir modül Search'e bir public search document contract sağlar.

Örnek:

```dart
final class SearchDocument {
  const SearchDocument({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
  });
}

abstract interface class SearchDocumentSource {
  Stream<SearchDocumentChange> watchChanges();
  Future<List<SearchDocument>> snapshot();
}
```

Alternatif olarak uygulamanın ölçeğine uygun basit event tabanlı model kullanılabilir:

```text
NoteChanged  -> SearchIndexer
CardChanged  -> SearchIndexer
BoardChanged -> SearchIndexer
```

### Yapılacaklar

- Search repository'den `NoteDocument` internal importunu kaldır.
- Search repository'nin `_database.notes/cards/boards` doğrudan erişimini kaldır.
- Rebuild işlemini registered `SearchDocumentSource` kaynaklarından besle.
- FTS tablosunun sahipliğini Search modülüne ver.

### Çıkış kriteri

- Search modülü Notes/Kanban `data/` veya internal domain dosyalarını import etmiyor.
- Yeni aranabilir feature eklemek Search core implementation'ını değiştirmeyi gerektirmiyor.
- Search sonuçları davranış olarak mevcut sürümle eşdeğer.

---

## Faz 5 — Cross-feature lifecycle orchestration'ı data katmanından çıkar

### Amaç

Kanban'ın Attachments ve Reminders internallerini yönetmesini engellemek.

### Mevcut problem

`LifecycleKanbanRepository` kart/pano silme sırasında Attachments ve Reminders repository'lerini doğrudan çağırıyor.

### Hedef

Cross-module workflow uygulama seviyesinde yönetilir.

Tercih sırası:

1. Basit ve açık workflow için application orchestration.
2. Bağımlılığı daha da gevşetmek gerekiyorsa domain/application event.

Örnek application service:

```text
app/application/delete_card_workflow.dart

DeleteCardWorkflow
  -> KanbanFacade
  -> AttachmentsFacade
  -> RemindersFacade
```

veya event modeli:

```text
Kanban: CardDeleted
        |
        +-> Attachments cleanup handler
        +-> Reminders cleanup handler
```

### Transaction notu

Birden fazla local tabloyu atomik biçimde değiştirmesi gereken workflow'larda transaction boundary bilinçli tasarlanmalıdır. Eventual consistency varsayılan olarak kabul edilmemelidir.

### Çıkış kriteri

- Kanban `data/` katmanı Attachments/Reminders import etmiyor.
- Kart/pano silme lifecycle davranışı korunuyor.
- Child cleanup için regression testleri mevcut.

---

## Faz 6 — Presentation izolasyonu

### Amaç

Bir feature'ın presentation katmanının başka bir feature'ın presentation implementation'ına bağlanmasını engellemek.

### Mevcut örnek

Notes editörü Reminders presentation widget'larını doğrudan kullanıyor.

### Hedef seçenek

App-level composition:

```text
NoteEditorScreen
   -> NoteEditorBody

App composition
   -> NoteEditorBody
   -> AttachmentSection
   -> ReminderSection
```

veya public feature widget API:

```text
features/reminders/public/reminder_section.dart
```

Public widget yalnız kontrollü bir feature API'sidir; internal `presentation/widgets/...` dışarı açılmaz.

### Çıkış kriteri

- `features/<A>/presentation` altında `features/<B>/presentation` internal importu yok.
- Notes editörü attachment/reminder davranışını kaybetmiyor.

---

## Faz 7 — Composition root ve provider wiring temizliği

### Amaç

Concrete dependency oluşturmayı tek noktada toplamak ve feature'ların birbirini dependency container üzerinden dolaylı biçimde de olsa sınırsız görmesini engellemek.

### İşler

- `AppBootstrap` composition root olarak korunur.
- `AppServices` mümkün olduğunca modül facade'larını expose eder.
- UI'ın ihtiyaç duymadığı low-level servisler global provider olarak açılmaz.
- `app/providers.dart` public module contract seviyesinde sadeleştirilir.
- Concrete Drift repository, RemoteGateway, Sync adapter vb. yalnız bootstrap/infrastructure tarafında görünür.

### Hedef

Presentation şu tip dependency görür:

```text
NotesFacade
KanbanFacade
ReminderFacade
SearchFacade
```

Şunları doğrudan görmez:

```text
AppDatabase
DriftNotesRepository
SyncQueueRepository
RemoteGateway
```

### Çıkış kriteri

- Provider graph business-module sınırlarını yansıtıyor.
- Concrete data implementation UI'a sızmıyor.

---

## Faz 8 — Architecture tests ve CI enforcement

### Amaç

Mimarinin yalnız belgeye bağlı kalmamasını sağlamak.

### Minimum otomatik kurallar

CI aşağıdaki ihlallerde fail etmelidir:

```text
core/**
  x features/** import edemez

features/*/domain/**
  x Flutter
  x Riverpod
  x Drift
  x Supabase
  x aynı feature'ın data/**
  x presentation/**

features/<A>/**
  x features/<B>/data/**
  x features/<B>/presentation/**
  x features/<B>/domain/internal/**

presentation/**
  x AppDatabase
  x Drift concrete repository
  x SupabaseClient
```

Cross-feature import yalnız şuralara izinli olmalıdır:

```text
features/<B>/public/**
```

veya açıkça tanımlanmış shared contract'lara.

### Uygulama seçenekleri

Öncelik sırası:

1. Dart tabanlı custom architecture test.
2. CI'da import graph kontrol script'i.
3. Uygun ve sürdürülebilir bir lint çözümü varsa ek statik kural.

Architecture testleri repository'nin kendi kodu olmalı; geliştiricinin yerel araca sahip olmasına bağımlı olmamalıdır.

### CI kalite kapısı

En az:

```text
dart format --set-exit-if-changed .
flutter analyze
flutter test
architecture boundary tests
```

Platform build/test workflow'ları mevcut CI stratejisine göre korunur.

### Çıkış kriteri

- Yasak bağımlılık eklendiğinde CI gerçekten fail oluyor.
- Mimari regresyon insan review'una bağlı değil.

---

## Faz 9 — Eski compatibility katmanlarını kaldır ve dokümantasyonu güncelle

### Amaç

Geçiş sırasında kullanılan geçici wrapper/deprecated API'leri temizlemek.

### İşler

- `LifecycleKanbanRepository` kaldır.
- Eski `LocalEntityStore` kaldır.
- Eski cross-feature imports kaldır.
- Kullanılmayan provider/repository wrapper'larını kaldır.
- README mimari diyagramını hedef yapıya göre güncelle.
- `PRODUCT_ROADMAP.md` içinde mimari refactor tamamlanma kaydı ekle.
- Yeni feature geliştirme kurallarını repository contribution standardına ekle.

### Çıkış kriteri

- Compatibility bridge kalmamış.
- Dokümantasyon kodla aynı mimariyi tarif ediyor.
- Architecture testleri temiz.

---

# 6. Faz bağımlılıkları

```text
0 Baseline
   |
   v
1 Public contracts
   |
   +--------------------+
   |                    |
   v                    v
2 Persistence        6 Presentation
   |
   v
3 Sync adapters
   |
   +----------+
   |          |
   v          v
4 Search    5 Orchestration
   \          /
    \        /
     v      v
   7 Composition root
          |
          v
   8 Architecture CI
          |
          v
   9 Cleanup/docs
```

Faz 2-6 uygun alt parçalarda paralel ilerleyebilir; ancak Faz 1 public contract modeli belirlenmeden feature-to-feature refactor yapılmamalıdır.

---

# 7. Önerilen uygulama sırası

Risk azaltmak için feature bazında küçük dikey dilimler tercih edilir.

1. Architecture test altyapısının ilk sürümünü ekle ancak yalnız mevcut yeni kuralları ihlal etmeyen alanlarda enforce et.
2. Notes persistence ownership.
3. Kanban persistence ownership.
4. Attachments persistence ownership.
5. Reminders persistence ownership.
6. Conflicts persistence ownership.
7. Sync adapter registry.
8. Search decoupling.
9. Card/board lifecycle orchestration.
10. Presentation boundary cleanup.
11. Provider/composition cleanup.
12. Bütün architecture kurallarını strict hale getir.
13. Compatibility kodunu sil.

Her adım sonunda çalışan uygulama bırakılmalıdır. Büyük bang migration yapılmaz.

---

# 8. Test stratejisi

## 8.1. Her fazda korunacak davranışlar

- uygulama mevcut DB ile açılabilmeli
- Notes CRUD
- Kanban CRUD ve reorder/move
- attachment add/remove
- reminder scheduling/reconcile
- local search/rebuild
- offline write
- sync queue enqueue
- push/pull
- conflict record/resolve
- delete/tombstone lifecycle

## 8.2. Persistence taşıma testleri

- SQL tablo isimleri değişmemeli
- schema version gereksiz artırılmamalı
- mevcut migration fixture'ları açılabilmeli
- foreign key/index davranışı korunmalı

## 8.3. Sync adapter contract testleri

Her adapter için:

- payload serialization
- localVersion
- remote apply
- tombstone
- malformed payload handling

## 8.4. Architecture tests

En az şu negatif fixture senaryoları test edilmelidir:

- core -> feature import
- domain -> Drift import
- Notes -> Reminders internal presentation import
- Search -> Notes data import

Test, ihlali tespit etmediğinde başarısız sayılmalıdır.

---

# 9. Definition of Done

Geçiş aşağıdaki maddelerin tamamı sağlanmadan bitmiş kabul edilmez:

- [ ] Her business feature açık bir modül sahibine sahip.
- [ ] Feature persistence tabloları ilgili feature altında.
- [ ] `core` hiçbir feature import etmiyor.
- [ ] `core/sync` hiçbir feature entity alanını bilmiyor.
- [ ] Merkezi `entityType switch` yerine adapter registry kullanılıyor.
- [ ] Search başka feature'ın database/domain internal implementation'ına erişmiyor.
- [ ] Kanban data katmanı Attachments/Reminders repository'lerini import etmiyor.
- [ ] Feature presentation katmanları birbirlerinin internal presentation dosyalarını import etmiyor.
- [ ] Cross-feature erişim yalnız public contract veya app-level orchestration üzerinden.
- [ ] UI concrete Drift/Supabase implementation görmüyor.
- [ ] Offline-first davranış değişmemiş.
- [ ] Mevcut SQLite verileri migration sonrasında korunuyor.
- [ ] Sync/conflict davranışı regression testleriyle korunuyor.
- [ ] Architecture boundary testleri CI'da zorunlu.
- [ ] README ve roadmap yeni mimariyle uyumlu.

---

# 10. Geçiş sırasında yapılmayacaklar

Bu çalışma mimari refactor'dur. Aşağıdakiler aynı değişiklik setlerine karıştırılmamalıdır:

- yeni büyük ürün feature'ları
- UX redesign
- veritabanı tablo isimlerinin keyfi değiştirilmesi
- Supabase protocol redesign
- state-management framework değişimi
- Drift'in başka persistence teknolojisiyle değiştirilmesi
- Riverpod'un değiştirilmesi
- bütün feature'ları ayrı Dart/Flutter package'a bölme

Son madde özellikle bilinçlidir: strict module boundary için ilk aşamada package-per-feature gerekli değildir. Tek Flutter package içinde architecture testleri ve açık public contracts ile modular monolith kurulacaktır. İleride compile-time isolation ihtiyacı belirginleşirse ayrı package'lara bölme ayrıca değerlendirilebilir.

---

# 11. Riskler ve azaltma stratejisi

| Risk | Azaltma |
| --- | --- |
| Source taşıma sırasında Drift generated code kırılması | Feature bazında taşı, build_runner çıktısını kontrollü yenile |
| DB migration yanlışlıkla tetiklenmesi | SQL adlarını koru, schema version'ı yalnız gerçek şema değişikliğinde artır |
| Sync serialization regresyonu | Adapter contract testleri + mevcut push/pull fixtures |
| Cross-feature lifecycle kaybı | Application workflow testleri |
| Architecture over-engineering | Kullanılmayan katman/abstraction oluşturma |
| Çok büyük PR/commit | Dikey, davranış koruyan küçük fazlar |
| Geçici compatibility kodunun kalıcılaşması | Faz 9 cleanup blocker |

---

# 12. Nihai hedef

Geçiş sonunda aşağıdaki cümle teknik olarak doğru olmalıdır:

> `not`, tek deploy edilen Flutter uygulaması ve tek local database kullanan; Notes, Kanban, Attachments, Reminders, Search ve Conflicts modüllerinin veri ve davranış sahipliğini koruduğu; modüller arası erişimin açık public sözleşmelerle sınırlandığı; shared core'un feature bilgisi taşımadığı ve bu kuralların CI tarafından otomatik doğrulandığı bir modular monolith'tir.
