# Not — Ürün Kapsamı ve Sınırlar

> Durum: Ürün geliştirme için bağlayıcı scope belgesi  
> Kapsam: iOS, Android ve macOS Flutter istemcisi  
> Ürün modeli: Tek kullanıcı, offline-first, kişisel not + Kanban çalışma alanı

Bu belge `Not` uygulamasının ürün sınırlarını tanımlar. Amaç, geliştirme sırasında özelliklerin kontrolsüz büyümesini engellemek; mimari, UX ve uygulama kararlarının hangi ürün hedeflerine hizmet ettiğini açık tutmaktır.

Bu dosya, **ne yapılacağını** ve en az onun kadar önemli olarak **ne yapılmayacağını** tanımlar. Yeni bir özellik bu belgede açıkça kapsam içinde değilse varsayılan olarak kapsam dışıdır ve eklenmeden önce bu belge güncellenmelidir.

---

## 1. Ürün tanımı

`Not`, tek bir kişinin kendi cihazlarında kullanacağı, Notion benzeri fakat daha dar ve odaklı bir kişisel çalışma alanıdır.

Uygulama dört temel ihtiyacı bir araya getirir:

1. Not oluşturma ve düzenleme.
2. Notları ve işleri Kanban panolarında yönetme.
3. PDF, görsel ve belge gibi dosyaları nota/karta ekleme.
4. Yerel hatırlatıcı kurma ve verileri kullanıcının cihazları arasında bulut üzerinden senkronize etme.

Uygulamanın temel çalışma ilkesi **offline-first**'tür. Yerel veri tabanı birincil veri kaynağıdır. İnternet erişimi uygulamanın temel kullanım şartı değildir.

---

## 2. Ana ürün hedefi

Kullanıcı uygulamayı açtığında internet olup olmadığını düşünmeden aşağıdaki işleri yapabilmelidir:

- hızlı not oluşturmak,
- mevcut notu düzenlemek,
- Kanban kartı oluşturmak,
- kartı kolonlar arasında taşımak,
- dosya eklemek,
- hatırlatıcı tanımlamak,
- arama yapmak,
- daha önce açılmış yerel dosyalara ulaşmak.

Bağlantı geldiğinde değişiklikler kullanıcı müdahalesi gerektirmeden senkronize edilmelidir.

---

## 3. Ürün modeli: kesinlikle tek kullanıcı

Uygulama çok kullanıcılı bir ürün değildir.

Tek kullanıcı kararı geçici MVP sadeleştirmesi değil, mevcut ürün kapsamının temel varsayımıdır.

### Kapsam içinde

- Aynı kişinin birden fazla cihaz kullanması.
- Tek kişisel bulut hesabı ile cihazlar arası senkronizasyon.
- Aynı kullanıcının iPhone, Android telefon/tablet ve Mac cihazlarında aynı veriye erişmesi.

### Kapsam dışında

- çalışma alanı üyeleri,
- ekipler,
- organizasyonlar,
- davet sistemi,
- kullanıcı rolleri,
- RBAC,
- sahip/editor/viewer rolleri,
- kullanıcı atama,
- kart assignee alanı,
- yorumlarda kullanıcı mention sistemi,
- aynı belgeyi iki farklı kişinin gerçek zamanlı düzenlemesi,
- kullanıcılar arası paylaşım izinleri,
- public/private workspace modeli.

Tek kullanıcıya ait bulut kimliği yalnızca uzak verinin güvenliği ve cihazlar arası eşitleme için kullanılabilir.

---

## 4. Desteklenen platformlar

### Birincil platformlar

- macOS
- iOS
- Android

### Platform hedefi

Aynı Flutter codebase kullanılacaktır ancak platforma özgü davranış gerektiğinde native özelliklerden yararlanılabilir.

### Kapsam dışında

- Windows
- Linux masaüstü
- Web uygulaması
- browser extension
- watchOS
- Wear OS
- visionOS

Bu platformlar ileride ayrıca değerlendirilmedikçe mevcut geliştirme hedefinin parçası değildir.

---

## 5. Temel fonksiyonel kapsam

### 5.1 Notlar

Kullanıcı:

- yeni not oluşturabilir,
- başlık yazabilir,
- not içeriğini düzenleyebilir,
- notu favorileyebilir,
- notu silebilir ve çöp kutusundan geri alabilir,
- yakın zamanda kullanılan notları görebilir,
- not içinde temel zengin içerik blokları kullanabilir,
- nota dosya/ek iliştirebilir,
- nota hatırlatıcı bağlayabilir,
- notları arayabilir.

### Desteklenecek içerik blokları

İlk ürün kapsamı:

- paragraf,
- başlık seviyeleri,
- madde işaretli liste,
- numaralı liste,
- yapılacaklar/checkbox,
- alıntı,
- ayraç,
- basit kod bloğu,
- bağlantı,
- görsel,
- dosya eki.

### Kapsam dışında

- tam Notion blok ekosisteminin birebir kopyalanması,
- veritabanı görünümü olarak tablo/calendar/gallery sistemi,
- formül motoru,
- relation/rollup,
- spreadsheet motoru,
- Mermaid/diagram editörü,
- gelişmiş collaborative cursor,
- canlı yorum sistemi,
- page permissions,
- public web publishing,
- website builder.

---

## 6. Kanban kapsamı

Kullanıcı:

- pano oluşturabilir,
- panoyu yeniden adlandırabilir,
- pano silebilir,
- kolon oluşturabilir,
- kolon yeniden adlandırabilir,
- kolon sıralamasını değiştirebilir,
- kart oluşturabilir,
- kart düzenleyebilir,
- kart silebilir,
- kartı aynı kolon içinde taşıyabilir,
- kartı başka kolona taşıyabilir,
- karta açıklama/not ekleyebilir,
- karta dosya ekleyebilir,
- karta hatırlatıcı ekleyebilir.

Kart sıralaması offline çalışmalıdır ve O(N) toplu yeniden indeksleme yapılmamalıdır. Fractional indexing/LexoRank benzeri yaklaşım kullanılacaktır.

### Kapsam dışında

- kullanıcı atama,
- ekip bazlı kartlar,
- sprint yönetimi,
- story point,
- Scrum velocity,
- Jira benzeri issue workflow motoru,
- custom workflow automation,
- webhook tabanlı kart otomasyonları,
- bağımlılık grafiği,
- Gantt görünümü,
- roadmap görünümü,
- enterprise project portfolio yönetimi.

---

## 7. Dosya ve ek kapsamı

Kullanıcı notlara ve kartlara dosya ekleyebilir.

### Desteklenen temel sınıflar

- PDF,
- yaygın görsel formatları,
- metin dosyaları,
- ofis dokümanları gibi genel dosyalar.

### Saklama modeli

- Dosya byte'ları SQLite BLOB olarak saklanmaz.
- Dosyalar uygulamanın sandbox dosya alanında tutulur.
- DB yalnızca dosya yolu/URI, isim, MIME türü, boyut, checksum ve sync metadata saklar.
- Bulut senkronizasyonu açık olduğunda dosya Supabase Storage benzeri uzak depoya yüklenebilir.

### Kapsam içinde

- dosya seçme,
- yerel kopya oluşturma,
- dosya metadata kaydı,
- upload/download ilerlemesi,
- lokal cache,
- gerektiğinde LRU benzeri cache temizliği,
- ek silme,
- temel dosya önizleme veya sistem uygulamasıyla açma.

### Kapsam dışında

- uygulama içinde tam PDF editörü,
- PDF üzerine profesyonel annotation katmanı,
- Word/Excel/PowerPoint düzenleme motoru,
- video düzenleme,
- medya transcoding,
- OCR motoru,
- otomatik doküman sınıflandırma,
- dosya paylaşım servisi,
- Dropbox/Drive benzeri genel amaçlı dosya yöneticisi.

---

## 8. Hatırlatıcı kapsamı

Kullanıcı bir not veya kart için tarih ve saat bazlı yerel hatırlatıcı oluşturabilir.

### Kapsam içinde

- tek seferlik zamanlanmış bildirim,
- timezone-aware tarih/saat saklama,
- bildirim düzenleme,
- bildirim iptal etme,
- uygulama açılışında DB ile OS bildirim durumunu uzlaştırma,
- cihaz yeniden başlatma/platform yaşam döngüsü sonrasında mümkün olan en güvenilir yeniden planlama,
- Android/iOS/macOS izin akışları,
- Android exact-alarm kısıtlarını desteklenen sistem davranışlarına göre yönetme.

### İlk sürümde kapsam dışında

- karmaşık takvim recurrence motoru,
- cron benzeri tekrar kuralları,
- lokasyon bazlı reminder,
- kişi/iletişim bazlı reminder,
- SMS reminder,
- e-posta reminder,
- telefon araması reminder,
- sunucu push notification kampanyaları,
- alarm clock uygulaması gibi tam ekran kritik alarm deneyimi.

Basit günlük/haftalık tekrar ileride ayrıca değerlendirilebilir; temel ürünün çalışması buna bağlı değildir.

---

## 9. Offline-first kapsamı

Offline-first uygulamanın vazgeçilmez ürün özelliğidir.

### İnternet olmadan çalışması gerekenler

- uygulamanın açılması,
- mevcut notların okunması,
- not oluşturma ve düzenleme,
- Kanban panolarını görüntüleme,
- kart oluşturma/düzenleme/taşıma,
- daha önce cihazda bulunan ekleri açma,
- yeni yerel ek ekleme,
- hatırlatıcı oluşturma/düzenleme,
- yerel arama,
- silme ve geri alma gibi yerel işlemler.

### İnternet gerektirebilecek işlemler

- başka cihazdaki yeni değişiklikleri alma,
- yeni ek dosyanın buluta yüklenmesi,
- başka cihazda eklenmiş ve bu cihazda cache'lenmemiş dosyanın indirilmesi,
- ilk bulut oturumu oluşturma,
- hesap kurtarma gibi kimlik işlemleri.

### Kesin ürün kuralı

Ağ hatası normal kullanıcı işlemini başarısız göstermemelidir, eğer işlem yerel olarak güvenli biçimde kaydedilebiliyorsa.

UI'da “işlem başarısız” yerine gerekirse “cihazda kaydedildi, senkronizasyon bekliyor” durumu gösterilir.

---

## 10. Bulut senkronizasyon kapsamı

Bulut, uygulamanın source-of-truth'u değildir. Yerel Drift veri tabanı istemci için birincil kaynaktır.

### Senkronizasyonun amacı

- kullanıcının cihazları arasında veri devamlılığı,
- cihaz değişiminde verilerin geri getirilebilmesi,
- ek dosyaların cihazlar arasında erişilebilir olması.

### Kapsam içinde

- delta tabanlı senkronizasyon,
- sync queue,
- retry/backoff,
- idempotent uzak operasyonlar,
- entity version bilgisi,
- tombstone tabanlı silme,
- dosya upload/download durumu,
- bağlantı geri geldiğinde otomatik senkronizasyon,
- kullanıcıya anlaşılır sync durumu,
- sync hata tanılama ekranı.

### Conflict yaklaşımı

Tek kullanıcı olmasına rağmen aynı kişinin iki cihazda çevrimdışı değişiklik yapması mümkündür.

İlk ürün politikası:

- version + updatedAt kontrollü last-write-wins,
- kritik conflict durumunda veri kaybını sessizce gizlememek,
- gerektiğinde kullanıcıya iki sürümü karşılaştırma/seçme seçeneği sunmak,
- Kanban ranking değişikliklerini bağımsız alan olarak ele almak.

### Kapsam dışında

- gerçek zamanlı Google Docs tipi CRDT editörü,
- OT altyapısı,
- çok kullanıcılı merge engine,
- kullanıcı presence sistemi,
- collaborative cursor,
- multi-user event sourcing altyapısı.

---

## 11. Kimlik doğrulama kapsamı

Uygulama tek kullanıcılıdır. Auth ürünün merkezi deneyimi değildir.

### Yerel kullanım

Mimari, temel yerel kullanımın mümkün olduğunca kullanıcı hesabına bağımlı olmamasını hedefler.

### Bulut kullanımı

Bulut senkronizasyonu etkinleştirildiğinde tek kullanıcı hesabı gerekir.

### Kapsam içinde

- güvenli kullanıcı oturumu,
- session persistence,
- çıkış yapma,
- gerekli minimum hesap yönetimi.

### Kapsam dışında

- sosyal ağ profili,
- kullanıcı keşfi,
- takipçi/takip sistemi,
- kullanıcı dizini,
- organizasyon hesabı,
- admin paneli,
- kullanıcı rol matrisi,
- ekip onboarding'i.

İstemci uygulamasına Supabase `service_role` veya benzeri ayrıcalıklı secret gömülmez.

---

## 12. Arama kapsamı

### Kapsam içinde

- not başlığı arama,
- not içeriği arama,
- kart başlığı/açıklaması arama,
- pano adı arama,
- sonuçları türüne göre gruplayabilme,
- mümkün olduğu ölçüde offline yerel arama,
- command palette üzerinden hızlı navigasyon.

### Kapsam dışında

- internet çapında web search,
- semantic vector search zorunluluğu,
- AI embedding altyapısı,
- OCR ile dosya içeriği indeksleme,
- harici Google Drive/Dropbox içeriğini indeksleme.

Yerel FTS ihtiyaca göre uygulanabilir ancak uygulamanın temel domain modeli bunun belirli bir sağlayıcısına bağımlı olmamalıdır.

---

## 13. Ayarlar kapsamı

Kullanıcı en azından şu ayarları yönetebilir:

- tema: sistem / açık / koyu,
- bildirim izin ve tercihleri,
- senkronizasyon durumu,
- bulut oturumu,
- yerel depolama/cache bilgisi,
- cache temizleme,
- tanılama bilgileri.

### Kapsam dışında

- yüzlerce özelleştirme seçeneği,
- plugin marketplace ayarları,
- enterprise policy yönetimi,
- workspace yönetimi,
- rol ve erişim ayarları.

---

## 14. Tema ve kişiselleştirme sınırı

Light ve dark tema desteklenir.

UX tasarımının esasları `docs/UX_DESIGN.md` dosyasında tanımlanmıştır.

### Kapsam içinde

- sistem temasını takip etme,
- açık tema,
- koyu tema,
- erişilebilir kontrast,
- platforma uygun responsive düzen.

### Kapsam dışında

- tema marketplace,
- sınırsız kullanıcı CSS'i,
- kullanıcı tarafından tamamen özelleştirilebilir component sistemi,
- Notion benzeri workspace icon/avatar ekosistemi zorunluluğu.

---

## 15. Import / export sınırı

Temel ürünün çekirdeği veri kilitlemeyi hedeflememelidir.

### Hedeflenen kapsam

- notları makul, taşınabilir bir formatta dışa aktarma için mimari alan bırakılması,
- ek dosyaların kullanıcıya ait kalması,
- ilerleyen fazda basit Markdown/JSON export desteği.

### İlk uygulama fazlarında zorunlu değil

- kapsamlı import wizard,
- Notion workspace birebir import,
- Evernote migration,
- Obsidian vault migration,
- Google Keep import,
- tüm metadata'yı kayıpsız üçüncü parti dönüşümü.

Bu özellikler ana not/Kanban/offline/sync akışı tamamlanmadan geliştirilmemelidir.

---

## 16. AI özellikleri

AI mevcut scope'un parçası değildir.

### Kapsam dışında

- AI metin yazma,
- AI özetleme,
- otomatik etiketleme,
- doküman soru-cevap,
- embedding/vector database,
- RAG,
- OCR + LLM belge analizi,
- AI görev planlama,
- AI ajanları.

Mimari ileride AI eklenmesine engel olmamalıdır ancak bugünkü geliştirme sırasında AI uğruna domain veya veri modeli karmaşıklaştırılmamalıdır.

---

## 17. Entegrasyonlar

İlk ürün bağımsız çalışmalıdır.

### Kapsam dışında

- Google Calendar iki yönlü senkronizasyon,
- Outlook Calendar,
- Gmail,
- Slack,
- Teams,
- Trello,
- Jira,
- GitHub issue sync,
- Zapier,
- IFTTT,
- webhook platformu,
- public API,
- plugin SDK.

Harici entegrasyonlar temel ürün tamamlanmadan geliştirilmemelidir.

---

## 18. Güvenlik ve gizlilik sınırı

### Kapsam içinde

- kullanıcı verilerini uygulamanın sandbox alanında saklama,
- secret'ları kaynak koda gömmeme,
- güvenli auth token saklama,
- HTTPS/TLS kullanan uzak iletişim,
- Supabase tarafında tek kullanıcının yalnız kendi verisine erişmesini sağlayan veri politikaları,
- loglara hassas içerik basmama,
- dosya yollarını ve sync metadata'yı kontrollü yönetme.

### İlk sürüm için kapsam dışında

- uçtan uca şifreli collaborative workspace,
- Signal benzeri kriptografik protokol,
- kurum yönetimli anahtar altyapısı,
- MDM yönetim paneli,
- enterprise DLP,
- SIEM entegrasyonu,
- SSO/SAML/SCIM.

Disk şifreleme gerektiğinde işletim sisteminin güvenli depolama ve cihaz şifreleme yeteneklerinden yararlanılır; uygulama kendi kripto protokolünü icat etmez.

---

## 19. Veri sahipliği

Kullanıcı tarafından oluşturulan bütün içerik kullanıcı verisidir.

Temel ilkeler:

- Yerel değişiklik önce cihazda güvenli biçimde saklanır.
- Bulut senkronizasyonu yerel verinin tek kopyası olmamalıdır.
- Bir sync hatası yerel veriyi otomatik silmemelidir.
- Conflict çözülmeden bir sürüm sessizce geri döndürülemez şekilde kaybedilmemelidir.
- Dosya silme işlemleri sync/tombstone süreci tamamlanana kadar kontrollü yürütülmelidir.

---

## 20. Veri modeli sınırı

Temel entity'ler:

- Note
- Board
- BoardColumn
- KanbanCard
- Attachment
- Reminder
- SyncOperation

Gerekli destek entity'leri eklenebilir ancak yeni domain kavramı oluşturmak scope genişletme gerekçesi değildir.

### Şimdilik oluşturulmaması gereken entity örnekleri

- Team
- WorkspaceMember
- Organization
- Role
- Permission
- Assignee
- CommentAuthor
- SubscriptionPlan
- BillingAccount
- MarketplacePlugin

---

## 21. Navigasyon sınırı

Ana üst düzey navigasyon alanları:

- Ana Sayfa
- Notlar
- Panolar
- Hatırlatıcılar
- Arama
- Ayarlar

Sync Center, Çöp Kutusu, Dosya Görüntüleyici ve benzeri alanlar ikincil navigasyon veya bağlamsal ekran olabilir.

Ürün büyüdükçe ana navigasyona kontrolsüz yeni sekmeler eklenmemelidir.

---

## 22. UX sınırları

Detaylı kurallar `docs/UX_DESIGN.md` dosyasındadır.

Scope açısından zorunlu UX ilkeleri:

- offline durum normal bir çalışma modu olarak sunulur,
- her düzenleme için manuel Save butonu zorunlu tutulmaz,
- masaüstünde üretkenlik için klavye kullanımı desteklenir,
- mobilde temel eylemler başparmak erişimine uygun olmalıdır,
- kritik olmayan işlemler modal yığını oluşturmamalıdır,
- destructive işlemlerde geri alma tercih edilir,
- sync teknik ayrıntıları ana kullanıcı akışını kirletmemelidir,
- çok kullanıcılı ürünlere özgü avatar/member/assignee UI bileşenleri eklenmemelidir.

---

## 23. Performans sınırı

Ürün mimarisi aşağıdaki davranışları hedefler:

- UI thread üzerinde büyük dosya kopyalama yapılmaması,
- dosya byte'larının DB BLOB alanına yazılmaması,
- Kanban reorder işleminde kolonun tamamının yeniden indekslenmemesi,
- uzun listelerde lazy rendering/virtualization yaklaşımı,
- veritabanı sorgularında gereksiz full-table read yapılmaması,
- sync işlemlerinin UI'yı bloklamaması,
- büyük attachment işlemlerinde progress ve iptal edilebilirlik için altyapı bırakılması.

Kesin performans eşikleri gerçek cihaz profiling sonuçlarıyla belirlenecektir; ancak mimari baştan açıkça pahalı anti-pattern'lere izin vermemelidir.

---

## 24. Cache sınırı

### Kapsam içinde

- kullanıcının aktif ve yakın zamanda kullandığı dosyaları cihazda tutmak,
- cache boyutunu ölçmek,
- güvenli cache temizleme,
- ihtiyaç halinde LRU benzeri eviction,
- uzak dosyanın local availability durumunu izlemek.

### Kesin kural

Kullanıcının cihazda oluşturduğu ve henüz buluta senkronize edilmemiş tek kopya, cache temizliği adı altında silinemez.

Eviction yalnız yeniden indirilebilir veya güvenli biçimde başka yerde bulunan içeriklerde uygulanmalıdır.

---

## 25. Background çalışma sınırı

Mobil işletim sistemleri sürekli background process garantisi vermez.

Bu nedenle ürün:

- sonsuz çalışan daemon varsayımına dayanmaz,
- işletim sisteminin izin verdiği background mekanizmalarını kullanır,
- sync için uygulama açılışı, resume ve network trigger gibi fırsatları değerlendirir,
- notification scheduling'i işletim sistemine devreder.

### Kapsam dışında

- Android/iOS kısıtlarını aşmak için güvenilmez sürekli servis hack'leri,
- battery optimization bypass'ını varsayan ürün davranışı,
- uygulama kapalıyken sürekli çalışan özel sync daemon garantisi.

---

## 26. Ürün içi analitik ve telemetri

İlk ürünün çalışması üçüncü taraf davranış analitiğine bağlı değildir.

### Başlangıçta kapsam dışında

- reklam SDK'ları,
- kullanıcı profilleme,
- pazarlama attribution SDK'ları,
- davranış izleme heatmap'leri.

Hata/performans telemetry'si ileride eklenirse gizlilik odaklı ve minimum veri prensibiyle değerlendirilmelidir.

---

## 27. Monetizasyon sınırı

Mevcut kapsam kişisel kullanım ürünüdür.

### Kapsam dışında

- ödeme ekranı,
- App Store subscription sistemi,
- tier/plan matrisi,
- freemium limitleri,
- ekip lisansı,
- ödeme altyapısı,
- reklam.

Bu nedenle domain modeline şimdiden `plan`, `billing`, `quota`, `seat` gibi kavramlar eklenmemelidir.

---

## 28. Bildirim dışı iletişim sınırı

Uygulamanın kullanıcıyla proaktif iletişimi yerel reminder bildirimleriyle sınırlıdır.

### Kapsam dışında

- newsletter,
- marketing push,
- transactional email altyapısı,
- SMS,
- WhatsApp entegrasyonu,
- in-app campaign sistemi.

---

## 29. MVP / Core Release kapsamı

İlk pazarlanabilir veya günlük kullanılabilir çekirdek sürüm aşağıdaki zinciri eksiksiz çalıştırmalıdır:

### A. App shell

- iOS / Android / macOS açılışı
- responsive ana navigasyon
- light/dark tema
- temel routing

### B. Yerel veri

- Drift DB
- migration altyapısı
- repository katmanı
- reactive stream'ler

### C. Notlar

- oluşturma
- düzenleme
- silme/geri alma
- favoriler
- temel bloklar
- arama

### D. Kanban

- board/column/card CRUD
- drag & drop
- fractional ranking
- optimistic UI

### E. Attachments

- seçme
- sandbox'a kopyalama
- metadata
- görüntüleme/açma
- silme

### F. Reminders

- oluşturma
- düzenleme
- iptal
- OS scheduling
- timezone yönetimi

### G. Sync

- tek hesap
- sync queue
- metadata sync
- attachment sync
- retry/backoff
- conflict koruması
- sync status

### H. Stabilite

- migration testleri
- offline/online geçiş testleri
- conflict testleri
- temel widget/domain testleri
- gerçek cihaz smoke testleri

Bu sekiz alan tamamlanmadan büyük yeni özellik alanları açılmamalıdır.

---

## 30. Core Release sonrası değerlendirilebilecek alanlar

Aşağıdaki özellikler **otomatik olarak scope içinde değildir**; yalnız çekirdek ürün stabil olduktan sonra ayrıca karar verilebilir:

- gelişmiş Markdown import/export,
- basit recurring reminders,
- widget / quick capture,
- share extension,
- daha güçlü full-text search,
- tags,
- templates,
- archive,
- backlink,
- graph view,
- gelişmiş editor block tipleri,
- lokal AI özellikleri,
- takvim görünümü.

Bu maddeler roadmap adayıdır; mevcut geliştirme görevlerine doğrudan eklenmemelidir.

---

## 31. Kesin kapsam dışı ürün yönleri

Aşağıdaki yönlerden herhangi birine dönüşmek mevcut scope'u ihlal eder:

1. **Takım işbirliği platformu** — Notion Teams/Confluence/ClickUp benzeri.
2. **Kurumsal proje yönetimi sistemi** — Jira/MS Project benzeri.
3. **Genel amaçlı bulut disk** — Dropbox/Drive benzeri.
4. **Office editör paketi** — Word/Excel/PDF editor benzeri.
5. **Sosyal ağ** — kullanıcı profili, takip, paylaşım feed'i.
6. **AI-first çalışma alanı** — bütün ürünün LLM'e bağımlı olması.
7. **Takvim ürünü** — Google Calendar yerine geçme.
8. **Görev otomasyon platformu** — Zapier/IFTTT benzeri.
9. **No-code database builder** — Airtable benzeri.
10. **Web publishing/CMS** — website/blog builder.

---

## 32. Teknik kapsam dışı anti-pattern'ler

Aşağıdaki uygulamalar kabul edilmez:

- Widget içinden doğrudan SQLite/Drift sorgusu çalıştırmak.
- Widget içinden doğrudan `FilePicker` veya native notification plugin çağırmak.
- Dosyaları SQLite BLOB olarak saklamak.
- Her kart taşımasında tüm kolon sıralarını yeniden yazmak.
- Remote API response'unu doğrudan UI source-of-truth yapmak.
- Network yokken kullanıcı değişikliğini reddetmek.
- Sync başarısız diye yerel değişikliği geri almak.
- Secret/service-role anahtarını uygulamaya gömmek.
- Migration olmadan DB schema değiştirmek.
- Domain katmanını Flutter widget veya plugin tiplerine bağımlı hale getirmek.
- Tek kullanıcı üründe gereksiz Team/Role/Permission modeli kurmak.

---

## 33. Scope değişiklik prosedürü

Yeni özellik eklenmeden önce şu sorular cevaplanmalıdır:

1. Bu özellik mevcut dört temel alanın hangisine hizmet ediyor: notes, kanban, attachments, reminders/sync?
2. Kullanıcının günlük kişisel kullanımını belirgin biçimde iyileştiriyor mu?
3. Offline-first çalışabilir mi veya offline davranışı açıkça tanımlı mı?
4. Yeni domain entity'si gerçekten gerekli mi?
5. Çok kullanıcı varsayımını yanlışlıkla içeri taşıyor mu?
6. Ürünün bağımsız çalışmasını üçüncü parti servise bağımlı hale getiriyor mu?
7. Var olan daha basit bir özellikle aynı ihtiyacı karşılamak mümkün mü?
8. Yeni özellik UX_DESIGN ile uyumlu mu?
9. Veri migration/sync/conflict etkisi tanımlandı mı?
10. Eklenen karmaşıklık sağladığı değere değiyor mu?

Bu soruların cevabı net değilse özellik implementation'a alınmamalıdır.

---

## 34. Definition of Scope Compliance

Bir geliştirme işi scope'a uygun kabul edilirken:

- mevcut ürün hedeflerinden en az birini doğrudan desteklemeli,
- tek kullanıcı varsayımını korumalı,
- offline davranışı tanımlı olmalı,
- local-first veri modelini bozmamalı,
- yeni gereksiz harici servis bağımlılığı oluşturmamalı,
- UX tasarım sözleşmesine aykırı yeni pattern getirmemeli,
- veri kaybı veya sync belirsizliği oluşturmamalı,
- kapsam dışı bir ürün kategorisini dolaylı biçimde inşa etmeye başlamamalıdır.

---

## 35. Referans belgeler

Bu scope aşağıdaki proje belgeleriyle birlikte değerlendirilmelidir:

- `README.md` — genel mimari ve proje başlangıç bilgileri
- `docs/UX_DESIGN.md` — ekran, interaction ve design-system sözleşmesi
- `docs/SCOPE.md` — ürün sınırları ve non-goals

Çelişki durumunda ürün kapsamı açısından bu dosya, UI ayrıntıları açısından `UX_DESIGN.md`, teknik mimari açısından README'deki mimari prensipler esas alınır.

---

## 36. Kısa ürün sınırı özeti

`Not` şudur:

> Tek kişinin kendi cihazlarında kullandığı; internet olmasa da çalışan; not, Kanban, dosya eki ve hatırlatıcı işlevlerini bir araya getiren; bağlantı geldiğinde verilerini güvenli biçimde senkronize eden kişisel çalışma alanı.

`Not` şunlar değildir:

> Takım uygulaması, kurumsal proje yönetim sistemi, sosyal ağ, AI platformu, Office paketi, bulut disk, otomasyon servisi veya Notion'ın bütün özelliklerini kopyalamaya çalışan genel amaçlı workspace ürünü.
