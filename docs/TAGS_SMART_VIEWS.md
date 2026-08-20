# Planora — Etiketler ve Akıllı Görünümler

> Durum: Uygulama kapsamı / teknik sözleşme  
> Branch: `feature/tags-smart-views`  
> Veri şeması: v5

## 1. Amaç

Etiketler ve Akıllı Görünümler, Planora'daki notlar ile Kanban kartlarını yeni klasör hiyerarşileri oluşturmadan düzenlemek için eklenmiştir. Sistem local-first çalışır; internet olmadan etiket oluşturma, atama/kaldırma, Akıllı Görünüm oluşturma ve filtre sonuçlarını kullanma mümkündür.

Akıllı Görünüm sonuçları ayrı veri olarak saklanmaz. Bir Akıllı Görünüm yalnızca versiyonlu bir `ContentFilter` sorgusudur; sonuçlar SQLite'tan canlı olarak hesaplanır.

## 2. Veri modeli

### `tags`

- `id`
- `name`
- `normalized_name`
- `color_key`
- `created_at`
- `updated_at`
- `version`
- `deleted_at`

Aktif etiket adları normalize edilmiş biçimde tekildir. Etiket kimliği normalize edilmiş addan deterministik olarak türetilir; bu aynı etiketin iki çevrimdışı cihazda bağımsız oluşturulması halinde mantıksal çoğalmayı azaltır.

### `tag_assignments`

- `id`
- `tag_id`
- `target_type`: `note | card`
- `target_id`
- `created_at`
- `updated_at`
- `version`
- `deleted_at`

Atama kimliği `tag + target type + target id` bileşiminden deterministik olarak türetilir. Aynı etiket aynı içeriğe birden fazla aktif kez bağlanamaz.

### `smart_views`

- `id`
- `name`
- `icon_key`
- `rank_key`
- `query_json`
- `created_at`
- `updated_at`
- `version`
- `deleted_at`

`query_json`, `ContentFilter` şemasının versiyonlu serileştirmesidir.

## 3. ContentFilter v1

Desteklenen alanlar:

- içerik kapsamı: `notes | cards | all`
- metin sorgusu
- tümü gerekli etiketler (`allTagIds`)
- herhangi biri yeterli etiketler (`anyTagIds`)
- hariç tutulan etiketler (`noneTagIds`)
- etiketli / etiketsiz durumu
- favori durumu
- hatırlatıcı var/yok
- dosya eki var/yok
- son N günde güncellenmiş olma
- pano sınırı
- kolon sınırı
- güncelleme tarihi veya başlığa göre sıralama
- artan / azalan sıralama

Filtre mümkün olduğunca SQLite seviyesinde uygulanır. Büyük içerik kümelerini Dart'a çekip tek tek filtrelemek kabul edilmez.

## 4. Hazır Akıllı Görünümler

Uygulama kayıt oluşturmadan aşağıdaki sistem görünümlerini sunar:

- Favoriler
- Etiketsiz
- Hatırlatıcılı
- Dosyalı
- Son 7 Gün

Bunlar `smart_views` tablosunda zorunlu kayıt değildir; uygulama tarafından bilinen hazır `ContentFilter` tanımlarıdır.

## 5. Etiket UX

Etiketler:

- not editöründe başlığın altında,
- not listesindeki not önizlemesinde,
- kart ayrıntısında,
- Kanban kartı üzerinde kompakt önizleme olarak

gösterilir.

Etiket seçici mobilde bottom sheet, geniş ekranlarda dialog olarak açılır. Kullanıcı mevcut etiketi seçebilir veya arama alanından yeni etiket oluşturabilir.

Etiket yönetim ekranında oluşturma, yeniden adlandırma, renk değiştirme, kullanım sayısı ve silme bulunur. Etiket silmek bağlı not veya kartı silmez; yalnız etiket ve ilişkileri tombstone olur.

## 6. Arama entegrasyonu

FTS5 metin araması korunur. Gelişmiş arama filtreleri `ContentFilter` üzerinden not/kart sonuçlarına uygulanır:

- etiketler,
- etiketli/etiketsiz,
- hatırlatıcı,
- dosya eki,
- güncellenme süresi.

Pano araması mevcut FTS akışında kalır; nota/karta ait metadata filtreleri panolara uygulanmaz.

## 7. Offline-first ve sync

Yeni sync entity türleri:

- `tag`
- `tag_assignment`
- `smart_view`

Yerel mutasyon önce SQLite transaction içinde yazılır ve sync queue'ya eklenir. Uzak veri source-of-truth değildir.

Pull uygulanırken bağımlılık sırası korunur:

1. `board`, `note`, `tag`
2. `column`
3. `card`
4. `card_note_link`, `tag_assignment`
5. bağımsız metadata entity'leri

Bu sıra özellikle `tag_assignment.tag_id -> tags.id` foreign key'i nedeniyle zorunludur.

Silme işlemleri tombstone tabanlıdır. Not veya kart kalıcı silinirken ilgili etiket atamaları da önce tombstone edilir; başka cihazda hayalet ilişki bırakılmaz.

## 8. Supabase

`supabase/migrations/0003_tags_smart_views.sql`, uzak generic entity sözleşmesine şu türleri ekler:

- `tag`
- `tag_assignment`
- `smart_view`

İstemci güvenlik katmanı da yalnız izin verilen entity türlerini kabul eder.

## 9. Feature sınırları

Cross-feature erişimler mümkün olduğunda `public/` sözleşmelerinden geçer:

- `features/tags/public/`
- `features/smart_views/public/`
- `features/kanban/public/`

Bir feature başka feature'ın `data/` implementasyonuna doğrudan bağlanmamalıdır. Uygulama shell'i üst seviye ekranlar arası navigasyonun sahibidir.

## 10. Test kapıları

Feature tamamlandıktan sonra aşağıdaki gruplar birlikte doğrulanmalıdır:

- schema v4 -> v5 migration
- tag normalize/dedup
- tag assign/unassign/restore
- tag tombstone ve lifecycle cleanup
- ALL / ANY / NOT tag filtreleri
- etiketsiz sorgu
- favori / reminder / attachment / date kombinasyonları
- saved Smart View JSON v1
- offline restart kalıcılığı
- iki cihaz aynı etiket/atama yakınsaması
- remote pull bağımlılık sırası
- arama + metadata filtre entegrasyonu
- yüksek hacimli sorgu performansı

## 11. Performans hedefi

Hedef veri kümesi:

- 10.000 içerik,
- yüzlerce etiket,
- binlerce etiket ataması.

Akıllı Görünüm sorguları uygun indeksleri kullanmalı ve bütün içerikleri Dart katmanına taşıyan full-table uygulama filtrelemesi yapmamalıdır. Kesin süre eşiği CI/gerçek cihaz profiline göre ayrıca kalibre edilir.

## 12. Kapsam dışı

Bu özellik aşağıdakileri getirmez:

- nested/hiyerarşik etiket ağacı,
- ekip etiketi / kullanıcı ataması,
- otomatik AI etiketleme,
- kural çalıştıran otomasyon motoru,
- sonuçları kopyalayan ayrı koleksiyonlar,
- Notion tipi relation/rollup veritabanı sistemi.
