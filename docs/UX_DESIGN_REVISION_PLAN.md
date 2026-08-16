# Not — UX Design Revizyon Planı

> Durum: Uygulama öncesi revizyon planı  
> Hedef: Sade, modern, içerik-öncelikli, platforma uyumlu kullanıcı deneyimi  
> Kapsam: Flutter iOS / Android / macOS istemcisi  
> İlişkili belge: `docs/UX_DESIGN.md`  
> Tarih: 2026-08-16

---

## 1. Amaç

Bu belge, mevcut `UX_DESIGN.md` spesifikasyonunu kaldırmak veya baştan yazmak için değil; mevcut uygulama ile tasarım spesifikasyonu arasındaki farkları kapatmak ve ürünün görsel/etkileşimsel dilini sadeleştirmek için uygulanabilir bir revizyon sırası tanımlar.

Revizyonun hedefi:

- uygulamayı daha az “Material bileşenleri yan yana getirilmiş” hissettirmek,
- içerik alanını arayüz kromundan daha baskın hâle getirmek,
- not yazma ve Kanban kullanımını uygulamanın merkezine almak,
- desktop, tablet ve telefonda aynı ürün dilini korurken her form faktörünün güçlü taraflarını kullanmak,
- sık kullanılan eylemleri hızlandırmak,
- modal/dialog sayısını azaltmak,
- görsel yoğunluğu düşürürken bilgi yoğunluğunu korumak,
- offline-first ve otomatik kaydetme davranışlarını kullanıcıya güven veren fakat dikkat dağıtmayan biçimde göstermek.

Bu revizyon **veri modeli, repository sözleşmeleri veya senkronizasyon mimarisini yeniden tasarlama işi değildir**. Gerektiğinde mevcut yeteneklerin UI karşılığı değişir; yeni backend özelliği yalnız UX'in çalışması için zorunluysa ayrıca planlanır.

---

# 2. Mevcut durum değerlendirmesi

## 2.1 Güçlü taraflar

Mevcut kod tabanında revizyonu hızlandıracak iyi bir temel vardır:

- `AppTheme` altında ortak renk, spacing ve breakpoint tanımları mevcut.
- Light/dark tema altyapısı hazır.
- `AppPageHeader`, `EmptyState`, `ErrorState`, `AppButton`, `AppTextField` gibi ortak bileşen başlangıçları var.
- Responsive shell compact / medium / expanded olarak ayrılmış.
- Not editörü `760 dp` içerik genişliği, slash command, selection toolbar ve block modeline sahip.
- Global focus-dismiss davranışı uygulama seviyesinde çözülmüş.
- Kanban kartlarında kolonlar arası taşıma, kolon içi sıralama, edge auto-scroll ve doğrudan taşıma aksiyonları mevcut.
- Arama klavye ile kullanılabiliyor ve `⌘/Ctrl + K` kısayolu mevcut.
- Senkronizasyon durumu global shell içinde görünür.

Bunlar korunmalı; revizyon mümkün olduğunca mevcut davranışları bozmayacak şekilde presentation katmanında ilerlemelidir.

## 2.2 Ana UX problemleri

### A. Görsel dil ortak fakat yeterince uygulanmış değil

`Calm Paper` yönü doğru olmasına rağmen gerçek ekranlarda Material 3 varsayılan bileşen dili hâlâ çok baskın. Özellikle `ListTile`, `Card`, `SegmentedButton`, `AppBar`, `FilledButton` ve standart dialog kombinasyonları ekranları jenerik gösteriyor.

### B. Fazla yüzey, border ve kart kullanımı

Ana Sayfa `SectionCard` bloklarından, Pano listesi Card'lardan, Kanban kolonları yine büyük Card'lardan oluşuyor. Bu katmanlama içerik hiyerarşisi yerine “kart içinde kart” hissi yaratıyor.

### C. Sayfa başlıkları gereğinden fazla yer kaplıyor

Birçok ana ekranda başlık + açıklama + action kombinasyonu tekrar ediyor. Desktop'ta bu yapı dikey alan tüketiyor ve üretkenlik uygulamasından çok ayar/örnek uygulama hissi veriyor.

### D. Basit işlemler için dialog yoğunluğu

Yeni pano, yeni kolon, yeni kart, yeniden adlandırma ve bazı düzenleme akışları dialog üzerinden ilerliyor. Basit içerik üretiminde inline edit, popover, side sheet veya bottom sheet daha hızlıdır.

### E. Not editöründe üst bar fazla teknik

Editor AppBar'ında blok ekleme, ek dosya, hatırlatıcı, manuel kaydetme ve menü aynı anda görünür. Otomatik kaydetme kullanan bir üründe manuel “Şimdi kaydet” aksiyonu ana UI'da olmamalıdır.

### F. Kart detay ekranı ürün modeline ters biçimde manuel kaydetme istiyor

Not editörü autosave kullanırken kart detayında `Kaydet` butonu bulunuyor. Aynı uygulamadaki iki içerik türünün kaydetme modeli farklı hissediyor.

### G. Desktop'ta detaylar bağlamı gereksiz koparıyor

Not editörü ve kart detayları çoğunlukla yeni route olarak açılıyor. Geniş ekranda liste/pano bağlamını koruyan split-view ve side sheet daha verimlidir.

### H. Arama güçlü fakat command palette deneyimi tamamlanmamış

`⌘K` kullanıcıyı Arama ekranına götürüyor. Desktop için gerçek floating command palette daha hızlı ve modern bir deneyim sağlar; tam sayfa Arama ise ayrıca kalabilir.

### I. Renk kullanımı içerikten fazla dikkat çekebiliyor

Not, kolon ve kartlara verilen renkler geniş tinted surface olarak kullanıldığında aynı anda çok sayıda renkli yüzey oluşabilir. Renk, kimlik/ayırt etme amacıyla nokta, ince accent veya küçük badge seviyesinde tutulmalıdır.

### J. Platform tipografisi yeterince native değil

Tema tipografisi `Typography.material2021(platform: TargetPlatform.android)` üzerinden kuruluyor. Bu, macOS/iOS'ta ürünün native hissini azaltır. Platform fontları ve ölçüleri form faktörüne göre ele alınmalıdır.

---

# 3. Yeni tasarım yönü — “Quiet Workspace”

Revizyonun görsel karakteri **Quiet Workspace** olarak ele alınacaktır.

Ana fikir: Kullanıcı arayüzü fark etmek yerine içeriği fark etmelidir.

## 3.1 İlkeler

1. **İçerik > krom**  
   Başlıklar, toolbarlar, kart sınırları ve dekoratif renkler geri planda kalır.

2. **Tek güçlü vurgu**  
   Accent rengi seçim, focus ve birincil CTA için kullanılır. Büyük renkli alanlardan kaçınılır.

3. **Border önce, gölge sonra**  
   Gölge yalnız floating öğelerde: command palette, popover, context menu, drag feedback.

4. **Desktop yoğun, mobil rahat**  
   Desktop'ta pointer/klavye için daha kompakt görsel kontrol; mobilde minimum 44–48 dp dokunma alanı.

5. **Autosave varsayılan davranış**  
   Kaydet butonu içerik düzenleme ekranlarında kaldırılır. Durum pasif metadata olarak görünür.

6. **Inline işlem > dialog**  
   İsim değiştirme, kart ekleme, kolon ekleme gibi düşük riskli işlemler mümkün olduğunca yerinde yapılır.

7. **Renk kimliktir, zemin değildir**  
   Pano/kolon/kart/not renkleri küçük göstergelerde kullanılır; tüm yüzeyi boyamaz.

8. **Progressive disclosure**  
   Nadir eylemler her zaman görünmez. Hover/focus/context menu ile ortaya çıkar.

9. **Klavye ve dokunmatik eşdeğer vatandaş**  
   Hiçbir temel işlem yalnız hover, drag veya sağ tık üzerinden erişilebilir olmamalıdır.

---

# 4. Tasarım sistemi revizyonu

## 4.1 Renkler

Mevcut Calm Paper paleti korunabilir ancak kullanım sadeleştirilmelidir.

### Light

- `canvas`: sıcak kırık beyaz
- `surface`: beyaz
- `surfaceSubtle`: yalnız hover / seçili grup / kolon zemini
- `border`: düşük kontrast nötr
- `accent`: tek ana indigo/mor
- `danger`, `warning`, `success`: yalnız durum/eylem alanında

### Dark

- saf siyah yerine katmanlı koyu nötrler
- yüzey ayrımı border ve düşük luminance farkıyla
- accent doygunluğu azaltılmış

### Uygulama kuralı

Entity renkleri:

- pano kartında 3–4 px accent çizgisi veya küçük nokta,
- kolon başlığında 8 px nokta,
- kartta maksimum ince üst/sol accent veya küçük badge,
- not listesinde küçük nokta/ikon accent.

Entity rengi tüm kart/kolon arka planını boyamamalıdır.

## 4.2 Tipografi

Platform-aware tipografi kullanılmalı.

- iOS/macOS: sistem SF ailesi
- Android: sistem Roboto
- özel font bundle etmek zorunlu değil

Önerilen ölçek:

| Rol | Desktop | Mobile | Ağırlık |
| --- | ---: | ---: | ---: |
| Page title | 22 | 22 | 650/700 |
| Editor title | 30 | 28 | 700 |
| Section | 16 | 17 | 600 |
| Body | 15–16 | 16 | 400 |
| UI label | 13–14 | 14 | 500/600 |
| Metadata | 12 | 12–13 | 400 |

Not editörü line-height rahat tutulmalı; diğer UI metinleri daha kompakt olabilir.

## 4.3 Radius

Radius sayısı azaltılmalı:

- küçük control: 8
- card / list hover surface: 10
- floating surface / sheet: 12–14

Her bileşende farklı radius kullanımı engellenmeli.

## 4.4 Spacing

4 dp grid korunacak.

Ana ölçek:

- 4: mikro
- 8: control içi
- 12: yakın öğeler
- 16: standart blok
- 24: bölüm
- 32: ana sayfa kenarı / büyük ayrım

Desktop'ta her ekranda otomatik 24 px üst-alt padding kullanmak yerine bağlama göre 16–24 aralığı kullanılmalı.

## 4.5 Control yoğunluğu

Visual control yüksekliği:

- desktop: 36–40 dp
- touch: 44–48 dp

Hit target erişilebilirlik nedeniyle minimum 44 dp korunur; ancak desktop'ta görsel yüzey 48 dp olmak zorunda değildir.

## 4.6 Motion

- hover/focus: 100–120 ms
- sheet/palette: 160–200 ms
- drag insertion: 120–160 ms
- büyük bounce/overshoot kullanılmaz
- reduced-motion sistem tercihine uyulur

---

# 5. Uygulama kabuğu ve navigasyon

## 5.1 Expanded / macOS

Mevcut 248 dp sidebar sadeleştirilecek.

Hedef:

- varsayılan genişlik: `224–232 dp`
- collapsed: `56–60 dp`
- üstte küçük logo + `Not`
- orta navigasyon: Ana Sayfa, Notlar, Panolar, Hatırlatıcılar
- Arama ayrı bir nav satırı olmak yerine üst/orta bölümde `Ara  ⌘K` affordance'ı olabilir
- Ayarlar sidebar'ın alt bölümünde kalır
- sync status en altta küçük status chip/row olur

Seçili nav öğesi güçlü mor dolgu yerine düşük kontrast tonal yüzey + belirgin icon/text ile gösterilir.

## 5.2 Medium

NavigationRail korunur ancak label yoğunluğu azaltılır.

- rail 64–72 dp
- aktif label görünür, diğerleri tooltip ile desteklenebilir
- tablet landscape'te opsiyonel mini-expanded rail

## 5.3 Compact

Alt navigation 5 hedefi korur:

- Ana
- Notlar
- Panolar
- Hatırlatıcılar
- Daha

`Daha` yalnız Arama, Ayarlar ve sync durumunu içerir; içeride ikinci bir uygulama ana ekranı gibi görünmemelidir.

## 5.4 Global top bar

Ana ekranlarda tek ortak top bar davranışı oluşturulmalı.

- yükseklik desktop ~52–56
- başlık kısa
- açıklama metni varsayılan olarak gösterilmez
- açıklama yalnız onboarding/empty state veya gerçekten bağlam gerektiren ekranlarda
- birincil eylem sağda
- ikincil eylemler icon/overflow

`AppPageHeader` mevcut hâliyle her ekranda kullanılmak yerine `AppToolbar` / `PageToolbar` modeline dönüştürülmelidir.

---

# 6. Ekran bazlı revizyon

## 6.1 Ana Sayfa

### Sorun

Mevcut ekran üç ayrı `SectionCard` listesi ve “Hızlı not” butonu üzerinden ilerliyor. Bu yapı dashboard'dan çok üst üste kart listeleri gibi görünüyor.

### Hedef

Desktop:

```text
Ana Sayfa                                      [Yeni not]

[ Bir fikir, görev veya not yaz…                         ]

Son notlar                            Bugün
──────────────────────                ──────────────────
Not A                                 09:30 Hatırlatıcı
Not B                                 14:00 ...
Not C

Panolar
[Pano] [Pano] [Pano]
```

Revizyon:

- üstte gerçek Quick Capture input,
- Enter ile doğrudan not oluşturma,
- kart çerçevesi yerine açık section düzeni,
- desktop'ta son notlar + bugün iki kolon,
- mobilde tek kolon,
- “Son panolar” hafif grid/list,
- empty state yalnız ihtiyaç olduğunda.

## 6.2 Notlar listesi

### Hedef

Desktop'ta bilgi yoğun fakat sakin liste.

Toolbar:

- `Notlar`
- filtre/sort/view kontrolleri
- `Yeni not`

Filtreler:

- expanded: küçük secondary navigation veya compact dropdown
- segmented control sürekli geniş alan kaplamamalı

Liste satırı:

- renk göstergesi
- başlık
- 1 satır preview
- güncelleme zamanı
- favori / reminder / attachment metadata
- actions yalnız hover/focus'ta; mobile'da overflow

Görünüm:

- Liste default
- Grid opsiyonel

Desktop ileri hedefi:

- geniş pencere varsa master-detail: not listesi solda, editör sağda
- mobile'da mevcut route yaklaşımı korunur

## 6.3 Not editörü — en yüksek öncelik

Editor ürünün ana yüzeyi olarak yeniden ele alınacak.

### Üst bar

Göster:

- geri/breadcrumb
- küçük autosave/sync durumu
- favori
- `...`

Kaldır / overflow'a taşı:

- manuel “Şimdi kaydet”
- sürekli görünen “blok ekle” action
- attachment ve reminder için ayrı ayrı kalıcı toolbar icon'ları

Overflow:

- Hatırlatıcı ekle
- Dosya/görsel ekle
- Kart oluştur
- Dışa aktar
- Çöpe taşı

### Gövde

- max width `720–760 dp`
- title üstte daha belirgin
- metadata gereksizse görünmez
- block spacing normalize edilir
- her blokta sürekli sağ `...` yerine hover/focus gutter

Desktop block gutter:

```text
[+] [⋮⋮]   blok içeriği
```

- `+`: insert
- drag handle: reorder + context
- yalnız hover/focus halinde görünür

Mobil:

- seçili blok için küçük handle/context
- blok taşıma için erişilebilir menü alternatifi

### Slash menu

- gerçek floating popover
- kategori başlıkları
- keyboard navigation
- seçili öğe net focus state
- ekran kenarlarına çarpmadan konumlanan overlay

### Selection toolbar

- metnin hemen üst/altına anchored floating toolbar
- yalnız mevcut alan kadar action
- mobilde sistem selection ile yarışmayacak sade varyant

### Alt bölüm

Editor sonunda kalıcı “Hatırlatıcılar” bölümü gösterilmemeli.

Hatırlatıcılar:

- toolbar/overflow üzerinden açılan side sheet / bottom sheet
- mevcut hatırlatıcı varsa üst barda küçük metadata chip/ikon

### Silme

- “Çöpe taşı” confirmation dialog olmadan uygulanır
- snackbar: `Not çöp kutusuna taşındı · Geri al`
- kalıcı silme yalnız Çöp Kutusu'nda confirmation ister

## 6.4 Pano listesi

Pano kartları sadeleştirilecek.

Kart:

- ince border veya hover surface
- renk yalnız accent çizgisi/nokta
- pano adı
- kolon/kart sayısı (veri hazırsa)
- son değişiklik
- küçük kolon preview opsiyonel
- menu yalnız hover/focus/mobile overflow

Yeni pano:

- desktop: küçük anchored dialog/popover veya side sheet
- mobile: bottom sheet
- gereksiz büyük modal yok

## 6.5 Kanban pano — en yüksek öncelik

### Genel

Mevcut büyük `Card` kolon yaklaşımı hafifletilecek.

- pano zemini canvas
- kolonlar düşük kontrast `surfaceSubtle`
- kolon çerçevesi minimum
- kartlar kolon yüzeyinden net fakat sade ayrılır

### Toolbar

```text
Panolar / Proje adı                         [+ Kart] [•••]
```

- pano adı mümkünse inline rename
- “Kolon ekle” board'un en sağında yeni kolon yüzeyi olarak da sunulabilir

### Kolon

- genişlik desktop ~300–312
- mobile viewport'un ~85–88%'i
- başlık satırı kompakt
- renk noktası
- kart sayısı secondary text
- menu
- alt `+ Kart ekle`

### Kart

- title
- gerekiyorsa 1–2 satır preview
- reminder/attachment metadata
- entity renkleri yüzeyi boyamaz

Taşıma kontrolleri korunur:

- sol kolon yoksa sol ok gösterilmez
- sağ kolon yoksa sağ ok gösterilmez
- desktop'ta küçük ghost icon alanı hover/focus'ta görünür olabilir
- touch cihazında context action / doğrudan erişilebilir alternatif korunur
- drag & drop aynı kolon ve kolonlar arasında çalışır

### Drag & drop

- dragged card hafif elevation
- kaynak placeholder
- hedefte “Buraya taşı” kutusu yerine ince insertion indicator tercih edilir
- kolon hedefi için tüm kolon outline yerine net ama düşük gürültülü highlight
- edge auto-scroll korunur
- drop sonrası optimistic görünüm

## 6.6 Kart detayı

### Sorun

Mevcut ekran geniş bir full-screen form ve `Kaydet` butonu kullanıyor.

### Hedef

Desktop:

- sağ side sheet `400–440 dp`
- pano görünmeye devam eder

Mobile:

- full-screen route

Davranış:

- title inline autosave
- description autosave (debounce)
- `Kaydet` butonu kaldırılır
- kolon seçimi dropdown/menu
- attachments ve reminders collapsible bölümler
- delete overflow içinde

Kart detayı açıldığında context kaybı minimum olmalıdır.

## 6.7 Hatırlatıcılar

### Hedef

- üstte compact permission durumu
- Yaklaşan / Geçmiş / Devre dışı filtreleri daha hafif segmented/tab yapısı
- yaklaşanlar tarih gruplarıyla: Bugün, Yarın, Bu hafta, Daha sonra
- satırda saat daha baskın, teknik scheduling status daha düşük öncelikli
- exact/inexact bilgisi normal kullanımda teknik terim yerine kullanıcı diliyle
- permission banner sürekli büyük kırmızı kutu olmamalı; kritik değilse compact warning row

## 6.8 Arama

### Desktop

`⌘/Ctrl + K` gerçek command palette açar.

Palette:

- 600–680 dp
- floating surface
- search input
- son kullanılanlar / sonuçlar
- keyboard selection
- Enter açar
- Esc kapatır

Tam Arama ekranı ayrıca nav/More üzerinden açılabilir.

Sonuçlarda:

- type icon
- title
- match highlight
- breadcrumb / pano-kolon bilgisi
- kısa preview

### Mobile

- tam ekran search route
- büyük input
- type filter chips gerektiğinde

## 6.9 Ayarlar

Desktop'ta uzun tek sayfa kart yığını kaldırılmalı.

Hedef:

```text
Ayarlar
┌────────────────┬──────────────────────────────┐
│ Görünüm        │ seçili ayar içeriği          │
│ Bildirimler    │                              │
│ Senkronizasyon │                              │
│ Depolama       │                              │
│ Hakkında       │                              │
└────────────────┴──────────────────────────────┘
```

Mobile:

- ayar kategori listesi
- nested detail pages

Teknik kavramlar yalnız gerektiğinde “Gelişmiş / Tanılama” altında gösterilmeli.

## 6.10 Çatışma / sync queue / tanılama ekranları

Bu ekranlar günlük ürün yüzeyi değildir.

- Settings > Senkronizasyon > Gelişmiş altında gruplanmalı
- teknik ID ve payload bilgisi birincil UI'da görünmemeli
- normal kullanıcı dili üstte, teknik ayrıntı expandable altta

---

# 7. Ortak bileşen planı

Revizyon ekran ekran kopyala-yapıştır yapılmamalıdır. Önce aşağıdaki UI primitives oluşturulmalıdır.

## P0 ortak bileşenler

- `AppToolbar`
- `AppSidebarItem`
- `AppIconButton`
- `AppMenuButton`
- `AppSearchField`
- `AppListRow`
- `AppSectionHeader`
- `AppStatusChip`
- `AppBanner` (`info`, `warning`, `error`)
- `AppSheet` responsive wrapper
- `AppPopover`
- `AppContextMenu`
- `AppEntityColorIndicator`
- `AppEmptyState`

## Editor primitives

- `EditorBlockGutter`
- `EditorFloatingToolbar`
- `EditorCommandPalette`
- `EditorSaveStatus`

## Kanban primitives

- `BoardColumnSurface`
- `KanbanCardSurface`
- `KanbanInsertionIndicator`
- `KanbanQuickMoveControls`

Bu primitives mevcut `common_widgets.dart` içinde tek dev dosyaya yığılmamalı; presentation/core UI altında küçük ve amaç odaklı dosyalara ayrılmalıdır.

---

# 8. Responsive kurallar

## Compact `< 600`

- full-screen detail routes
- bottom navigation
- bottom sheets
- FAB yalnız listelerde ana create eylemi için
- toolbar action sayısı maksimum 2 görünür + overflow
- Kanban kolon ~86vw

## Medium `600–1023`

- NavigationRail
- mümkün olduğunda 2-pane
- side sheet 360–400
- Kanban kolon 280–300

## Expanded `>= 1024`

- compact sidebar
- master-detail / side sheet
- command palette
- hover states
- keyboard shortcuts
- daha yoğun list rows

Breakpoint tek başına karar vermemeli; pencere yüksekliği ve input türü de dikkate alınmalıdır.

---

# 9. Erişilebilirlik ve input standardı

Revizyon tamamlanmış sayılmaz unless:

- tüm temel işlemler keyboard ile yapılabilir,
- focus state görünür,
- hit target en az 44x44,
- renk tek başına anlam taşımaz,
- metin/background kontrastı WCAG AA seviyesini karşılar,
- tooltip desktop icon button'larında vardır,
- destructive işlem semantik olarak belirtilir,
- screen reader sırası görsel sırayla uyumludur,
- drag işleminin menü/ok alternatifi vardır,
- reduced motion tercihine uyulur,
- text scale yükseldiğinde toolbar/listeler taşmaz.

---

# 10. UX copy standardı

Metinler kısa, doğal ve teknik olmayan Türkçe kullanmalıdır.

Örnek dönüşümler:

- `Senkronize` → `Güncel`
- `Kuyrukta 3 işlem` → normal UI'da `3 değişiklik bekliyor`
- `Exact Alarm izni` → normal UI'da `Tam zamanlı bildirim izni`
- `Inexact fallback` → normal UI'da `Yaklaşık zamanda bildirilecek`

Teknik terimler yalnız tanılama ekranında parantezsiz şekilde kullanılabilir.

Sayfa subtitle'ları çoğu ekrandan kaldırılacak; empty state veya onboarding açıklamaları ihtiyaç duyulan bağlamı verecektir.

---

# 11. Uygulama fazları

## Faz 0 — UX baseline ve regression sınırı

Amaç: Tasarım değişirken mevcut işlevlerin kaybolmamasını sağlamak.

Yapılacaklar:

- ana ekranların compact / medium / expanded screenshot baseline'larını oluştur
- mevcut keyboard shortcut listesi çıkar
- note editor ve Kanban temel etkileşimlerini smoke senaryosu olarak sabitle
- mevcut responsive overflow noktalarını kaydet

Çıktı:

- görsel karşılaştırma için temel
- revizyon sırasında korunması gereken interaction contract

## Faz 1 — Design tokens ve primitives

Öncelik: **P0**

Dosya odakları:

- `lib/app/theme/app_theme.dart`
- `lib/app/widgets/`

Yapılacaklar:

- platform-aware typography
- surface/border/accent token ayrımı
- control density
- toolbar, list row, banner, sheet, popover, entity color indicator
- hover/focus/pressed state standardı
- hard-coded `Colors.green/orange/red` kullanımını semantic tokenlara taşı

Kabul kriteri:

- yeni primitive'lerde doğrudan rastgele radius/color/padding yok
- light/dark aynı hiyerarşiyi koruyor

## Faz 2 — App shell ve global navigation

Öncelik: **P0**

Dosya odakları:

- `lib/app/app_shell.dart`
- `lib/app/router/`
- global search trigger

Yapılacaklar:

- sade expanded sidebar
- Ayarlar alt bölüme
- search affordance
- compact More sadeleştirme
- global toolbar standardı
- `⌘/Ctrl + K`, settings ve create shortcut contract

Kabul kriteri:

- 3 breakpoint'te navigation stabil
- keyboard focus kaybolmuyor
- content area gereksiz nested SafeArea/padding üretmiyor

## Faz 3 — Notes list + editor

Öncelik: **P0**

Dosya odakları:

- `lib/features/notes/presentation/screens/notes_screen.dart`
- `lib/features/notes/presentation/screens/note_editor_screen.dart`
- `lib/features/notes/presentation/widgets/`

Yapılacaklar:

- notes toolbar/filter/list yeniden tasarımı
- renkleri küçük indicator'a indirgeme
- editor AppBar sadeleştirme
- manuel save action kaldırma
- block gutter
- overlay slash palette
- anchored selection toolbar
- reminder/attachment secondary surface akışı
- trash + undo
- expanded master-detail hazırlığı

Kabul kriteri:

- not yazarken kullanıcı ana gövde dışında görsel gürültü hissetmiyor
- autosave durumu var ama dikkat dağıtmıyor
- outside tap focus-dismiss korunuyor
- slash/formatting klavye davranışları bozulmuyor

## Faz 4 — Boards + Kanban + card detail

Öncelik: **P0**

Dosya odakları:

- `lib/features/kanban/presentation/screens/boards_screen.dart`
- `lib/features/kanban/presentation/screens/kanban_board_screen.dart`
- `lib/features/kanban/presentation/screens/card_detail_screen.dart`
- `lib/features/kanban/presentation/widgets/`

Yapılacaklar:

- pano kartı sadeleştirme
- kolonları Card görünümünden workspace görünümüne taşıma
- renk tintlerini azaltma
- insertion line drag feedback
- kolonlar arası drag contract'ı koruma
- akıllı sağ/sol taşıma kontrolleri
- desktop card detail side sheet
- card autosave

Kabul kriteri:

- aynı kolon sıralama ve kolonlar arası taşıma çalışır
- ilk/son kolonda geçersiz yön oku görünmez
- drag dışında erişilebilir taşıma alternatifi vardır
- desktop'ta kart detayı açıldığında pano bağlamı korunur

## Faz 5 — Home + Search + Reminders + Settings

Öncelik: **P1**

Yapılacaklar:

- Home quick capture
- dashboard card katmanlarını azaltma
- desktop command palette
- search result highlight/breadcrumb
- reminder date grouping
- permission banners sadeleştirme
- settings split-view
- teknik sync ekranlarını Advanced altında toplama

Kabul kriteri:

- günlük ana akışlar 1–2 tıklamada erişilebilir
- settings günlük ürün navigasyonunu şişirmiyor

## Faz 6 — Responsive polish + accessibility + visual QA

Öncelik: **P1**

Yapılacaklar:

- compact/medium/expanded overflow audit
- large text audit
- screen reader semantics
- keyboard-only pass
- hover/focus pass
- dark mode pass
- reduced motion
- screenshot/golden regression

Kabul kriteri:

- kritik ekranda overflow yok
- dark/light hierarchy eşdeğer
- mouse olmadan desktop kullanılabiliyor
- drag olmadan Kanban temel işlemleri yapılabiliyor

---

# 12. Öncelik matrisi

## P0 — Ürün hissini doğrudan değiştirir

1. Theme/token ve platform typography revizyonu
2. Global sidebar + toolbar revizyonu
3. Not editörü sadeleştirme
4. Notes list yoğunluk/hiyerarşi revizyonu
5. Kanban kolon/kart görsel sistemi
6. Kart detayını autosave + desktop side sheet'e taşıma
7. Ortak dialog/undo/destructive davranış standardı

## P1 — Deneyimi tamamlar

1. Home quick capture ve dashboard yerleşimi
2. Gerçek desktop command palette
3. Reminder grouping ve permission UX
4. Settings split-view
5. Entity renk kullanımını tüm ekranda normalize etme
6. Responsive + accessibility polish

## P2 — Sonraki ürün zenginleştirmeleri

Bunlar revizyonun tamamlanması için zorunlu değildir:

- pano şablon seçimi
- grid/list görünüm tercihini kalıcı saklama
- gelişmiş quick actions
- daha zengin editor block tipleri
- özel emoji/icon picker
- gelişmiş motion/microinteraction

---

# 13. Tasarım dışı kapsam sınırı

Bu UX revizyonu sırasında aşağıdakiler “tasarımı tamamlamak” gerekçesiyle sessizce eklenmemelidir:

- collaborative/multi-user özellikler
- assignee/avatar sistemi
- yeni sync protokolü
- backend zorunlu arama
- yeni veri modeli gerektiren etiket sistemi (mevcut altyapı yoksa ayrı ürün kararı gerekir)
- AI özellikleri
- calendar görünümü
- web uygulaması

Amaç mevcut ürün kapsamını daha iyi sunmaktır; scope creep yaratmak değildir.

---

# 14. Kod organizasyonu hedefi

UX revizyonu sonunda presentation katmanı şu prensibe yaklaşmalıdır:

```text
lib/
  app/
    theme/
      app_theme.dart
      app_colors.dart
      app_typography.dart
      app_spacing.dart
    widgets/
      toolbar/
      navigation/
      feedback/
      inputs/
      overlays/
  features/
    notes/
      presentation/
        screens/
        widgets/
    kanban/
      presentation/
        screens/
        widgets/
```

Bu bir zorunlu fiziksel migration değildir; fakat ortak UX primitives feature ekranlarının içinde tekrarlanmamalıdır.

---

# 15. Definition of Done — UX revizyonu

Revizyon tamamlanmış kabul edilmesi için:

- [ ] Ana ekranlar aynı görsel dilde
- [ ] Material default görünüm hissi belirgin biçimde azaltılmış
- [ ] Ana yüzeylerde gereksiz Card/border katmanları kaldırılmış
- [ ] Entity renkleri accent seviyesine çekilmiş
- [ ] Desktop navigation daha kompakt
- [ ] Sayfa subtitle'ları yalnız gerekli yerde
- [ ] Not editörü manuel save gerektirmiyor
- [ ] Kart detayı autosave kullanıyor
- [ ] Desktop kart detayı pano bağlamını koruyor
- [ ] Kanban drag + doğrudan taşıma birlikte çalışıyor
- [ ] İlk/son kolonda geçersiz yön aksiyonu görünmüyor
- [ ] Global search `⌘/Ctrl + K` ile hızlı açılıyor
- [ ] Basit veri girişlerinde dialog kullanımı azaltılmış
- [ ] Destructive işlemler tutarlı undo/confirmation modeline sahip
- [ ] Light/dark tema eşdeğer kaliteye sahip
- [ ] Compact/medium/expanded overflow audit temiz
- [ ] Keyboard-only kullanım temel akışlarda mümkün
- [ ] Touch target, contrast ve semantics erişilebilirlik kontrolünden geçmiş
- [ ] Mevcut offline-first ve sync davranışları UX revizyonu nedeniyle bozulmamış

---

# 16. Önerilen uygulama sırası

En güvenli sıra:

```text
Design tokens
→ UI primitives
→ App shell
→ Notes list
→ Note editor
→ Boards
→ Kanban
→ Card detail
→ Home
→ Search
→ Reminders
→ Settings
→ Accessibility / responsive / visual QA
```

Not editörü ile Kanban erken ele alınmalıdır; ürünün gerçek kalite algısını en çok bu iki çalışma alanı belirler.

---

## Son karar

Mevcut `UX_DESIGN.md` doğru bir ürün vizyonu tanımlıyor ancak uygulanmış UI bu vizyona henüz tam yaklaşmıyor. Revizyon sırasında yeni bir gösterişli tema üretmek yerine mevcut Calm Paper yaklaşımı daha disiplinli, daha az dekoratif ve daha platform-native bir **Quiet Workspace** diline dönüştürülmelidir.

Başarı ölçütü “daha fazla tasarım öğesi” değildir. Kullanıcı uygulamayı açtığında daha az arayüz görmeli, notunu/panosunu daha hızlı görmeli ve daha az karar vererek işine devam edebilmelidir.
