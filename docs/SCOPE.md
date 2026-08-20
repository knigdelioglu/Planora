# Planora — Ürün Kapsamı ve Sınırlar

> Durum: Ürün geliştirme için bağlayıcı scope belgesi  
> Kapsam: iOS, Android ve macOS Flutter istemcisi  
> Ürün modeli: Tek kullanıcı, offline-first, kişisel not + Kanban çalışma alanı

Bu belge `Planora` uygulamasının ürün sınırlarını tanımlar. Yeni bir özellik bu belgede açıkça kapsam içinde değilse varsayılan olarak kapsam dışıdır ve implementation'dan önce scope güncellenmelidir.

---

## 1. Ürün tanımı

`Planora`, tek bir kişinin kendi cihazlarında kullandığı, Notion benzeri fakat daha dar ve odaklı kişisel çalışma alanıdır.

Temel ihtiyaçlar:

1. Not oluşturma ve düzenleme.
2. Notları ve işleri Kanban panolarında yönetme.
3. PDF, görsel ve belge gibi dosyaları nota/karta ekleme.
4. Yerel hatırlatıcı kurma.
5. Not ve kartları etiketler ve Akıllı Görünümler ile düzenleme.
6. Verileri kullanıcının cihazları arasında güvenli biçimde senkronize etme.

Uygulamanın temel çalışma ilkesi **offline-first**'tür. Yerel veri tabanı istemci için birincil veri kaynağıdır.

---

## 2. Ana ürün hedefi

Kullanıcı internet durumunu düşünmeden:

- hızlı not oluşturabilmeli,
- mevcut notu düzenleyebilmeli,
- Kanban kartı oluşturup taşıyabilmeli,
- dosya ekleyebilmeli,
- hatırlatıcı tanımlayabilmeli,
- not ve kartlara etiket bağlayabilmeli,
- kayıtlı Akıllı Görünümler ile içeriğini filtreleyebilmeli,
- yerel arama ve metadata filtrelerini kullanabilmeli.

Bağlantı geldiğinde değişiklikler kullanıcı müdahalesi gerektirmeden senkronize edilmelidir.

---

## 3. Ürün modeli: kesinlikle tek kullanıcı

Tek kullanıcı kararı geçici MVP sadeleştirmesi değildir.

### Kapsam içinde

- Aynı kişinin birden fazla cihaz kullanması.
- Tek kişisel bulut hesabı ile cihazlar arası senkronizasyon.
- iPhone, Android telefon/tablet ve Mac arasında veri devamlılığı.

### Kapsam dışında

- ekipler ve organizasyonlar,
- workspace üyeleri,
- davet sistemi,
- RBAC / rol / izin matrisi,
- assignee,
- çok kullanıcılı gerçek zamanlı düzenleme,
- kullanıcılar arası paylaşım izinleri.

Bulut kimliği yalnız kullanıcının kendi uzak verisini korumak ve cihazlar arası eşitlemek için kullanılır.

---

## 4. Desteklenen platformlar

### Birincil platformlar

- macOS
- iOS
- Android

Aynı Flutter codebase kullanılır; platforma özgü davranış gerektiğinde native yeteneklerden yararlanılabilir.

### Kapsam dışında

- Windows
- Linux masaüstü
- Web
- browser extension
- watchOS / Wear OS / visionOS

---

## 5. Temel fonksiyonel kapsam

### 5.1 Notlar

Kullanıcı:

- yeni not oluşturabilir,
- başlık ve içerik düzenleyebilir,
- favorileyebilir,
- silebilir ve çöp kutusundan geri alabilir,
- yakın zamanda kullanılan notları görebilir,
- zengin içerik blokları kullanabilir,
- dosya/ek iliştirebilir,
- hatırlatıcı bağlayabilir,
- bir veya daha fazla etiket bağlayabilir,
- etiketleri doğrudan editör ve liste görünümünden yönetebilir,
- notları arayabilir.

### Desteklenen bloklar

- paragraf,
- başlık seviyeleri,
- madde işaretli liste,
- numaralı liste,
- checkbox,
- alıntı,
- ayraç,
- basit kod bloğu,
- bağlantı,
- görsel,
- dosya eki.

### Kapsam dışında

- tam Notion blok ekosistemi,
- tablo/calendar/gallery database sistemi,
- formula / relation / rollup,
- spreadsheet motoru,
- collaborative cursor,
- public web publishing.

---

## 6. Kanban kapsamı

Kullanıcı:

- pano/kolon/kart CRUD işlemlerini yapabilir,
- kolonları ve kartları sıralayabilir,
- kartı aynı veya başka kolona taşıyabilir,
- karta açıklama, dosya ve hatırlatıcı ekleyebilir,
- karta bir veya daha fazla etiket bağlayabilir,
- kart üzerinde kompakt etiket önizlemesi görebilir.

Kart sıralaması offline çalışmalı ve fractional indexing/LexoRank benzeri yaklaşım kullanılmalıdır.

### Kapsam dışında

- assignee,
- sprint/story point/velocity,
- Jira benzeri workflow motoru,
- webhook otomasyonları,
- Gantt / roadmap / portfolio yönetimi.

---

## 7. Dosya ve ek kapsamı

Kullanıcı notlara ve kartlara PDF, görsel, metin ve genel ofis dokümanları gibi dosyalar ekleyebilir.

### Saklama modeli

- Dosya byte'ları SQLite BLOB olarak saklanmaz.
- Dosyalar sandbox dosya alanında tutulur.
- DB yol/URI, isim, MIME, boyut, checksum ve sync metadata saklar.
- Bulut senkronizasyonu açık olduğunda dosya uzak storage'a yüklenebilir.

### Kapsam dışında

- tam PDF editörü,
- profesyonel annotation katmanı,
- Word/Excel/PowerPoint düzenleme,
- medya transcoding,
- OCR motoru,
- genel amaçlı bulut disk.

---

## 8. Hatırlatıcı kapsamı

Kullanıcı not veya kart için tarih/saat bazlı yerel hatırlatıcı oluşturabilir.

### Kapsam içinde

- tek seferlik bildirim,
- timezone-aware saklama,
- düzenleme/iptal,
- DB ↔ OS notification uzlaştırması,
- platform izin akışları,
- Android exact-alarm kısıtlarının güvenli yönetimi.

### İlk sürümde kapsam dışında

- karmaşık recurrence motoru,
- cron kuralları,
- konum/kişi bazlı reminder,
- SMS/e-posta/arama reminder.

Basit günlük/haftalık tekrar daha sonraki fazda ayrıca değerlendirilebilir.

---

## 9. Offline-first kapsamı

İnternet olmadan aşağıdakiler çalışmalıdır:

- uygulamanın açılması,
- not okuma/oluşturma/düzenleme,
- Kanban görüntüleme ve mutasyonları,
- yerel ekleri açma ve yeni ek ekleme,
- hatırlatıcı oluşturma/düzenleme,
- etiket oluşturma/yeniden adlandırma/atama/kaldırma,
- Akıllı Görünüm oluşturma/düzenleme/silme,
- Akıllı Görünüm sonuçlarını yerel veriden hesaplama,
- yerel arama ve metadata filtreleri,
- silme/geri alma.

Ağ hatası, işlem yerel olarak güvenli biçimde kaydedilebiliyorsa normal kullanıcı işlemini başarısız göstermemelidir.

---

## 10. Bulut senkronizasyon kapsamı

Bulut source-of-truth değildir. Yerel Drift DB istemci için birincil kaynaktır.

### Kapsam içinde

- delta tabanlı sync,
- sync queue,
- retry/backoff,
- idempotent uzak operasyonlar,
- entity version,
- tombstone silme,
- attachment upload/download,
- otomatik eşitleme,
- sync durumu ve hata tanılama,
- `tag`, `tag_assignment` ve `smart_view` senkronizasyonu.

### Conflict yaklaşımı

- version + updatedAt kontrolü,
- veri kaybını sessizce gizlememe,
- gerektiğinde iki sürümü karşılaştırma/seçme,
- deterministik etiket ve atama kimlikleriyle aynı mantıksal verinin iki cihazda çoğalmasını azaltma.

Pull sırasında bağımlı kayıtlar ebeveynlerinden önce uygulanamaz. Özellikle `tag` kaydı `tag_assignment` kaydından önce uygulanmalıdır.

### Kapsam dışında

- CRDT / OT,
- multi-user merge engine,
- presence/collaborative cursor.

---

## 11. Kimlik doğrulama kapsamı

Auth ürünün merkezi deneyimi değildir. Yerel kullanım mümkün olduğunca hesaba bağımlı olmamalıdır.

Bulut kullanımı için güvenli tek kullanıcı oturumu, session persistence ve çıkış yapma yeterlidir. İstemciye `service_role` benzeri ayrıcalıklı secret gömülmez.

---

## 12. Arama kapsamı

### Kapsam içinde

- not başlığı ve içeriği,
- kart başlığı/açıklaması,
- pano adı,
- tür bazlı gruplama,
- offline FTS,
- command palette,
- not/kart aramasında etiket filtresi,
- etiketli/etiketsiz filtresi,
- reminder var/yok,
- attachment var/yok,
- son N günde güncellenmiş içerik filtresi.

Pano araması FTS akışında kalır; not/karta özgü metadata filtreleri panolara uygulanmaz.

### Kapsam dışında

- web search,
- zorunlu semantic/vector search,
- OCR ile dosya içeriği indeksleme,
- harici Drive/Dropbox içeriğini indeksleme.

---

## 12.1 Etiketler ve Akıllı Görünümler

### Etiketler

Etiketler ayrı domain entity'sidir; not tablosuna virgüllü string olarak gömülmez.

Kapsam:

- not ve kart hedefleri,
- bir içeriğe birden çok etiket,
- normalize edilmiş tekil ad,
- renk anahtarı,
- oluşturma/yeniden adlandırma/renk değiştirme/silme,
- kullanım sayısı,
- offline-first çalışma,
- tombstone ve cihazlar arası sync.

Etiket silmek bağlı not veya kartı silmez.

### Akıllı Görünümler

Akıllı Görünüm sonuçları saklanmaz; versiyonlu bir `ContentFilter` tanımı saklanır.

`ContentFilter v1` şunları destekler:

- `notes | cards | all` kapsamı,
- metin sorgusu,
- tümü gerekli etiketler (`ALL`),
- herhangi biri yeterli etiketler (`ANY`),
- hariç tutulan etiketler (`NOT`),
- etiketli/etiketsiz,
- favori,
- reminder var/yok,
- attachment var/yok,
- son N gün,
- pano ve kolon sınırı,
- başlık/güncelleme sıralaması.

Hazır sistem görünümleri:

- Favoriler
- Etiketsiz
- Hatırlatıcılı
- Dosyalı
- Son 7 Gün

Kullanıcı ayrıca kendi Akıllı Görünümlerini oluşturabilir, düzenleyebilir ve silebilir.

### Kapsam dışında

- nested/hiyerarşik etiket ağacı,
- otomatik AI etiketleme,
- filtre sonucu üzerinde kural çalıştıran otomasyon motoru,
- Notion relation/rollup sistemi.

---

## 13. Ayarlar kapsamı

Kullanıcı en azından tema, bildirim izinleri, sync durumu, bulut oturumu, yerel depolama/cache ve tanılama bilgilerini yönetebilir.

Etiketlerin toplu yönetimi ikincil ürün yönetim ekranı olarak sunulabilir.

---

## 14. Tema ve kişiselleştirme sınırı

Light/dark/system tema, erişilebilir kontrast ve responsive düzen kapsam içindedir. Tema marketplace, kullanıcı CSS'i ve sınırsız component özelleştirme kapsam dışıdır.

---

## 15. Import / export sınırı

Veri kilitleme hedeflenmez. Markdown/JSON export için mimari alan bırakılır. Kapsamlı üçüncü parti import wizard'ları çekirdek akış tamamlanmadan geliştirilmez.

---

## 16. AI özellikleri

AI mevcut scope'un parçası değildir.

Kapsam dışında:

- AI yazma/özetleme,
- otomatik etiketleme,
- embedding/vector DB,
- RAG,
- OCR + LLM analizi,
- AI ajanları.

---

## 17. Entegrasyonlar

İlk ürün bağımsız çalışmalıdır. Google Calendar, Outlook, Gmail, Slack, Teams, Trello, Jira, GitHub issue sync, Zapier, IFTTT, public API ve plugin SDK kapsam dışıdır.

---

## 18. Güvenlik ve gizlilik sınırı

### Kapsam içinde

- sandbox veri saklama,
- secret'ları kaynak koda gömmeme,
- güvenli auth token saklama,
- TLS,
- kullanıcıya ait uzak veriyi RLS/politikalarla ayırma,
- loglara hassas içerik basmama,
- dosya yolları ve sync metadata'yı kontrollü yönetme.

Uygulama kendi kripto protokolünü icat etmez.

---

## 19. Veri sahipliği

Kullanıcı tarafından oluşturulan bütün içerik kullanıcı verisidir.

- Yerel değişiklik önce cihazda saklanır.
- Bulut tek kopya değildir.
- Sync hatası yerel veriyi otomatik silmez.
- Conflict çözülmeden sürüm sessizce kaybedilmez.
- Etiket ve ilişki silmeleri de tombstone/sync sürecine uyar.

---

## 20. Veri modeli sınırı

Temel entity'ler:

- Note
- Board
- BoardColumn
- KanbanCard
- Attachment
- Reminder
- Tag
- TagAssignment
- SmartView
- SyncOperation

`SmartView` sonucu ayrı entity değildir; `ContentFilter` sorgusundan üretilir.

Şimdilik oluşturulmaması gereken örnek entity'ler: Team, WorkspaceMember, Organization, Role, Permission, Assignee, BillingAccount, MarketplacePlugin.

---

## 21. Navigasyon sınırı

Ana üst düzey alanlar:

- Ana Sayfa
- Notlar
- Panolar
- Hatırlatıcılar
- Arama
- Ayarlar

Akıllı Görünümler ve Etiketler desktop sidebar/ikincil navigasyon veya mobil `Daha` alanından erişilir. Mobil alt navigasyona yeni sekmeler eklenmez.

---

## 22. UX sınırları

- offline normal çalışma modudur,
- manuel Save zorunlu değildir,
- masaüstünde klavye üretkenliği desteklenir,
- mobil eylemler başparmak erişimine uygun olmalıdır,
- destructive işlemlerde geri alma tercih edilir,
- sync teknik ayrıntıları ana akışı kirletmemelidir,
- etiketler içerik kartlarını görsel olarak boğmayan kompakt chip'ler olarak sunulmalıdır,
- çok kullanıcıya özgü avatar/member/assignee UI eklenmemelidir.

Detaylı tasarım sözleşmesi `docs/UX_DESIGN.md` içindedir.

---

## 23. Performans sınırı

- büyük dosya kopyalama UI thread üzerinde yapılmaz,
- dosya byte'ları DB BLOB alanına yazılmaz,
- Kanban reorder tüm kolonu her seferinde yeniden indekslemez,
- uzun listelerde lazy rendering kullanılır,
- gereksiz full-table read yapılmaz,
- sync UI'yı bloklamaz,
- Akıllı Görünüm filtreleri mümkün olduğunca SQLite seviyesinde çalışır,
- 10.000 içerik / yüzlerce etiket / binlerce assignment ölçeğinde Dart tarafında tüm içeriği tarayan filtreleme kabul edilmez.

---

## 24. Cache sınırı

Aktif/yakın kullanılan dosyalar cihazda tutulabilir; cache ölçümü ve güvenli LRU eviction yapılabilir. Henüz buluta çıkmamış tek yerel kopya cache temizliği adı altında silinemez.

---

## 25. Background çalışma sınırı

Ürün sonsuz daemon varsayımına dayanmaz. OS'in izin verdiği background mekanizmaları, app open/resume ve network trigger fırsatları kullanılır.

---

## 26. Ürün içi analitik ve telemetri

İlk ürün reklam SDK'larına, kullanıcı profillemeye, attribution veya heatmap sistemlerine bağlı değildir. Hata/performance telemetrisi eklenirse minimum veri prensibi uygulanır.

---

## 27. Monetizasyon sınırı

Mevcut kapsam kişisel kullanım ürünüdür. Subscription, tier/plan, freemium limitleri, ekip lisansı, billing ve reklam domain'e eklenmez.

---

## 28. Bildirim dışı iletişim sınırı

Proaktif iletişim yerel reminder bildirimleriyle sınırlıdır. Newsletter, marketing push, transactional email, SMS ve WhatsApp entegrasyonu kapsam dışıdır.

---

## 29. Core Release kapsamı

Çekirdek günlük kullanılabilir sürüm aşağıdaki zinciri eksiksiz çalıştırmalıdır:

### A. App shell
- iOS / Android / macOS açılışı
- responsive navigasyon
- light/dark tema

### B. Yerel veri
- Drift DB
- migration
- repository
- reactive stream

### C. Notlar
- CRUD / trash / favorite
- blok editörü
- arama
- etiketler

### D. Kanban
- board/column/card CRUD
- drag & drop
- fractional ranking
- kart etiketleri

### E. Attachments
- sandbox kopya / metadata / açma / silme

### F. Reminders
- CRUD / OS scheduling / timezone

### G. Tags + Smart Views
- Tag CRUD
- note/card assignment
- ALL/ANY/NOT filtreleri
- hazır görünümler
- kullanıcı tanımlı görünümler
- arama filtre entegrasyonu

### H. Sync
- tek hesap
- queue / retry / conflict
- attachment, tag, assignment ve smart-view sync

### I. Stabilite
- migration,
- offline/online,
- conflict,
- widget/domain,
- scale/performance,
- gerçek cihaz smoke testleri.

---

## 30. Core Release sonrası değerlendirilebilecek alanlar

Aşağıdakiler otomatik olarak scope içinde değildir:

- gelişmiş Markdown import/export,
- basit recurring reminders,
- widget / quick capture,
- share extension,
- templates,
- archive,
- backlink,
- graph view,
- nested/hiyerarşik tags,
- gelişmiş editor block tipleri,
- lokal AI,
- takvim görünümü.

---

## 31. Kesin kapsam dışı ürün yönleri

Planora şunlara dönüşmez:

1. takım işbirliği platformu,
2. kurumsal proje yönetim sistemi,
3. genel amaçlı bulut disk,
4. Office editör paketi,
5. sosyal ağ,
6. AI-first çalışma alanı,
7. Google Calendar yerine geçen takvim ürünü,
8. Zapier tipi otomasyon platformu,
9. Airtable tipi no-code database builder,
10. web publishing/CMS.

---

## 32. Teknik kapsam dışı anti-pattern'ler

Kabul edilmez:

- Widget içinden doğrudan SQLite/Drift sorgusu,
- Widget içinden doğrudan native plugin çağrısı,
- dosyaları SQLite BLOB saklama,
- her kart taşımada tüm kolon rank'larını yeniden yazma,
- remote response'u UI source-of-truth yapma,
- network yokken güvenli yerel mutasyonu reddetme,
- sync başarısız diye yerel değişikliği geri alma,
- secret/service-role gömme,
- migration olmadan schema değiştirme,
- domain'i Flutter/plugin tiplerine bağımlı kılma,
- feature A'nın feature B `data/` implementasyonuna doğrudan bağlanması,
- feature'lar arası UI bağımlılıklarını kontrolsüz büyütme.

Cross-feature erişim gerektiğinde `public/` sözleşmeleri veya application-level orchestration tercih edilir.

---

## 33. Scope değişiklik prosedürü

Yeni özellikten önce:

1. günlük kişisel kullanıma değeri,
2. offline davranışı,
3. yeni entity gereksinimi,
4. tek kullanıcı varsayımı,
5. harici servis bağımlılığı,
6. daha basit alternatif,
7. UX uyumu,
8. migration/sync/conflict etkisi,
9. performans etkisi

açıkça değerlendirilmelidir.

---

## 34. Definition of Scope Compliance

Bir iş scope'a uygun sayılmak için:

- mevcut ürün hedefini doğrudan desteklemeli,
- tek kullanıcı varsayımını korumalı,
- offline davranışı tanımlı olmalı,
- local-first veri modelini bozmamalı,
- gereksiz harici bağımlılık oluşturmamalı,
- UX sözleşmesine uymalı,
- veri kaybı/sync belirsizliği yaratmamalı,
- performans açısından açık anti-pattern getirmemelidir.

---

## 35. Referans belgeler

- `README.md` — genel mimari
- `docs/UX_DESIGN.md` — UX/design-system sözleşmesi
- `docs/TAGS_SMART_VIEWS.md` — Etiketler ve Akıllı Görünümler teknik sözleşmesi
- `docs/SCOPE.md` — ürün sınırları ve non-goals

Çelişki durumunda ürün kapsamı açısından bu dosya esas alınır.

---

## 36. Kısa ürün sınırı özeti

`Planora` şudur:

> Tek kişinin kendi cihazlarında kullandığı; internet olmasa da çalışan; not, Kanban, dosya eki, hatırlatıcı, etiket ve kayıtlı filtre görünümlerini bir araya getiren; bağlantı geldiğinde verilerini güvenli biçimde senkronize eden kişisel çalışma alanı.

`Planora` şunlar değildir:

> Takım uygulaması, kurumsal proje yönetim sistemi, sosyal ağ, AI platformu, Office paketi, bulut disk, otomasyon servisi veya Notion'ın bütün özelliklerini kopyalamaya çalışan genel amaçlı workspace ürünü.
