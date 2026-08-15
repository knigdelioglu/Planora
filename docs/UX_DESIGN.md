# Not — UX / UI Tasarım Spesifikasyonu

> Durum: Ürün geliştirme için bağlayıcı tasarım referansı  
> Kapsam: iOS, Android ve macOS Flutter istemcisi  
> Ürün modeli: Tek kullanıcı, offline-first, kişisel not + Kanban çalışma alanı

Bu belge, `Not` uygulamasının ekranlarını, navigasyonunu, görsel sistemini, bileşenlerini, buton davranışlarını, boş/yükleme/hata durumlarını, responsive kurallarını ve temel etkileşimlerini tanımlar. Uygulama geliştirilirken UI/UX kararları için birincil referans olarak kullanılmalıdır.

---

## 1. Tasarım vizyonu

`Not`, Notion benzeri içerik esnekliğini görev yönetimi ve çevrimdışı kullanım güvenilirliği ile birleştiren kişisel bir çalışma alanıdır.

Tasarımın ana karakteri:

- sakin,
- içerik-öncelikli,
- yoğun bilgi gösterebilen fakat kalabalık hissettirmeyen,
- hızlı klavye ve dokunmatik kullanıma uygun,
- offline durumda dahi güven veren,
- sürekli modal açtırmayan,
- düşük görsel gürültülü,
- masaüstünde üretkenlik, mobilde hızlı yakalama odaklı.

### 1.1 Tasarım ilkeleri

1. **İçerik arayüzden önemlidir.** Çerçeve, kart ve gölge yalnızca hiyerarşi gerektiğinde kullanılır.
2. **Offline durum hata değildir.** Kullanıcı çevrimdışıyken uygulama normal çalışır; yalnızca senkronizasyon durumu değişir.
3. **Birincil eylem her ekranda açıktır.** Aynı ekranda birden fazla güçlü CTA kullanılmaz.
4. **Kaydet butonu varsayılan değildir.** Not, kart ve ayar değişiklikları mümkün olduğunda otomatik yerel kaydedilir.
5. **Silme gibi yıkıcı işlemler geri alınabilir olmalıdır.** Snackbar + Undo tercih edilir.
6. **Detaylar bağlamı bozmadan açılır.** Masaüstünde side sheet/right panel, mobilde tam ekran veya bottom sheet kullanılır.
7. **Durum görünür, teknik detay gizlidir.** “Kaydedildi”, “Senkronizasyon bekliyor” gibi kullanıcı dili kullanılır; queue ID gibi teknik kavramlar yalnız tanılama ekranında görünür.

---

## 2. Bilgi mimarisi

Ana ürün alanları:

```text
Ana Sayfa
├── Hızlı Yakalama
├── Son Notlar
├── Yaklaşan Hatırlatıcılar
└── Son Panolar

Notlar
├── Tüm Notlar
├── Favoriler
├── Son Kullanılanlar
├── Çöp Kutusu
└── Not Düzenleyici

Panolar
├── Pano Listesi
├── Kanban Pano
└── Kart Detayı

Hatırlatıcılar
├── Yaklaşan
├── Geçmiş
└── Hatırlatıcı Düzenleyici

Arama
└── Birleşik sonuçlar: Notlar + Kartlar + Panolar

Ayarlar
├── Görünüm
├── Bildirimler
├── Senkronizasyon
├── Depolama
└── Hakkında / Tanılama
```

### 2.1 Top-level navigasyon

Top-level öğeler:

1. Ana Sayfa
2. Notlar
3. Panolar
4. Hatırlatıcılar
5. Arama
6. Ayarlar

`Ekler` bağımsız ana navigasyon öğesi değildir. Ekler not veya kart bağlamında yönetilir; genel depolama görünümü `Ayarlar > Depolama` altında bulunur.

---

## 3. Responsive kabuk

### 3.1 Breakpoint'ler

| Sınıf | Genişlik | Kullanım |
| --- | ---: | --- |
| Compact | `< 600 dp` | Telefon |
| Medium | `600–1023 dp` | Tablet / dar pencere |
| Expanded | `>= 1024 dp` | macOS / geniş tablet |

### 3.2 Compact — telefon

- Alt navigation bar: 5 öğe maksimum.
- `Ana`, `Notlar`, `Panolar`, `Hatırlatıcılar`, `Daha`.
- `Daha` içinde Arama ve Ayarlar.
- Ekran başlıkları standart app bar.
- Detaylar çoğunlukla tam ekran route.
- FAB yalnız gerçekten güçlü “yeni” eylemi gereken listelerde kullanılır.

Alt navigasyon yüksekliği: `64 dp` + safe area.

### 3.3 Medium — tablet

- Sol NavigationRail: `72 dp`.
- İçerik 1 veya 2 sütuna bölünebilir.
- Not listesi + not önizleme, pano + kart side sheet mümkün.

### 3.4 Expanded — macOS / desktop

Sol sidebar varsayılan genişlik: `248 dp`.

Daraltılmış sidebar: `64 dp`.

Ana düzen:

```text
┌──────────────┬───────────────────────────────────────┐
│ Sidebar      │ Toolbar                               │
│              ├───────────────────────────────────────┤
│ Ana          │                                       │
│ Notlar       │ Main content                          │
│ Panolar      │                                       │
│ Hatırlatıcı  │                                       │
│ Arama        │                                       │
│              │                                       │
│ Ayarlar      │                                       │
└──────────────┴───────────────────────────────────────┘
```

Kart veya ikincil detay açıldığında:

```text
┌──────────┬──────────────────────────┬─────────────────┐
│ Sidebar  │ Main content             │ Detail panel    │
│ 248      │ flexible                 │ 380–440         │
└──────────┴──────────────────────────┴─────────────────┘
```

---

## 4. Görsel tasarım sistemi

## 4.1 Renk yaklaşımı

Tema adı: **Calm Paper**.

Amaç; beyaz/sıcak nötr yüzeyler, yüksek okunabilirlik ve yalnız seçili/etkileşimli öğelerde belirgin vurgu kullanmaktır.

### Light theme

| Token | Hex | Kullanım |
| --- | --- | --- |
| `bg.canvas` | `#F7F7F5` | Uygulama genel zemini |
| `bg.surface` | `#FFFFFF` | Panel, kart, editor |
| `bg.subtle` | `#F1F1EF` | Hover, secondary alan |
| `bg.selected` | `#E9E8FF` | Seçili nav/list item |
| `text.primary` | `#242424` | Ana metin |
| `text.secondary` | `#686868` | Yardımcı metin |
| `text.tertiary` | `#929292` | Placeholder / metadata |
| `border.default` | `#E2E2DE` | Divider / border |
| `accent.primary` | `#5B57D9` | Ana vurgu |
| `accent.hover` | `#4B47C6` | Primary hover |
| `accent.soft` | `#EFEEFF` | Tonal vurgu |
| `success` | `#2F7D4A` | Başarı / synced |
| `warning` | `#A76600` | Bekleyen sync / uyarı |
| `danger` | `#C73E3A` | Yıkıcı eylem |
| `info` | `#2D6FB7` | Bilgilendirme |

### Dark theme

| Token | Hex |
| --- | --- |
| `bg.canvas` | `#191919` |
| `bg.surface` | `#222222` |
| `bg.subtle` | `#2C2C2C` |
| `bg.selected` | `#34305D` |
| `text.primary` | `#F2F2F0` |
| `text.secondary` | `#B8B8B3` |
| `text.tertiary` | `#858580` |
| `border.default` | `#383836` |
| `accent.primary` | `#918DFF` |
| `accent.hover` | `#A6A3FF` |
| `accent.soft` | `#302E52` |
| `success` | `#66B783` |
| `warning` | `#D9A14A` |
| `danger` | `#EF7772` |
| `info` | `#72A9DE` |

### Renk kullanım kuralları

- Vurgu rengi dekorasyon amacıyla geniş alanlara yayılmaz.
- Bir ekranda birincil CTA dışında güçlü mor vurgu minimumda tutulur.
- Durum renkleri tek başına anlam taşımaz; ikon/metin ile desteklenir.
- Kanban kolonlarının rengini kullanıcı seçebilir; kolon başlığı arka planı yerine küçük renk noktası veya sol çizgi tercih edilir.

---

## 4.2 Tipografi

Platformlar arası tutarlılık için varsayılan tercih: **Inter**. Inter bundle edilmezse Apple platformlarında SF Pro, Android'de Roboto sistem fallback'i kullanılabilir.

| Stil | Boyut | Weight | Line height | Kullanım |
| --- | ---: | ---: | ---: | --- |
| Display | 32 | 700 | 40 | Boş durum / onboarding başlık |
| H1 | 28 | 700 | 36 | Not başlığı |
| H2 | 22 | 650 | 30 | Ekran başlığı |
| H3 | 18 | 600 | 26 | Bölüm başlığı |
| Body L | 16 | 400 | 25 | Editör gövde |
| Body M | 14 | 400 | 21 | Normal UI metni |
| Label | 13 | 600 | 18 | Buton / filter |
| Caption | 12 | 400 | 17 | Metadata |
| Mono | 13 | 400 | 20 | Kod blokları |

Not editor ana gövde genişliği masaüstünde maksimum `760 dp` tutulur.

---

## 4.3 Spacing sistemi

Temel grid: `4 dp`.

Tokenlar:

- `xs = 4`
- `sm = 8`
- `md = 12`
- `lg = 16`
- `xl = 24`
- `2xl = 32`
- `3xl = 48`

Ana ekran yatay padding:

- telefon: `16 dp`
- tablet: `24 dp`
- desktop: `32 dp`

---

## 4.4 Radius ve gölge

| Bileşen | Radius |
| --- | ---: |
| Button | 8 dp |
| Input | 8 dp |
| Small card | 10 dp |
| Kanban card | 10 dp |
| Dialog / sheet | 14 dp |
| Floating palette | 12 dp |

Gölge yalnız floating öğelerde kullanılır.

- normal kart: border, gölge yok
- hover kart: çok hafif elevation
- popover/dialog: elevation 8 eşdeğeri

---

## 4.5 İkonografi

Material Symbols Rounded veya platformlar arası eşdeğer sade çizgi ikon seti.

Standart ikon boyutları:

- inline: `16 dp`
- normal: `20 dp`
- toolbar: `22 dp`
- büyük boş durum: `40–48 dp`

İkon buton hit target minimum `44x44 dp`, Android için tercihen `48x48 dp`.

---

# 5. Ana bileşenler

## 5.1 Primary Button

Kullanım: Ekranın ana ve net CTA'sı.

Örnek: `Yeni pano oluştur`, `İzni aç`, `Bulut senkronizasyonunu bağla`.

- yükseklik: 40 dp desktop / 44 dp mobile
- yatay padding: 16 dp
- radius: 8 dp
- background: `accent.primary`
- text: white/light equivalent
- icon opsiyonel, solda 18–20 dp

Durumlar:

- default
- hover
- pressed
- focused
- loading: spinner + label korunur
- disabled: düşük kontrast, tooltip ile gerekçe gerekiyorsa açıklanır

Bir dialog içinde en fazla bir primary button.

## 5.2 Secondary Button

- surface veya transparent background
- 1 dp border yalnız gerektiğinde
- normal metin `text.primary`
- hover `bg.subtle`

Örnek: `Vazgeç`, `Dışa aktar`, `Dosya seç`.

## 5.3 Tonal Button

Sık kullanılan fakat primary olmayan eylemler.

Örnek: `Hatırlatıcı ekle`, `Ek ekle`.

Background `accent.soft`, foreground `accent.primary`.

## 5.4 Ghost / Toolbar Button

- background transparent
- hover `bg.subtle`
- ikon veya kısa label

Örnek: filtre, sıralama, görünüm modu.

## 5.5 Danger Button

Yalnız geri dönüşü zor veya açıkça yıkıcı işlemde.

Örnek: `Çöp kutusunu boşalt`, `Bulut verisini sıfırla`.

Normal listeden öğe silmede doğrudan danger primary yerine menü + confirmation veya snackbar undo kullanılır.

## 5.6 Icon Button

- görsel alan 32–36 dp
- hit target 44–48 dp
- tooltip desktop'ta zorunlu

## 5.7 Floating Action Button

Sadece compact listelerde:

- Notlar: `+ Yeni not`
- Panolar: `+ Yeni pano`
- Hatırlatıcılar: `+ Hatırlatıcı`

Desktop'ta FAB kullanılmaz; toolbar/button kullanılır.

## 5.8 Text Field

Standart yükseklik: 40–44 dp.

State:

- default
- hover
- focus: 2 dp accent outline
- error: danger outline + açıklama
- disabled

Placeholder kullanıcıya örnek verir fakat label yerine kullanılmaz.

## 5.9 Search Field

Global search:

- masaüstünde maksimum 560 dp
- `⌘K / Ctrl+K` ile açılır
- leading search icon
- clear button yalnız metin varsa
- sonuçlar yazdıkça filtrelenir

## 5.10 Checkbox

Görev listesi ve seçim eylemlerinde kullanılır.

- 20 dp visual
- 44 dp hit target
- completed metin opacity düşer ama kontrast erişilebilir kalır

## 5.11 Segmented Control

Az sayıda eş seviyeli görünüm seçeneğinde.

Örnek: `Liste | Kartlar`, `Yaklaşan | Geçmiş`.

## 5.12 Chip

Kullanım:

- etiket,
- filter,
- sync state,
- dosya tipi.

Yükseklik: 28–32 dp.

## 5.13 Context Menu

Desktop: sağ tık veya `...`.
Mobile: `...` veya long press.

Sıra:

1. temel eylemler
2. organize etme
3. duplicate/export
4. divider
5. delete

## 5.14 Snackbar

Alt bölgede, navigation bar'ın üzerinde.

Süre:

- bilgi: 3–4 sn
- undo: 6 sn

Örnek: `Not çöp kutusuna taşındı — Geri al`.

## 5.15 Dialog

Yalnız karar gerektiren durumlarda.

Kullanılacak durumlar:

- kalıcı veri silme,
- sync hesabını kaldırma,
- cache temizleme seçenekleri,
- kritik izin açıklaması.

Basit veri girişinde dialog yerine sheet/panel tercih edilir.

## 5.16 Bottom Sheet / Side Sheet

Aynı işlev farklı form faktöründe:

- mobile: modal bottom sheet veya full screen sheet
- desktop/tablet: sağ side sheet

Örnek: Kart ayrıntısı, hatırlatıcı düzenleme, dosya ekleme seçenekleri.

---

# 6. Global uygulama kabuğu

## 6.1 Sidebar — desktop

Üst bölüm:

- uygulama logosu/işareti: `N`
- ürün adı: `Not`
- sidebar daralt butonu

Navigasyon öğeleri:

- Ana Sayfa
- Notlar
- Panolar
- Hatırlatıcılar
- Arama

Alt bölüm:

- Senkronizasyon durumu
- Ayarlar

Navigation item:

- yükseklik 40 dp
- radius 8 dp
- icon 20 dp
- label 14 dp
- seçili: `bg.selected`
- hover: `bg.subtle`

Sync status örnekleri:

- `✓ Güncel`
- `↻ 3 değişiklik bekliyor`
- `○ Çevrimdışı`
- `! Eşitleme sorunu`

Bu status sidebar'ın alt bölümünde küçük ve düşük baskınlıkta gösterilir.

## 6.2 Global toolbar

Desktop yüksekliği: `56 dp`.

Sol:

- breadcrumb veya ekran başlığı

Sağ:

- görünüm özel eylemleri
- `...` menüsü

Toolbar her zaman dolu olmak zorunda değildir.

## 6.3 Keyboard shortcuts

Desktop:

- `⌘/Ctrl + K`: Global arama
- `⌘/Ctrl + N`: Aktif bağlama göre yeni not/kart
- `⌘/Ctrl + Shift + N`: Yeni not
- `⌘/Ctrl + ,`: Ayarlar
- `⌘/Ctrl + Z`: Undo
- `Esc`: açık popover/sheet kapat
- `/`: editor command menu

Shortcut'lar tooltip veya menülerde görünür.

---

# 7. Ekran: İlk Açılış / Onboarding

Amaç: Kullanıcıyı gereksiz hesap oluşturma akışına sokmadan uygulamayı çalışır hale getirmek.

Tek kullanıcı ve offline-first olduğu için onboarding maksimum 2 adımdır.

## 7.1 Ekran A — Hoş geldiniz

Yerleşim:

```text
            [N logo]

       Notlarını düzenle.
      İşlerini takip et.
       Çevrimdışı da.

  Verilerin önce bu cihazda tutulur.

       [Başlayalım]

       Daha fazla bilgi
```

Primary: `Başlayalım`

Secondary text button: `Daha fazla bilgi`

Bulut hesabı zorunlu değildir.

## 7.2 Ekran B — Bildirim izni

İzin istemeden önce pre-permission ekranı:

Başlık: `Hatırlatıcıları kaçırma`

Açıklama: cihaz üzerinde çalışan hatırlatıcıların neden izne ihtiyaç duyduğu.

Butonlar:

- Primary: `Bildirimlere izin ver`
- Secondary: `Şimdilik değil`

Sistem permission dialog'u ancak primary sonrası açılır.

Onboarding bitince Ana Sayfa.

---

# 8. Ekran: Ana Sayfa

Amaç: Kullanıcının uygulamayı açtığında “şimdi ne var?” sorusunu yanıtlamak.

## 8.1 Desktop düzen

```text
Ana Sayfa                              [Hızlı not +]

Günaydın

┌─────────────────────────────┐  ┌─────────────────────┐
│ Hızlı yakalama              │  │ Bugün               │
│ Bir şey yaz...              │  │ 10:30 Toplantı      │
└─────────────────────────────┘  │ 18:00 Kitap          │
                                 └─────────────────────┘

Son notlar
[Not card] [Not card] [Not card]

Panolar
[Pano preview] [Pano preview]
```

## 8.2 Hızlı yakalama

Tek satırlı minimal giriş.

Placeholder: `Bir fikir, görev veya not yaz...`

Enter:

- yeni not oluşturur,
- metni ilk paragraf yapar,
- snackbar: `Not oluşturuldu`.

Shift+Enter: satır kırma.

Sağ küçük ikonlar:

- hatırlatıcı ekle
- panoya kart olarak ekle

## 8.3 Bugün paneli

Yaklaşan 3–5 hatırlatıcı.

Her satır:

- saat
- başlık
- ilişkili not/kart ikonu

`Tümünü gör` text button.

## 8.4 Son not kartı

- maksimum 3 satır başlık/önizleme
- güncellenme zamanı
- favori yıldızı yalnız hover'da veya seçiliyse görünür
- tek tıklama açar

## 8.5 Boş Ana Sayfa

Yeni kullanıcıda kalabalık placeholder card yok.

Göster:

- kısa mesaj
- `İlk notunu oluştur`
- `İlk panonu oluştur`

---

# 9. Ekran: Notlar Listesi

## 9.1 Toolbar

Başlık: `Notlar`

Sağ:

- `Yeni not` primary/tonal button
- filter icon
- sort icon
- view toggle: Liste / Grid

Mobile: `+` FAB ve overflow toolbar.

## 9.2 Sol filtre alanı — expanded

Opsiyonel dar ikinci sidebar:

- Tüm Notlar
- Favoriler
- Son Kullanılanlar
- Çöp Kutusu

Medium/compact'ta filtre dropdown/sheet olur.

## 9.3 Liste görünümü

Satır yüksekliği: 64–72 dp.

Kolonlar:

- başlık + küçük body preview
- etiketler
- güncellenme zamanı
- reminder icon varsa
- attachment icon + count varsa
- overflow

Hover:

- hafif arka plan
- action icons görünür

## 9.4 Grid görünümü

Kart minimum genişlik: 220 dp.

İçerik:

- title
- 3–5 satır preview
- tag row
- footer metadata

## 9.5 Seçim modu

Desktop: checkbox hover ile görünür.
Mobile: long press ile selection mode.

Top action bar:

- `Favoriye ekle`
- `Taşı`
- `Dışa aktar`
- `Çöpe taşı`

## 9.6 Empty state

Başlık: `Henüz not yok`

Açıklama: `Fikirlerini, listelerini ve belgelerini burada tutabilirsin.`

CTA: `Yeni not oluştur`

---

# 10. Ekran: Not Düzenleyici

Bu uygulamanın en önemli ekranıdır.

## 10.1 Desktop yerleşim

```text
Breadcrumb                         [☆] [↻ Güncel] [...]
──────────────────────────────────────────────────────

                 Emoji / icon

                 Not başlığı

                 Gövde içerik...
                 Gövde içerik...
                 / komut menüsü

                 + Blok ekle
```

Editor content max-width: `760 dp`.

Üst ve alt boşluk geniş tutulur.

## 10.2 Başlık

- border yok
- H1 28/36
- placeholder: `Başlıksız`
- otomatik kaydedilir

## 10.3 Editor blokları

İlk ürün sürümü için tasarım desteği:

- paragraph
- heading 1/2/3
- bullet list
- numbered list
- checklist
- quote
- divider
- code block
- image
- file attachment
- callout

Her blok hover'da sol gutter'da:

- `+` insert
- drag handle `⋮⋮`

Mobile'da handle seçili blokta görünür.

## 10.4 Slash command

`/` yazılınca command palette:

- Temel
  - Metin
  - Başlık 1
  - Başlık 2
  - Başlık 3
- Listeler
  - Madde işaretli
  - Numaralı
  - Yapılacak
- Medya
  - Görsel
  - Dosya
- Diğer
  - Alıntı
  - Kod
  - Ayraç

Arama destekli.

## 10.5 Selection toolbar

Metin seçildiğinde floating toolbar:

- B
- I
- U (isteğe bağlı)
- code
- link
- highlight
- text color

Mobile'da sistem selection ile çakışmayacak şekilde sadeleştirilir.

## 10.6 Editor üst aksiyonları

- Favori yıldızı
- Sync status
- `...`

Overflow:

- Hatırlatıcı ekle
- Dosya ekle
- Panoya kart oluştur
- Dışa aktar
- Kopyasını oluştur
- Çöp kutusuna taşı

## 10.7 Autosave durumu

UI teknik save butonu göstermez.

Durumlar:

- `Kaydediliyor…`
- `Bu cihazda kaydedildi`
- `Senkronizasyon bekliyor`
- `Güncel`
- `Eşitleme sorunu`

Yerel kaydetme başarılı, internet yoksa kullanıcıya hata rengi gösterilmez; `Bu cihazda kaydedildi · Çevrimdışı` denir.

## 10.8 Attachment block

### Dosya

```text
[PDF icon] dosya-adi.pdf
           2.4 MB · Bu cihazda
                         [⋯]
```

Durumlar:

- yerelde mevcut
- yükleniyor `%`
- bulutta mevcut
- indirme gerekli
- sync hatası
- dosya bulunamadı

### Görsel

- editor genişliğine fit
- radius 8
- click/tap: viewer
- caption alanı

## 10.9 Not silme

`Çöp kutusuna taşı` anında uygulanır.

Snackbar: `Not çöp kutusuna taşındı — Geri al`.

Kalıcı silme sadece Çöp Kutusu ekranından.

---

# 11. Ekran: Pano Listesi

## 11.1 Header

Başlık: `Panolar`

Primary: `Yeni pano`

View:

- grid default
- compact list opsiyonel

## 11.2 Pano kartı

Boyut: yaklaşık `280x150 dp` desktop.

İçerik:

- ikon / renk noktası
- pano adı
- `4 kolon · 18 kart`
- son güncelleme
- üç küçük kolon preview çizgisi

Overflow:

- Yeniden adlandır
- Kopyala
- Dışa aktar
- Sil

## 11.3 Yeni Pano sheet/dialog

Alanlar:

- Pano adı
- İkon/emoji
- Renk
- Başlangıç şablonu

Şablonlar:

- Boş
- Yapılacak / Yapılıyor / Tamamlandı
- Fikir / İnceleniyor / Planlandı / Bitti

Primary: `Oluştur`

Secondary: `Vazgeç`

---

# 12. Ekran: Kanban Pano

## 12.1 Toolbar

Sol:

- breadcrumb `Panolar / Proje X`
- pano adı

Sağ:

- `+ Kart ekle`
- Filter
- Sort
- Pano menüsü `...`

Pano adı inline rename destekler.

## 12.2 Pano alanı

Yatay scroll.

Kolon genişliği:

- desktop: 300 dp
- tablet: 280 dp
- mobile: viewport'un yaklaşık %86'sı

Kolonlar ekranın üstünden altına uzanır.

## 12.3 Kolon header

```text
● İnceleniyor   4                    [...]
```

- renk noktası 8 dp
- başlık
- kart sayısı
- overflow

Overflow:

- Yeniden adlandır
- Renk değiştir
- Tüm kartları taşı
- Kolonu sil

Alt:

`+ Kart ekle`

## 12.4 Kanban kartı

Minimum yükseklik: 72 dp.

Padding: 12 dp.

İçerik hiyerarşisi:

1. title
2. optional 1–2 satır description preview
3. tags
4. footer

Footer:

- reminder icon + date
- attachment icon + count
- optional note relation icon

Kartta avatar/assignee yoktur; tek kullanıcı uygulamasıdır.

Kart hover:

- subtle elevation
- quick edit icon

## 12.5 Drag & drop

Drag başlangıcında:

- kart %96 scale veya hafif elevation
- kaynak konumunda placeholder
- hedef aralığında accent insertion line

Kolon kenarına yaklaşınca yatay auto-scroll.

Optimistic:

- drop sonrası kart anında yeni yerde kalır
- sync beklerken kart üzerinde spinner gösterilmez
- yalnız global sync state değişir

Hata:

- yerel transaction başarısızsa kart eski konumuna döner ve snackbar
- uzak sync başarısızsa kart yerinde kalır, sync status uyarır

## 12.6 Mobile Kanban

Yatay kolon paging hissi.

- kolonlar snap etmez; serbest scroll
- kart drag için long press
- alternatif context action: `Başka kolona taşı`

Bu alternatif erişilebilirlik için de zorunludur.

## 12.7 Pano boş durumu

Hiç kolon yoksa:

`Bu pano boş`

Primary: `İlk kolonu oluştur`

Secondary: `Şablon kullan`

---

# 13. Ekran / Panel: Kart Detayı

Desktop: sağ side sheet `400 dp` varsayılan.

Mobile: full-screen page.

## 13.1 Header

- close/back
- card title inline
- overflow

## 13.2 Alanlar

- Kolon
- Etiketler
- Hatırlatıcı
- Ekler
- Açıklama
- İlişkili not
- Oluşturulma/güncellenme metadata

Alan satırı:

```text
Kolon        İnceleniyor ▾
Hatırlatıcı  Yarın 09:00
Etiketler    [Araştırma] [+]
```

## 13.3 Actions

- `Hatırlatıcı ekle`
- `Dosya ekle`
- `Nota dönüştür` / `İlişkili not oluştur`

Overflow:

- Kopyala
- Başka panoya taşı
- Sil

Kaydet button yok; auto-save.

---

# 14. Ekran: Hatırlatıcılar

## 14.1 Header

Başlık: `Hatırlatıcılar`

Segment:

- Yaklaşan
- Geçmiş

Primary/FAB: `Yeni hatırlatıcı`

## 14.2 Gruplama

Yaklaşan liste:

- Bugün
- Yarın
- Bu hafta
- Daha sonra

Her reminder satırı:

```text
09:30   Raporu gönder
        Proje Notu                         [⋯]
```

Date geçtiyse geçmiş bölümüne taşınır.

## 14.3 Quick actions

Swipe mobile / context menu desktop:

- 10 dk ertele
- 1 saat ertele
- Yarın
- Tamamlandı olarak işaretle
- Düzenle
- Sil

## 14.4 Empty state

`Yaklaşan hatırlatıcı yok`

Subtext: `Notlara veya kartlara tarih eklediğinde burada görünür.`

CTA: `Hatırlatıcı oluştur`

---

# 15. Sheet: Hatırlatıcı Düzenleyici

Alanlar:

1. Başlık
2. Tarih
3. Saat
4. Saat dilimi açıklaması
5. İlişkili not/kart
6. Tekrar — gelecekte genişletilebilir

Hızlı seçim chip'leri:

- Bugün
- Yarın
- Hafta sonu
- 1 hafta sonra

Saat chip'leri bağlama göre:

- 09:00
- 12:00
- 18:00

Primary: `Hatırlatıcı ekle` veya edit modunda `Bitti`.

Geçmiş tarih seçilirse inline validation:

`Geçmiş bir zaman için hatırlatıcı oluşturamazsın.`

## 15.1 Bildirim izni kapalıysa

Sheet içinde warning banner:

`Bildirimler kapalı. Hatırlatıcı kaydedilir ancak cihaz bildirimi gösterilemez.`

Button: `Ayarları aç`.

Hatırlatıcı kaydı tamamen engellenmez.

---

# 16. Global Arama

Arama iki biçimde açılabilir:

- tam ekran Arama sayfası
- desktop `⌘K` command palette

## 16.1 Command palette

Genişlik: 600–680 dp.

Üst:

`Ara...`

Alt kategoriler:

- Son kullanılanlar
- Notlar
- Kartlar
- Panolar
- Komutlar

Keyboard:

- ↑ ↓ gezin
- Enter aç
- Esc kapat

## 16.2 Arama sayfası

Toolbar altında büyük search field.

Filter chips:

- Tümü
- Notlar
- Kartlar
- Panolar
- Ekli dosyalar

Sonuç item:

- type icon
- title
- snippet içinde eşleşme highlight
- breadcrumb
- updated time

## 16.3 Offline arama

Yerel veriler normal aranır.

Bulutta olup yerelde bulunmayan içerik destekleniyorsa ayrı status mesajı:

`Çevrimdışısın; yalnız bu cihazdaki içerikler aranıyor.`

Bu bir error banner değildir; info text'tir.

---

# 17. Çöp Kutusu

`Notlar > Çöp Kutusu`.

Liste:

- başlık
- silinme zamanı
- otomatik kalıcı silme varsa kalan süre

Actions:

- Geri yükle
- Kalıcı sil

Toolbar:

- `Çöp kutusunu boşalt` danger text/button

Kalıcı silmede confirmation dialog:

Başlık: `Bu içerikleri kalıcı olarak sil?`

Açıklama: geri alınamayacağı açıkça belirtilir.

Buttons:

- `Vazgeç`
- `Kalıcı olarak sil`

---

# 18. Ayarlar Ana Ekranı

Desktop:

```text
Ayarlar
├── Görünüm
├── Bildirimler
├── Senkronizasyon
├── Depolama
└── Hakkında
```

Desktop'ta sol settings list + sağ details.
Mobile'da nested pages.

Her ayar satırı:

- icon
- title
- kısa description
- trailing control / chevron

---

# 19. Ayarlar: Görünüm

## 19.1 Tema

Segment/cards:

- Sistem
- Açık
- Koyu

## 19.2 Yoğunluk

- Rahat
- Kompakt

Kompakt mod özellikle desktop listeleri ve Kanban için.

## 19.3 Editor

- Metin boyutu: Küçük / Normal / Büyük
- Geniş sayfa: toggle

`Geniş sayfa` editor max width'i 760'tan yaklaşık 1040 dp'ye çıkarır.

---

# 20. Ayarlar: Bildirimler

Göster:

- OS permission status
- `Bildirimlere izin ver` / `Sistem ayarlarını aç`
- Varsayılan reminder saati
- Badge kullanımı toggle

Android exact alarm özel durumları açıklayıcı row/banner ile gösterilir.

Teknik terminoloji yerine:

`Dakik hatırlatıcılar için sistem izni gerekiyor.`

---

# 21. Ayarlar: Senkronizasyon

Bulut sync tamamen opsiyoneldir.

## 21.1 Sync bağlı değil

Kart/panel:

Başlık: `Bulut senkronizasyonu kapalı`

Açıklama: `Verilerin bu cihazda çalışmaya devam eder. İstersen cihazlar arasında eşitlemeyi açabilirsin.`

Primary: `Senkronizasyonu ayarla`

## 21.2 Sync bağlı

Göster:

- hesap kimliği / güvenli kısa tanım
- son sync zamanı
- bekleyen değişiklik sayısı
- `Şimdi eşitle`
- `Bağlantıyı kes`

Status card:

- Güncel
- Çevrimdışı
- Bekleyen değişiklikler
- Hata

## 21.3 Conflict durumu

Tek kullanıcı olmasına rağmen farklı cihaz versiyonları çakışabilir.

Varsayılan otomatik çözüm gerçekleşirse kullanıcı rahatsız edilmez.

İçerik kaybı riski varsa conflict resolution page/dialog:

```text
Aynı not iki cihazda değiştirildi

Bu cihazdaki sürüm        Buluttaki sürüm
14:32                     14:35
[önizleme]                [önizleme]

[Bu cihazdakini kullan] [Buluttakini kullan]
[İki sürümü de sakla]
```

Birincil öneri: `İki sürümü de sakla` veri kaybını önleyen güvenli seçenek olarak sunulabilir.

---

# 22. Senkronizasyon Merkezi / Tanılama

Normal kullanıcı akışında top-level ekran değildir.

Açılır:

- sync status'a tıklama
- Ayarlar > Senkronizasyon > Ayrıntılar

Göster:

- Son başarılı eşitleme
- Bekleyen değişiklikler
- Hatalı öğeler
- Retry durumu

Kullanıcı dostu liste:

`Not: Proje Planı — Yükleme bekliyor`

Action:

- `Tekrar dene`
- `Ayrıntıyı göster`

Teknik queue payload varsayılan görünümde gösterilmez.

Developer diagnostics altında opsiyonel olabilir.

---

# 23. Ayarlar: Depolama

Amaç: Yerel attachment cache ve uygulama alanını yönetmek.

## 23.1 Storage summary

```text
Toplam kullanılan     1.8 GB
Not verileri           84 MB
Ekler                 1.6 GB
Önbellek              116 MB
```

Progress bar yalnız kapasite bağlamı anlamlıysa.

## 23.2 Actions

- `Önbelleği temizle`
- `İndirilen dosyaları yönet`
- `Depolama konumunu göster` — desktop mümkünse

### Önbelleği temizle dialog

Checkbox seçenekleri:

- yalnız yeniden indirilebilir önbellek
- küçük görsel önizlemeleri

Kalıcı, henüz buluta yüklenmemiş yerel dosyalar cache temizliğiyle silinmez.

Bu güvenlik kuralı UI metninde açıkça belirtilir.

---

# 24. Dosya Seçme / Ek Ekleme UX'i

Tetikleyiciler:

- editor `/Dosya`
- `Ek ekle`
- kart detayı `Dosya ekle`

Mobile bottom sheet:

- Fotoğraf seç
- Dosya seç
- Kamera — gelecekte

Desktop popover/menu:

- Dosya seç
- Sürükleyip bırak

## 24.1 Drag & Drop overlay — desktop

Dosya pencere üzerine sürüklendiğinde:

- tüm uygun drop alanı subtle accent overlay
- merkezde `Dosyayı buraya bırak`

Dosya bırakıldığında:

- local copy progress
- UI thread bloklanmaz

Hata:

`Dosya eklenemedi. Kaynak dosyaya erişim kesildi.`

Retry + yeniden seç.

---

# 25. Dosya Görüntüleyici

Görsel/PDF için uygulama içi viewer mümkünse.

Header:

- back/close
- filename
- `Paylaş/Dışa aktar`
- `...`

PDF:

- page indicator
- zoom
- open externally

Dosya yerelde yok, bulutta varsa:

`Bu dosya bu cihazda değil`

Button: `İndir`.

Offline ve local copy yoksa:

`Dosyayı indirmek için bağlantı gerekiyor.`

---

# 26. Boş, yükleme ve hata durumları

## 26.1 Loading

Offline-first ekranlarda tam ekran spinner minimum kullanılmalıdır.

Kural:

- Yerel DB hazırsa içerik hemen gösterilir.
- İlk DB açılışında kısa skeleton olabilir.
- Remote sync hiçbir zaman ana ekranı bloke etmez.

## 26.2 Skeleton

Yalnız layout tahmin edilebiliyorsa.

- note rows
- board cards

Kanban mevcut local data varken remote için skeleton yapılmaz.

## 26.3 Error banner

Recoverable durumlar için içerik üstünde inline banner:

`Bazı değişiklikler henüz eşitlenemedi.` `[Tekrar dene]`

## 26.4 Full page error

Yalnız local DB açılamaması gibi uygulamanın temel işlevinin durduğu durumlarda.

Başlık: `Not verilerine erişilemedi`

Actions:

- `Tekrar dene`
- `Tanılama bilgisi`

Kullanıcıya “SQLite exception” gibi teknik mesaj gösterilmez.

---

# 27. Offline ve sync durum tasarımı

Offline-first deneyimin en kritik UX sözleşmesi:

## 27.1 Offline

Kullanıcı:

- not oluşturabilir,
- not düzenleyebilir,
- kart taşıyabilir,
- reminder oluşturabilir,
- yerel attachment ekleyebilir.

UI:

`○ Çevrimdışı · Değişiklikler bu cihazda kaydediliyor`

Renk: nötr/info; danger değil.

## 27.2 Pending sync

`↻ 4 değişiklik bekliyor`

Kullanıcı action almadan uygulama retry eder.

## 27.3 Sync success

Persistent “başarılı” toast gösterilmez.

Status sessizce `✓ Güncel` olur.

## 27.4 Sync error

İlk geçici hata kullanıcıyı rahatsız etmez.

Retry'lar tükendiğinde:

`! Bazı değişiklikler eşitlenemedi`

Click -> Sync Center.

---

# 28. Bildirim UX'i

Notification içeriği:

Başlık: reminder başlığı.

Alt satır: ilişkili not/kart adı gerekiyorsa.

Actions platform destekliyorsa:

- `10 dk ertele`
- `Tamamlandı`

Gizlilik açısından notification preview ayarı gelecekte eklenebilir.

Saat dilimi değiştiğinde uygulama açılışında reminder schedule reconcile edilir; kullanıcıya ancak anlamlı tarih değişikliği riski varsa bilgi verilir.

---

# 29. Motion ve animasyon

Animasyonlar hızlı ve işlevsel.

Genel süreler:

- hover/focus: 100–120 ms
- expand/collapse: 160–200 ms
- sheet: 220–260 ms
- drag reorder: spring-like, yaklaşık 180 ms

Kurallar:

- büyük parallax yok
- bounce minimum
- reduced motion ayarına saygı
- optimistic update'te gereksiz spinner yok

---

# 30. Erişilebilirlik

Minimum hedef: WCAG 2.2 AA yaklaşımı.

Kurallar:

- text kontrastı en az 4.5:1 hedefi
- büyük metin 3:1
- touch target minimum 44x44 dp; Android'de 48 tercih
- keyboard navigation tüm desktop ekranlarında
- visible focus ring
- icon-only button tooltip + semantic label
- renk tek başına durum belirtmez
- drag/drop için alternatif `Taşı` menüsü
- dynamic text scaling layout'u kırmamalı
- screen reader sırası görsel sıra ile uyumlu
- destructive dialog net action adı kullanır; `Evet/Hayır` kullanılmaz

---

# 31. Platform davranışları

## 31.1 macOS

- pencere minimum boyutu yaklaşık 900x600 hedeflenir
- native titlebar entegrasyonu mümkünse sade
- keyboard shortcut öncelikli
- sağ tık context menu
- hover states aktif
- dosya drag/drop güçlü destek

## 31.2 iOS

- safe areas
- swipe back
- haptic feedback yalnız önemli drag/drop ve completion anlarında
- Cupertino-native dialog hissi korunabilir fakat tasarım tokenları aynı kalır

## 31.3 Android

- system back davranışı
- Material motion
- exact alarm ve notification permission açıklaması
- predictive back ile uyum hedefi

---

# 32. Mikro metin standardı

Dil: kısa, açıklayıcı, teknik olmayan Türkçe.

Tercih:

- `Bu cihazda kaydedildi`
- `Senkronizasyon bekliyor`
- `Dosya eklenemedi`
- `Tekrar dene`

Kaçınılır:

- `Operation failed`
- `Queue error`
- `Remote datasource unavailable`
- `Unknown exception`

Butonlar eylem fiili ile:

- `Oluştur`
- `Ekle`
- `Geri yükle`
- `Kalıcı olarak sil`
- `Tekrar dene`

`Tamam` yalnız gerçekten bağlamsız confirmation durumunda.

---

# 33. Tasarım component envanteri

Flutter implementation'da ortak design system altında toplanması önerilen componentler:

```text
lib/app/design_system/
├── tokens/
│   ├── app_colors.dart
│   ├── app_spacing.dart
│   ├── app_radius.dart
│   └── app_typography.dart
├── components/
│   ├── app_button.dart
│   ├── app_icon_button.dart
│   ├── app_text_field.dart
│   ├── app_search_field.dart
│   ├── app_chip.dart
│   ├── app_empty_state.dart
│   ├── app_error_banner.dart
│   ├── app_sync_status.dart
│   ├── app_sidebar.dart
│   ├── app_toolbar.dart
│   ├── app_context_menu.dart
│   └── app_confirm_dialog.dart
└── responsive/
    └── app_breakpoints.dart
```

Feature-specific UI ortak design system içine taşınmamalıdır.

Örneğin:

- `KanbanCard` -> kanban feature
- `NoteEditorBlock` -> notes feature
- `AttachmentTile` -> attachments feature
- `ReminderTile` -> reminders feature

---

# 34. Ekran envanteri — geliştirme kontrol listesi

Aşağıdaki ekranlar/akışlar ürün tasarımının tamamlayıcı kapsamıdır:

### Uygulama kabuğu
- [ ] Onboarding — Hoş geldiniz
- [ ] Onboarding — Bildirim izni
- [ ] Responsive sidebar / navigation rail / bottom navigation
- [ ] Global command palette

### Ana
- [ ] Ana Sayfa
- [ ] Hızlı yakalama
- [ ] Bugün / yaklaşan hatırlatıcılar paneli

### Notlar
- [ ] Not listesi — liste
- [ ] Not listesi — grid
- [ ] Favoriler
- [ ] Son kullanılanlar
- [ ] Çöp Kutusu
- [ ] Not Editor
- [ ] Slash command
- [ ] Text selection toolbar
- [ ] Attachment block
- [ ] Image/PDF viewer

### Kanban
- [ ] Pano listesi
- [ ] Yeni pano oluşturma
- [ ] Kanban board
- [ ] Kolon menüsü
- [ ] Card drag/drop
- [ ] Card detail side sheet/page
- [ ] Move-card alternative accessibility flow

### Hatırlatıcı
- [ ] Yaklaşan listesi
- [ ] Geçmiş listesi
- [ ] Reminder editor
- [ ] Permission-disabled state
- [ ] Snooze quick actions

### Arama
- [ ] Full search screen
- [ ] Search empty state
- [ ] Search no-result state
- [ ] Offline search state

### Ayarlar
- [ ] Settings index
- [ ] Görünüm
- [ ] Bildirimler
- [ ] Senkronizasyon — bağlı değil
- [ ] Senkronizasyon — bağlı
- [ ] Conflict resolution
- [ ] Sync center / diagnostics
- [ ] Depolama
- [ ] Cache cleanup confirmation
- [ ] Hakkında

### Sistem durumları
- [ ] Offline banner/status
- [ ] Pending sync
- [ ] Sync failure
- [ ] Local DB fatal error
- [ ] Empty states
- [ ] Undo snackbar
- [ ] Destructive confirmation

---

# 35. Ana kullanıcı akışları

## 35.1 Hızlı not

```text
Ana Sayfa
-> Hızlı Yakalama
-> Yaz
-> Enter
-> Local DB write
-> Not kartı anında görünür
-> Sync queue arka planda
```

Hedef: 5 saniyeden kısa kullanıcı eforu; ağ gerektirmez.

## 35.2 Not + ek + reminder

```text
Not Editor
-> /Dosya
-> Dosya seç
-> Local copy progress
-> Attachment block görünür
-> Hatırlatıcı ekle
-> Tarih/saat seç
-> OS schedule
-> Local transaction
-> Background sync
```

## 35.3 Kart taşıma

```text
Kanban
-> Card drag
-> New position preview
-> Drop
-> UI optimistic move
-> Local transaction + fractional rank
-> Sync queue
```

## 35.4 Offline çalışma

```text
Bağlantı yok
-> User edits normally
-> Local saved
-> Sidebar: Çevrimdışı
-> Network returns
-> Automatic sync
-> Status silently becomes Güncel
```

---

# 36. Kaçınılacak UX anti-pattern'leri

1. Her düzenlemede `Kaydet` butonu göstermek.
2. Offline durumu kırmızı hata banner'ı olarak göstermek.
3. Remote sync sürerken ekranı spinner ile kilitlemek.
4. Kart taşıdıktan sonra server cevabını bekleyip sonra UI'ı değiştirmek.
5. Her dosya eklemede modal progress dialog açmak.
6. Tek kullanıcı uygulamasında avatar/assignee/team kontrolleri göstermek.
7. Bir ekranda iki veya daha fazla primary CTA kullanmak.
8. Telefon ekranında desktop side sheet'i zorlamak.
9. Sadece drag/drop ile yapılabilen kritik işlem bırakmak.
10. Placeholder'ı kalıcı field label gibi kullanmak.
11. Error mesajında backend/SQLite/Supabase jargonunu kullanıcıya göstermek.
12. Küçük `...` ikonunu 24x24 hit target ile bırakmak.
13. Sync başarısını sürekli toast ile bildirmek.
14. Silme eyleminden sonra undo sunmamak.
15. Local unsynced attachment'ları “cache temizle” ile silebilmek.

---

# 37. Uygulama geliştirme için tasarım kabul kriterleri

Bir ekran “UX açısından tamamlandı” sayılmadan önce:

- light ve dark theme çalışmalı,
- compact ve expanded layout tanımlı olmalı,
- empty state bulunmalı,
- loading stratejisi belirlenmiş olmalı,
- recoverable error state bulunmalı,
- keyboard/focus davranışı desktop için çalışmalı,
- touch target minimumları sağlanmalı,
- offline davranışı tanımlı olmalı,
- sync beklerken ana işlem bloke olmamalı,
- destructive action geri alma veya confirmation içermeli,
- componentler design token kullanmalı; rastgele hex/padding kullanılmamalı.

---

# 38. Önceliklendirilmiş uygulama sırası

UX implementation sırası:

1. Design tokens + responsive shell
2. Sidebar / bottom navigation / toolbar
3. Ana Sayfa + Quick Capture
4. Not listesi
5. Note Editor temel blokları
6. Pano listesi
7. Kanban board + card component
8. Card detail panel
9. Reminder list + editor
10. Attachment tile/block + file flows
11. Search + command palette
12. Settings
13. Sync status + Sync Center
14. Storage management
15. Trash + conflict resolution
16. Accessibility, keyboard ve motion polish

Bu sıra, görsel bileşenleri erken stabilize ederek feature ekiplerinin aynı component sistemini kullanmasını sağlar.

---

# 39. Nihai ürün hissi

`Not` açıldığında kullanıcı bir “veritabanı istemcisi” veya “senkronizasyon uygulaması” hissetmemelidir. Ana deneyim kağıt kadar hızlı ve sessiz olmalıdır:

- yazınca yazı görünür,
- sürükleyince kart taşınır,
- dosya ekleyince içerikte yerini alır,
- bağlantı yoksa çalışma devam eder,
- bağlantı geldiğinde uygulama kendi işini yapar.

Teknik karmaşıklık mimaride bulunur; arayüzde değil.
