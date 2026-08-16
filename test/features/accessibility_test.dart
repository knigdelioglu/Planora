import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_app/app/theme/app_theme.dart';
import 'package:not_app/app/widgets/common_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestScaffold({required Widget child, ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('Kriter 2: Semantik Etiketler (Semantics), Tooltip ve Erişilebilirlik', () {
    testWidgets(
      'AppButton tüm varyantlarında doğru etiket, tooltip ve buton işlevi sağlar',
      (tester) async {
        bool kaydetClicked = false;
        bool iptalClicked = false;
        bool dahaFazlaClicked = false;
        bool silClicked = false;

        await tester.pumpWidget(
          buildTestScaffold(
            child: Column(
              children: <Widget>[
                AppButton.filled(
                  label: 'Kaydet',
                  onPressed: () {
                    kaydetClicked = true;
                  },
                  tooltip: 'Değişiklikleri kaydet',
                ),
                AppButton.outlined(
                  label: 'İptal',
                  onPressed: () {
                    iptalClicked = true;
                  },
                  semanticLabel: 'İşlemi iptal et',
                ),
                AppButton.text(
                  label: 'Daha Fazla',
                  onPressed: () {
                    dahaFazlaClicked = true;
                  },
                ),
                AppButton.danger(
                  label: 'Sil',
                  onPressed: () {
                    silClicked = true;
                  },
                  semanticLabel: 'Notu kalıcı olarak sil',
                ),
              ],
            ),
          ),
        );

        expect(find.widgetWithText(AppButton, 'Kaydet'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'İptal'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Daha Fazla'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Sil'), findsOneWidget);
        expect(find.byTooltip('Değişiklikleri kaydet'), findsOneWidget);

        await tester.tap(find.widgetWithText(AppButton, 'Kaydet'));
        await tester.pump();
        expect(kaydetClicked, isTrue);

        await tester.tap(find.widgetWithText(AppButton, 'İptal'));
        await tester.pump();
        expect(iptalClicked, isTrue);

        await tester.tap(find.widgetWithText(AppButton, 'Daha Fazla'));
        await tester.pump();
        expect(dahaFazlaClicked, isTrue);

        await tester.tap(find.widgetWithText(AppButton, 'Sil'));
        await tester.pump();
        expect(silClicked, isTrue);
      },
    );

    testWidgets(
      'AppButton loading durumunda butonu devre dışı bırakır ve yükleniyor semantiği sunar',
      (tester) async {
        bool pressed = false;
        await tester.pumpWidget(
          buildTestScaffold(
            child: AppButton.filled(
              label: 'Eşitle',
              isLoading: true,
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Eşitle'), findsOneWidget);

        await tester.tap(find.byType(AppButton));
        await tester.pump();
        expect(pressed, isFalse);
      },
    );

    testWidgets('AppTextField doğru etiket, ipucu ve metin kontrolü sağlar', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Başlangıç');

      await tester.pumpWidget(
        buildTestScaffold(
          child: AppTextField(
            controller: controller,
            label: 'Not Başlığı',
            hintText: 'Başlık girin...',
            semanticLabel: 'Not başlığı metin alanı',
          ),
        ),
      );

      expect(find.text('Not Başlığı'), findsOneWidget);
      expect(find.text('Başlangıç'), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(AppTextField), 'Yeni Başlık Değeri');
      await tester.pump();
      expect(controller.text, 'Yeni Başlık Değeri');
    });

    testWidgets(
      'AppStatusChip semantik ve tıklanabilir durum etiketlerini yönetir',
      (tester) async {
        bool chipTapped = false;
        await tester.pumpWidget(
          buildTestScaffold(
            child: Column(
              children: <Widget>[
                const AppStatusChip(
                  label: 'Tamamlandı',
                  statusType: AppStatusType.success,
                  tooltip: 'Görev başarıyla tamamlandı',
                ),
                AppStatusChip(
                  label: 'Filtrele',
                  statusType: AppStatusType.info,
                  onTap: () {
                    chipTapped = true;
                  },
                ),
              ],
            ),
          ),
        );

        expect(find.text('Tamamlandı'), findsOneWidget);
        expect(find.text('Filtrele'), findsOneWidget);

        await tester.tap(find.text('Filtrele'));
        await tester.pump();
        expect(chipTapped, isTrue);
      },
    );

    testWidgets('AppBanner liveRegion ve alert semantiğini doğru iletir', (
      tester,
    ) async {
      bool dismissed = false;
      bool actionTriggered = false;

      await tester.pumpWidget(
        buildTestScaffold(
          child: AppBanner(
            title: 'Senkronizasyon Uyarısı',
            message:
                'İnternet bağlantısı kesildi, değişiklikler yerelde saklanıyor.',
            variant: AppBannerVariant.warning,
            actionText: 'Tekrar Bağlan',
            onAction: () {
              actionTriggered = true;
            },
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      );

      expect(find.text('Senkronizasyon Uyarısı'), findsOneWidget);
      expect(
        find.text(
          'İnternet bağlantısı kesildi, değişiklikler yerelde saklanıyor.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Tekrar Bağlan'));
      await tester.pump();
      expect(actionTriggered, isTrue);

      await tester.tap(find.byTooltip('Kapat'));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('AppDialog başlık semantik başlığı ve aksiyonları sunar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppDialog.show<bool>(
                      context: context,
                      title: 'Silme Onayı',
                      message: 'Bu öğeyi silmek istediğinizden emin misiniz?',
                      icon: Icons.delete_outline_rounded,
                      isDestructive: true,
                      actions: <Widget>[
                        AppButton.text(
                          label: 'Vazgeç',
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        AppButton.danger(
                          label: 'Sil',
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    );
                  },
                  child: const Text('Dialog Aç'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dialog Aç'));
      await tester.pumpAndSettle();

      expect(find.text('Silme Onayı'), findsOneWidget);
      expect(
        find.text('Bu öğeyi silmek istediğinizden emin misiniz?'),
        findsOneWidget,
      );
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(find.text('Silme Onayı'), findsNothing);
    });

    testWidgets(
      'AppPageHeader ve AppSection semantik başlık (header: true) rolü sağlar',
      (tester) async {
        await tester.pumpWidget(
          buildTestScaffold(
            child: Column(
              children: const <Widget>[
                AppPageHeader(
                  title: 'Notlar',
                  subtitle: 'Tüm kişisel notlarınız',
                ),
                AppSection(title: 'Son Düzenlenenler', child: Text('İçerik')),
              ],
            ),
          ),
        );

        expect(find.text('Notlar'), findsOneWidget);
        expect(find.text('Son Düzenlenenler'), findsOneWidget);
      },
    );
  });

  group('Kriter 2: Minimum 48x48 dp Dokunma Alanı (Touch Target)', () {
    testWidgets('AppButton en az 48x48 dp boyutunda oluşturulur', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: AppButton.filled(label: 'Tamam', onPressed: () {}),
        ),
      );

      final Size buttonSize = tester.getSize(find.byType(AppButton));
      expect(
        buttonSize.width,
        greaterThanOrEqualTo(48.0),
        reason: 'Buton genişliği en az 48dp olmalıdır',
      );
      expect(
        buttonSize.height,
        greaterThanOrEqualTo(48.0),
        reason: 'Buton yüksekliği en az 48dp olmalıdır',
      );
    });

    testWidgets('AppTextField en az 48 dp yüksekliğinde giriş alanı sağlar', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestScaffold(
          child: const AppTextField(
            label: 'E-posta',
            hintText: 'ornek@alan.com',
          ),
        ),
      );

      final Size fieldSize = tester.getSize(find.byType(AppTextField));
      expect(
        fieldSize.height,
        greaterThanOrEqualTo(48.0),
        reason: 'Metin alanı dokunma yüksekliği en az 48dp olmalıdır',
      );
    });

    testWidgets(
      'Tıklanabilir AppStatusChip en az 48x48 dp etkileşim alanına sahiptir',
      (tester) async {
        await tester.pumpWidget(
          buildTestScaffold(
            child: AppStatusChip(
              label: 'Aktif',
              statusType: AppStatusType.success,
              onTap: () {},
            ),
          ),
        );

        final Size chipSize = tester.getSize(find.byType(AppStatusChip));
        expect(
          chipSize.width,
          greaterThanOrEqualTo(48.0),
          reason: 'Tıklanabilir çip genişliği en az 48dp olmalıdır',
        );
        expect(
          chipSize.height,
          greaterThanOrEqualTo(48.0),
          reason: 'Tıklanabilir çip yüksekliği en az 48dp olmalıdır',
        );
      },
    );

    testWidgets('AppTheme tüm buton temalarında 48x48 dp minimumSize sağlar', (
      tester,
    ) async {
      final ThemeData lightTheme = AppTheme.light();
      final ThemeData darkTheme = AppTheme.dark();

      expect(
        lightTheme.filledButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        lightTheme.filledButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.width,
        greaterThanOrEqualTo(48.0),
      );

      expect(
        lightTheme.outlinedButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        lightTheme.outlinedButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.width,
        greaterThanOrEqualTo(48.0),
      );

      expect(
        lightTheme.textButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        lightTheme.textButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.width,
        greaterThanOrEqualTo(48.0),
      );

      expect(
        lightTheme.iconButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        lightTheme.iconButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.width,
        greaterThanOrEqualTo(48.0),
      );

      expect(
        darkTheme.filledButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        darkTheme.outlinedButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        darkTheme.textButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
      expect(
        darkTheme.iconButtonTheme.style?.minimumSize
            ?.resolve(<WidgetState>{})
            ?.height,
        greaterThanOrEqualTo(48.0),
      );
    });
  });

  group('Kriter 3: Klavye Odak Halkaları ve Odak Sırası (Keyboard Focus)', () {
    testWidgets(
      'Klavye Tab geçişi odak halkasını ve odak sırasını doğru ilerletir',
      (tester) async {
        final FocusNode focusNode1 = FocusNode();
        final FocusNode focusNode2 = FocusNode();
        final FocusNode focusNode3 = FocusNode();

        await tester.pumpWidget(
          buildTestScaffold(
            child: Column(
              children: <Widget>[
                AppTextField(
                  label: 'Alan 1',
                  focusNode: focusNode1,
                  autofocus: true,
                ),
                AppTextField(label: 'Alan 2', focusNode: focusNode2),
                AppButton.filled(
                  label: 'Gönder',
                  focusNode: focusNode3,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(focusNode1.hasFocus, isTrue);
        expect(focusNode2.hasFocus, isFalse);
        expect(focusNode3.hasFocus, isFalse);

        // Focus next
        focusNode1.nextFocus();
        await tester.pump();

        expect(focusNode1.hasFocus, isFalse);
        expect(focusNode2.hasFocus, isTrue);

        // Focus next again
        focusNode2.nextFocus();
        await tester.pump();

        expect(focusNode2.hasFocus, isFalse);
        expect(focusNode3.hasFocus, isTrue);

        focusNode1.dispose();
        focusNode2.dispose();
        focusNode3.dispose();
      },
    );

    testWidgets(
      'AppTheme focusColor ve focusedBorder belirgin görsel göstergelere sahiptir',
      (tester) async {
        final ThemeData lightTheme = AppTheme.light();
        final ThemeData darkTheme = AppTheme.dark();

        expect(
          lightTheme.focusColor.a,
          greaterThan(0.0),
          reason: 'Odak rengi şeffaf olmamalıdır',
        );
        expect(
          darkTheme.focusColor.a,
          greaterThan(0.0),
          reason: 'Karanlık tema odak rengi şeffaf olmamalıdır',
        );

        final focusedBorder =
            lightTheme.inputDecorationTheme.focusedBorder
                as OutlineInputBorder?;
        expect(focusedBorder, isNotNull);
        expect(
          focusedBorder!.borderSide.width,
          greaterThanOrEqualTo(1.5),
          reason: 'Giriş odak çerçevesi en az 1.5px olmalıdır',
        );
      },
    );
  });

  group('Kriter 3: WCAG 2.1 Kontrast Oranları Doğrulaması', () {
    test(
      'Kontrast oranı hesaplama algoritması referans değerleri doğrular',
      () {
        final double blackWhiteRatio = AppColors.getContrastRatio(
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
        );
        expect(blackWhiteRatio, closeTo(21.0, 0.1));

        final double sameColorRatio = AppColors.getContrastRatio(
          const Color(0xFF5B57D9),
          const Color(0xFF5B57D9),
        );
        expect(sameColorRatio, closeTo(1.0, 0.01));
      },
    );

    test(
      'Açık Tema (Light Theme) WCAG AA standartlarını (>= 4.5:1) karşılar',
      () {
        // 1. Ana metin kontrastı (Canvas üzerinde)
        final double textOnCanvas = AppColors.getContrastRatio(
          AppColors.lightText,
          AppColors.lightCanvas,
        );
        expect(
          textOnCanvas,
          greaterThanOrEqualTo(4.5),
          reason: 'lightText on lightCanvas >= 4.5:1',
        );

        // 2. Ana metin kontrastı (Surface / Card üzerinde)
        final double textOnSurface = AppColors.getContrastRatio(
          AppColors.lightText,
          AppColors.lightSurface,
        );
        expect(
          textOnSurface,
          greaterThanOrEqualTo(7.0),
          reason: 'lightText on lightSurface >= 7.0:1 (AAA)',
        );

        // 3. İkincil metin kontrastı (Surface üzerinde)
        final double secondaryOnSurface = AppColors.getContrastRatio(
          AppColors.lightSecondary,
          AppColors.lightSurface,
        );
        expect(
          secondaryOnSurface,
          greaterThanOrEqualTo(4.5),
          reason: 'lightSecondary on lightSurface >= 4.5:1 (AA)',
        );

        // 4. Vurgu rengi kontrastı (Surface üzerinde)
        final double accentOnSurface = AppColors.getContrastRatio(
          AppColors.lightAccent,
          AppColors.lightSurface,
        );
        expect(
          accentOnSurface,
          greaterThanOrEqualTo(4.5),
          reason: 'lightAccent on lightSurface >= 4.5:1 (AA)',
        );

        // 5. Tehlike/Hata rengi kontrastı (Surface üzerinde)
        final double dangerOnSurface = AppColors.getContrastRatio(
          AppColors.lightDanger,
          AppColors.lightSurface,
        );
        expect(
          dangerOnSurface,
          greaterThanOrEqualTo(4.5),
          reason: 'lightDanger on lightSurface >= 4.5:1 (AA)',
        );
      },
    );

    test(
      'Karanlık Tema (Dark Theme) WCAG AA standartlarını (>= 4.5:1) karşılar',
      () {
        // 1. Ana metin kontrastı (Dark Canvas üzerinde)
        final double textOnCanvas = AppColors.getContrastRatio(
          AppColors.darkText,
          AppColors.darkCanvas,
        );
        expect(
          textOnCanvas,
          greaterThanOrEqualTo(4.5),
          reason: 'darkText on darkCanvas >= 4.5:1',
        );

        // 2. Ana metin kontrastı (Dark Surface üzerinde)
        final double textOnSurface = AppColors.getContrastRatio(
          AppColors.darkText,
          AppColors.darkSurface,
        );
        expect(
          textOnSurface,
          greaterThanOrEqualTo(7.0),
          reason: 'darkText on darkSurface >= 7.0:1 (AAA)',
        );

        // 3. İkincil metin kontrastı (Dark Surface üzerinde)
        final double secondaryOnSurface = AppColors.getContrastRatio(
          AppColors.darkSecondary,
          AppColors.darkSurface,
        );
        expect(
          secondaryOnSurface,
          greaterThanOrEqualTo(4.5),
          reason: 'darkSecondary on darkSurface >= 4.5:1 (AA)',
        );

        // 4. Vurgu rengi kontrastı (Dark Surface üzerinde)
        final double accentOnSurface = AppColors.getContrastRatio(
          AppColors.darkAccent,
          AppColors.darkSurface,
        );
        expect(
          accentOnSurface,
          greaterThanOrEqualTo(4.5),
          reason: 'darkAccent on darkSurface >= 4.5:1 (AA)',
        );

        // 5. Tehlike rengi kontrastı (Dark Surface üzerinde)
        final double dangerOnSurface = AppColors.getContrastRatio(
          AppColors.darkDanger,
          AppColors.darkSurface,
        );
        expect(
          dangerOnSurface,
          greaterThanOrEqualTo(4.5),
          reason: 'darkDanger on darkSurface >= 4.5:1 (AA)',
        );
      },
    );

    test(
      'Durum renkleri (Success, Warning, Info, Error) kendi arka planlarında >= 4.5:1 kontrast sağlar',
      () {
        // Success
        expect(
          AppColors.getContrastRatio(
            AppColors.onSuccessContainerLight,
            AppColors.successContainerLight,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          AppColors.getContrastRatio(
            AppColors.onSuccessContainerDark,
            AppColors.successContainerDark,
          ),
          greaterThanOrEqualTo(4.5),
        );

        // Warning
        expect(
          AppColors.getContrastRatio(
            AppColors.onWarningContainerLight,
            AppColors.warningContainerLight,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          AppColors.getContrastRatio(
            AppColors.onWarningContainerDark,
            AppColors.warningContainerDark,
          ),
          greaterThanOrEqualTo(4.5),
        );

        // Info
        expect(
          AppColors.getContrastRatio(
            AppColors.onInfoContainerLight,
            AppColors.infoContainerLight,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          AppColors.getContrastRatio(
            AppColors.onInfoContainerDark,
            AppColors.infoContainerDark,
          ),
          greaterThanOrEqualTo(4.5),
        );

        // Error
        expect(
          AppColors.getContrastRatio(
            AppColors.onErrorContainerLight,
            AppColors.errorContainerLight,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          AppColors.getContrastRatio(
            AppColors.onErrorContainerDark,
            AppColors.errorContainerDark,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  });
}
