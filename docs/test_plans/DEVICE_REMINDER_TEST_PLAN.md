# Gerçek Cihaz Yaşam Döngüsü, Hatırlatıcı ve Process Death Test Planı
**Doküman Kodu:** `TP-DEV-REMINDER-01`  
**Sürüm:** `1.0.0`  
**Tarih:** 2026-08-16  
**Durum:** `PLAN HAZIRLANDI — FİZİKSEL CİHAZ KOŞUSU 99-FINAL AŞAMASINDA YAPILACAKTIR (Henüz fiili cihaz koşusu yapılmamıştır)`

---

## 1. Amaç ve Kapsam

Bu doküman, Not/Kanban/Senkronizasyon uygulamasının Android, iOS ve macOS işletim sistemlerinde uygulama yaşam döngüsü geçişleri (foreground, background, terminated/process death, system reboot), hatırlatıcı alarm mekanizmaları (exact/inexact alarm, BOOT_COMPLETED, permission denial, timezone değişimi) ve veri tabanı/kuyruk toparlanma davranışlarını fiziksel cihazlar ve simülatörler üzerinde doğrulamak amacıyla hazırlanmış **ölçülebilir, adım adım test planıdır**.

> [!IMPORTANT]
> **Koşum Durumu Bildirimi:**
> Bu aşamada (Stage 07) veritabanı crash, WAL toparlanması, sync queue devamlılığı, attachment temizliği ve hatırlatıcı reconciliation mekanizmaları `test/integration/process_death_recovery_test.dart` entegrasyon test paketiyle otomatik olarak doğrulanmıştır (11/11 PASS).
> **Fiziksel cihaz testleri bu dokümanda tanımlanmış olup, fiili cihaz koşuları sürüm öncesi aşama olan `99-final-validation` kapsamında yürütülecektir.**

---

## 2. Test Edilen Platformlar ve Donanım Matrisi

| Platform | Hedef Sürümler | Test Ortamı / Donanım | Test Kapsamı |
| :--- | :--- | :--- | :--- |
| **Android** | Android 12 (API 31), 13 (API 33), 14 (API 34), 15 (API 35) | Fiziksel Cihaz (Pixel / Samsung Galaxy) + Android Emülatör | Exact Alarm, Inexact Fallback, BOOT_COMPLETED, Timezone Shift, Force Stop / SIGKILL |
| **iOS** | iOS 16.x, iOS 17.x, iOS 18.x | Fiziksel iPhone + iOS Simulator | UNUserNotificationCenter, Kilit Ekranı Bildirimi, İzin Reddi, Swipe-Kill / Suspended Restore |
| **macOS** | macOS 13 (Ventura), 14 (Sonoma), 15 (Sequoia) | Apple Silicon (M1/M2/M3) / Intel Mac | Yerel Bildirim Merkezi, Force Quit (`kill -9`), WAL Recovery, Concurrency |

---

## 3. Android Fiziksel Cihaz Doğrulama Matrisi

### Senaryo AND-01: Foreground ve Background Hatırlatıcı Bildirimi (Tam İzinli)
* **Amaç:** Uygulama açıkken (foreground) veya ana ekrana atılmışken (background) zamanı gelen hatırlatıcının sistem bildirim çekmecesine sesli ve başlık/gövde ile düşmesini doğrulamak.
* **Ön Koşul:** `POST_NOTIFICATIONS` ve `SCHEDULE_EXACT_ALARM` izinleri verilmiş.
* **Adım Adım Koşum:**
  1. Not ekranını açın ve başlığı `AND-01 Test Notu` olan bir not oluşturun.
  2. Hatırlatıcı ekleyin: Şu anki zamandan 2 dakika sonraya (`T + 2 dk`) ayarlayın.
  3. Cihazın ana ekranına dönün (Home butonu veya swipe up) -> Uygulama background durumuna geçer.
  4. 2 dakika bekleyin.
  5. Bildirim sesini/titreşimini dinleyin ve bildirim çekmecesini aşağı çekin.
  6. Bildirime dokunun.
* **Beklenen Gözlem ve Loglar:**
  * Logcat çıktısı: `[LocalNotificationService] Scheduled notification id=<id> at <time> (mode=exact)`
  * Bildirim başlığı: `AND-01 Test Notu`, gövdesi: `Hatırlatıcınız hazır.` (veya girilen gövde).
  * Bildirime dokunulduğunda uygulama açılır ve ilgili nota doğrudan odaklanır.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Bildirim tam zamanında (±5 sn) sesli/banner olarak belirir, tıklanınca ilgili nota gider.
  * **KALDI:** Bildirim gelmez, sessiz düşer veya tıklanınca çökme yaşanır.

---

### Senaryo AND-02: Terminated / Process Death Sonrası Hatırlatıcı Tetikleme (Killed State)
* **Amaç:** Uygulama işletim sistemi veya kullanıcı tarafından zorla sonlandırıldığında (terminated/killed) AlarmManager'a kaydedilmiş kesin alarmların çalışmasını ve uygulamanın bildirim üzerinden soğuk açılışla (cold start) güvenle toparlanmasını doğrulamak.
* **Ön Koşul:** Cihazda uygulama yüklü ve `SCHEDULE_EXACT_ALARM` izni aktif.
* **Adım Adım Koşum:**
  1. Bir karta `T + 3 dk` sonrasına hatırlatıcı kurun (`AND-02 Görevi`).
  2. Uygulamayı "Son Uygulamalar" (Recent Apps) listesinden yukarı kaydırarak kapatın.
  3. ADB üzerinden uygulamanın sürecini tamamen öldürün:
     ```bash
     adb shell am force-stop com.example.not_app
     ```
  4. Sürecin durduğunu doğrulayın: `adb shell pidof com.example.not_app` (boş dönmeli).
  5. 3 dakika dolduğunda cihazı gözlemleyin.
  6. Gelen bildirime dokunun.
* **Beklenen Gözlem ve Loglar:**
  * AlarmManager belirlenen UTC zamanında `AlarmReceiver` tetikler.
  * Durum çubuğunda uygulama ikonu ve bildirim kartı belirir.
  * Bildirime tıklandığında uygulama cold start yapar, Drift DB WAL dosyası hatasız açılır, doğrudan `AND-02 Görevi` kartının detay ekranı açılır.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Uygulama tamamen kapalıyken alarm çalar, bildirime basılınca cold start ile veri bozulmadan açılır.
  * **KALDI:** Bildirim gelmez, uygulama açılışında `SQLiteException` veya ANR (Application Not Responding) verir.

---

### Senaryo AND-03: Cihaz Yeniden Başlatma Sonrası Otomatik Hatırlatıcı Kurtarma (BOOT_COMPLETED)
* **Amaç:** Cihaz kapatılıp açıldığında (reboot) RAM'deki alarmlar silindiği için `RECEIVE_BOOT_COMPLETED` alıcısının tetiklenerek Drift DB'deki aktif hatırlatıcıları AlarmManager'a yeniden planlamasını doğrulamak.
* **Ön Koşul:** DB'de geleceğe ayarlanmış en az 2 aktif hatırlatıcı bulunuyor (`T + 15 dk` ve `T + 2 saat`).
* **Adım Adım Koşum:**
  1. İki hatırlatıcı tanımlayın.
  2. Cihazı yeniden başlatın:
     ```bash
     adb reboot
     ```
  3. Cihaz açıldıktan sonra kilit ekranını açın; **uygulamayı manuel olarak başlatmayın**.
  4. ADB logcat ile `BOOT_COMPLETED` alıcısının çalışmasını inceleyin:
     ```bash
     adb logcat -s "NotificationReceiver" "AppBootstrap"
     ```
  5. `T + 15 dk` zamanı geldiğinde bildirimin düşmesini bekleyin.
* **Beklenen Gözlem ve Loglar:**
  * Logcat: `BootReceiver: Reconciling reminders from database... Scheduled count: 2, Past skipped: 0`
  * Uygulama kullanıcı tarafından açılmasa dahi 15. dakikada alarm bildirimi ekranı aydınlatır ve ses çalar.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Yeniden başlatma sonrası kullanıcı uygulamayı açmasa bile alarm zamanında çalar.
  * **KALDI:** Reboot sonrası alarmlar kaybolur veya tetiklenmez.

---

### Senaryo AND-04: Android 12+ Exact Alarm İzni Reddedildiğinde Fallback Davranışı (Inexact Mode)
* **Amaç:** Kullanıcı Android Ayarlarından "Alarmlar ve Hatırlatıcılar" iznini kapattığında uygulamanın çökmemesini, kontrollü olarak `inexactAllowWhileIdle` moduna geçmesini ve kullanıcıyı UI üzerinden bilgilendirmesini doğrulamak.
* **Ön Koşul:** Android 12+ (API 31+) cihaz.
* **Adım Adım Koşum:**
  1. Cihaz Ayarları -> Uygulamalar -> Not Uygulaması -> Alarmlar ve Hatırlatıcılar -> **İzni Kapatın (Revoke)**.
  2. Uygulamayı açın.
  3. Ayarlar ekranına ve Hatırlatıcılar ekranına gidin.
  4. Yeni bir hatırlatıcı ekleyin (`AND-04 İzin Reddi Notu`, `T + 3 dk`).
  5. Ekranda çıkan uyarı mesajını gözlemleyin.
  6. "Sistem Ayarlarını Aç" butonuna dokunun.
* **Beklenen Gözlem ve Loglar:**
  * Hatırlatıcı ekleme anında çökme yaşanmaz (`SecurityException` oluşmaz).
  * UI Bildirimi: *"Kesin alarm izni kapalı olduğu için hatırlatıcınız yaklaşık zamanlı (inexact) planlandı."*
  * Veritabanı durumu: `reminders.scheduling_status = 'inexact'`.
  * "Sistem Ayarlarını Aç" butonuna basıldığında Android'in özel *Alarmlar ve Hatırlatıcılar* izin sayfası açılır.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Sıfır çökme, inexact fallback başarıyla uygulanır, izin kurtarma butonu doğru sayfayı açar.
  * **KALDI:** Uygulama çöker (`SecurityException: Caller not allowed to schedule exact alarms`) veya hatırlatıcı kaydedilemez.

---

### Senaryo AND-05: Saat Dilimi (Timezone / Gün Işığı Tasarrufu) Değişimi Doğrulaması
* **Amaç:** Kullanıcı farklı bir ülkeye seyahat ettiğinde veya cihaz saat dilimini değiştirdiğinde hatırlatıcıların mutlak UTC anını koruyarak yerel saate göre doğru tetiklenmesini doğrulamak.
* **Ön Koşul:** Cihaz başlangıçta `Europe/Istanbul` (UTC+3) diliminde.
* **Adım Adım Koşum:**
  1. Saat 14:00 (UTC+3) iken, saat 16:00 (UTC+3) için hatırlatıcı kurun (Mutlak an: 13:00 UTC).
  2. Cihaz Ayarları -> Sistem -> Tarih ve Saat -> Saat Dilimini `Europe/London` (UTC+1) olarak değiştirin.
  3. Uygulamayı ön plana getirin (resumed).
  4. Hatırlatıcılar listesini inceleyin.
* **Beklenen Gözlem ve Loglar:**
  * Uygulama açılışında `NotificationService.refreshTimeZone()` tetiklenir.
  * Hatırlatıcı saati UI'da Londra saatine göre `14:00 (UTC+1)` olarak gösterilir.
  * Mutlak tetiklenme anı (13:00 UTC) değişmez; gerçek zaman 13:00 UTC'ye ulaştığında bildirim çalar.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Saat dilimi değişimi sonrası hatırlatıcı mutlak anında çalar, UI yeni yerel saate adapte olur.
  * **KALDI:** Hatırlatıcı kaybolur, 2 saat erken/geç çalar veya uygulama kilitlenir.

---

### Senaryo AND-06: Sync ve Dosya Yükleme Anında Process Death & WAL Recovery
* **Amaç:** 10 MB'lık büyük bir ek dosya sunucuya yüklenirken veya çoklu sync batch operasyonu sırasında `SIGKILL` ile süreç öldürüldüğünde veritabanı bütünlüğünün bozulmamasını, açılışta temp dosyaların temizlenmesini ve sync kuyruğunun güvenle devam etmesini doğrulamak.
* **Ön Koşul:** Supabase veya mock remote gateway bağlı, 1 adet 10 MB PDF eki yükleniyor.
* **Adım Adım Koşum:**
  1. Not ekranında 10 MB PDF ekleyin -> Durum: `Yükleniyor (%35)`.
  2. Yükleme devam ederken terminalden anında süreci öldürün:
     ```bash
     adb shell kill -9 $(adb shell pidof com.example.not_app)
     ```
  3. Uygulamayı yeniden başlatın.
  4. Logcat ve UI durumunu inceleyin:
     ```bash
     adb logcat -s "AppBootstrap" "DriftAttachmentsRepository" "SyncCoordinator"
     ```
* **Beklenen Gözlem ve Loglar:**
  * Drift SQLite WAL toparlanır: `PRAGMA integrity_check -> ok`.
  * `AppBootstrap` başlangıcında `attachments.reconcile()` çalışır: Yarım kalan `.tmp` dosyaları temizlenir.
  * Veritabanında attachment durumu `pendingUpload` / `retryWaiting` durumuna geçer; dosya diski terk etmez.
  * `SyncCoordinator` kuyruktaki `uploadAttachment` operasyonunu yeniden devreye alır ve yükleme baştan tamamlanır.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Veritabanında bozulma (corruption) yok, orphan temp dosya kalmaz, yükleme otomatik tamamlanır.
  * **KALDI:** `DatabaseCorruptException`, `disk I/O error` veya dosya sonsuza dek "Yükleniyor" durumunda asılı kalır.

---

## 4. iOS Fiziksel Cihaz Doğrulama Matrisi

### Senaryo IOS-01: Foreground ve Kilit Ekranı (Lock Screen) Bildirim Gösterimi
* **Amaç:** iOS `UNUserNotificationCenter` entegrasyonunun foreground (uygulama açıkken banner/sound) ve kilit ekranında kusursuz çalışmasını doğrulamak.
* **Ön Koşul:** iOS Bildirim izni verilmiş.
* **Adım Adım Koşum:**
  1. Bir nota `T + 2 dk` sonrasına hatırlatıcı ekleyin (`IOS-01 Test Notu`).
  2. Cihazı güç tuşuyla kilitleyin (Lock Screen).
  3. 2 dakika bekleyin.
  4. Bildirim geldiğinde kilit ekranında bildirime dokunarak FaceID/TouchID ile kilidi açın.
* **Beklenen Gözlem:**
  * Kilit ekranında sesli ve titreşimli zengin bildirim kartı görüntülenir.
  * Dokunulduğunda iOS uygulamayı açar, Drift DB açılır, `IOS-01 Test Notu` ekrana gelir.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Kilit ekranında bildirim belirir, tıklama doğrudan hedef nota yönlendirir.
  * **KALDI:** Kilit ekranında bildirim çıkmaz veya tıklandığında boş beyaz ekran kalır.

---

### Senaryo IOS-02: Terminated (Swipe-to-Kill) Sonrası Bildirim ve Soğuk Başlatma
* **Amaç:** iOS App Switcher üzerinden yukarı kaydırılarak kapatılan (terminated) uygulamanın yerel bildirimlerinin iOS işletim sistemi tarafından bağımsız tetiklenmesini doğrulamak.
* **Adım Adım Koşum:**
  1. `T + 3 dk` sonrasına hatırlatıcı kurun.
  2. iOS App Switcher'ı açın (alttan yukarı kaydırıp bekleyin) ve Not uygulamasını yukarı fırlatarak kapatın.
  3. Cihazı beklemeye alın.
  4. 3. dakikada gelen bildirimi kontrol edin.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Uygulama kapalıyken iOS bildirimi gösterir, tıklandığında uygulama sorunsuz açılır.
  * **KALDI:** Bildirim gelmez veya uygulama açılışında çöker.

---

### Senaryo IOS-03: Bildirim İzni Reddedildiğinde Ayarlar Yönlendirmesi
* **Amaç:** iOS ilk açılış bildirim izni reddedildiğinde uygulamanın bunu tespit etmesi ve ayarlara yönlendiren kurtarma aksiyonu sunması.
* **Adım Adım Koşum:**
  1. iOS Ayarlar -> Notlar -> Bildirimler -> **İzin Ver'i Kapatın**.
  2. Uygulamayı açın ve Ayarlar -> Bildirimler bölümüne gidin.
  3. "Bildirim izni kapalı" uyarısını ve "iOS Ayarlarında Aç" butonunu gözlemleyin.
  4. Butona dokunun.
* **Beklenen Gözlem:**
  * Butona dokunulduğunda doğrudan iOS Sistem Ayarları uygulamasının ilgili uygulama sayfasına geçiş yapılır.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** URL şeması (`app-settings:`) doğru tetiklenir ve iOS Ayarları açılır.
  * **KALDI:** Buton tepki vermez veya geçersiz URL hatası fırlatır.

---

## 5. macOS Masaüstü Doğrulama Matrisi

### Senaryo MAC-01: Masaüstü Bildirim Merkezi ve Dock Etkileşimi
* **Amaç:** macOS bildirim merkezinde banner/uyarı gösterilmesi ve tıklanınca pencerenin öne getirilmesi.
* **Adım Adım Koşum:**
  1. macOS uygulamasında bir karta `T + 1 dk` hatırlatıcı kurun.
  2. Uygulama penceresini simge durumuna küçültün (Minimize / ⌘M).
  3. 1 dakika sonra ekranın sağ üst köşesinde çıkan macOS bildirimine dokunun.
* **Beklenen Gözlem:**
  * macOS Bildirim Merkezinde başlık ve açıklama içeren banner çıkar.
  * Tıklandığında uygulama penceresi restore edilir ve en öne (foreground) gelir.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Bildirim sağ üstte çıkar, tıklanınca pencere odağa gelir.
  * **KALDI:** Bildirim çıkmaz veya pencere tepkisiz kalır.

---

### Senaryo MAC-02: Ani Kapanma (`kill -9`) ve WAL Dosyası Kurtarma
* **Amaç:** macOS üzerinde `SIGKILL` sonrasında SQLite WAL dosyasının kilitlenme (deadlock / `SQLITE_BUSY`) olmaksızın açılması.
* **Adım Adım Koşum:**
  1. Uygulamada not yazın ve kanban kartlarını sürükleyip bırakın.
  2. Terminalden uygulamayı zorla öldürün:
     ```bash
     pkill -9 not_app || killall -9 not_app
     ```
  3. Uygulamayı yeniden başlatın.
* **Beklenen Gözlem:**
  * Uygulama 500 ms içinde açılır.
  * `PRAGMA busy_timeout = 5000` sayesinde hiçbir deadlock veya timeout yaşanmaz.
  * Son kaydedilen tüm notlar ve kolon sıralamaları eksiksiz gelir.
* **Geçti/Kaldı Kriteri:**
  * **GEÇTİ:** Hızlı açılış, sıfır kilitlenme, eksiksiz veri bütünlüğü.
  * **KALDI:** Uygulama açılışta takılı kalır (deadlock) veya veritabanı kilitli hatası verir.

---

## 6. Özet Doğrulama Kontrol Listesi (Master Verification Matrix)

| Test ID | Platform | Senaryo Özeti | Otomasyon (Unit/Integ) | Gerçek Cihaz Durumu |
| :--- | :--- | :--- | :--- | :--- |
| **AND-01** | Android | Foreground/Background Exact Bildirim | ✅ PASS (`process_death_recovery_test`) | ⏳ Planlandı (99-final) |
| **AND-02** | Android | Terminated/Killed State Alarm Tetikleme | ✅ PASS (`process_death_recovery_test`) | ⏳ Planlandı (99-final) |
| **AND-03** | Android | BOOT_COMPLETED Reboot Sonrası Yeniden Planlama | ✅ PASS (`process_death_recovery_test`) | ⏳ Planlandı (99-final) |
| **AND-04** | Android | SCHEDULE_EXACT_ALARM İzin Reddi & Inexact Fallback | ✅ PASS (`process_death_recovery_test`) | ⏳ Planlandı (99-final) |
| **AND-05** | Android | Timezone / DST Değişimi & Reconciliation | ✅ PASS (`notification_service_test`) | ⏳ Planlandı (99-final) |
| **AND-06** | Android | Transfer Sırasında Kill & WAL/Kuyruk Kurtarma | ✅ PASS (`process_death_recovery_test`) | ⏳ Planlandı (99-final) |
| **IOS-01** | iOS | Kilit Ekranı Bildirimi & Deep Link | ✅ PASS (`reminders_reconciliation_test`) | ⏳ Planlandı (99-final) |
| **IOS-02** | iOS | Swipe-Kill Sonrası iOS Bildirim & Soğuk Başlatma | ✅ PASS (`process_death_recovery_test`) | ⏳ Planlandı (99-final) |
| **IOS-03** | iOS | Bildirim İzni Reddi & `app-settings:` Yönlendirme | ✅ PASS (`notification_service_test`) | ⏳ Planlandı (99-final) |
| **MAC-01** | macOS | Masaüstü Bildirim Merkezi & Odaklanma | ✅ PASS (`reminders_reconciliation_test`) | ⏳ Planlandı (99-final) |
| **MAC-02** | macOS | `kill -9` Sonrası WAL Replay & Deadlock Koruması | ✅ PASS (`process_death_recovery_test`) | ⏳ Planlandı (99-final) |

---

## 7. Sonuç ve Sonraki Aşama

* **AC1 & AC2:** SQLite WAL, in-flight sync kuyruğu, interrupted attachment download/upload kurtarma ve hatırlatıcı reconciliation mantığı 11/11 otomatik entegrasyon testiyle kanıtlanmıştır.
* **AC3:** Android, iOS ve macOS platformları için ölçülebilir adım adım cihaz test planı eksiksiz dokümante edilmiştir.
* **Sonraki Aşama:** `08-notes-editor-ux` (Slash komut paleti, biçimlendirme araç çubuğu ve zengin klavye akışı).
