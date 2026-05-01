import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

const apiBaseUrl = 'http://127.0.0.1:8000';

String get appTenantId {
  final tenant = Uri.base.queryParameters['tenant']?.trim();
  return tenant == null || tenant.isEmpty ? 'acme-store' : tenant;
}

String get completedFixStorageKey => 'productfix.completedFixes.$appTenantId';
const appSettingsStorageKey = 'productfix.uiSettings';

void main() {
  runApp(const ProductFixApp());
}

enum AppLanguage { tr, en }

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.language,
    required this.darkMode,
    required this.onLanguageChanged,
    required this.onDarkModeChanged,
    required super.child,
  });

  final AppLanguage language;
  final bool darkMode;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<bool> onDarkModeChanged;

  static AppScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!;
  }

  String text(String key) {
    return (_translations[key] ?? const {})[language] ?? key;
  }

  AppPalette get colors => AppPalette(darkMode);

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return language != oldWidget.language || darkMode != oldWidget.darkMode;
  }
}

String tr(BuildContext context, String key) => AppScope.of(context).text(key);

class AppPalette {
  const AppPalette(this.dark);

  final bool dark;

  Color get page => dark ? const Color(0xFF101413) : AppColors.page;
  Color get sidebar => dark ? const Color(0xFF151B19) : const Color(0xFFFBFCFA);
  Color get surface => dark ? const Color(0xFF1A211F) : Colors.white;
  Color get surfaceAlt =>
      dark ? const Color(0xFF202925) : const Color(0xFFFCFDFC);
  Color get highlight =>
      dark ? const Color(0xFF2A2419) : const Color(0xFFFFF8E8);
  Color get warningSurface =>
      dark ? const Color(0xFF2A2419) : const Color(0xFFFFF7E8);
  Color get aiSurface =>
      dark ? const Color(0xFF162131) : const Color(0xFFF4F8FE);
  Color get line => dark ? const Color(0xFF33413D) : AppColors.line;
  Color get text => dark ? const Color(0xFFE8F0ED) : const Color(0xFF17211F);
  Color get muted => dark ? const Color(0xFFAAB7B3) : AppColors.muted;
}

const _translations = <String, Map<AppLanguage, String>>{
  'sidebar.subtitle': {
    AppLanguage.tr: 'Ürün sayfası analiz motoru',
    AppLanguage.en: 'Product page analysis engine',
  },
  'settings.language': {AppLanguage.tr: 'Dil', AppLanguage.en: 'Language'},
  'settings.background': {
    AppLanguage.tr: 'Koyu arka plan',
    AppLanguage.en: 'Dark background',
  },
  'nav.dashboard': {AppLanguage.tr: 'Dashboard', AppLanguage.en: 'Dashboard'},
  'nav.products': {AppLanguage.tr: 'Ürünler', AppLanguage.en: 'Products'},
  'nav.returns': {
    AppLanguage.tr: 'İade Analizi',
    AppLanguage.en: 'Return Analysis',
  },
  'nav.fixCenter': {AppLanguage.tr: 'Fix Center', AppLanguage.en: 'Fix Center'},
  'dashboard.subtitle': {
    AppLanguage.tr:
        'Ürün sayfası kalitesi, iade riski ve aksiyon önceliği tek yerde.',
    AppLanguage.en:
        'Product page quality, return risk, and action priority in one place.',
  },
  'dashboard.highRiskEyebrow': {
    AppLanguage.tr: 'Risk listesi',
    AppLanguage.en: 'Risk list',
  },
  'dashboard.highRiskTitle': {
    AppLanguage.tr: 'High Risk Products',
    AppLanguage.en: 'High Risk Products',
  },
  'dashboard.returnReasonsEyebrow': {
    AppLanguage.tr: 'İade sinyalleri',
    AppLanguage.en: 'Return signals',
  },
  'dashboard.returnReasonsTitle': {
    AppLanguage.tr: 'Top Return Reasons',
    AppLanguage.en: 'Top Return Reasons',
  },
  'dashboard.progressEyebrow': {
    AppLanguage.tr: 'Fix ilerleme',
    AppLanguage.en: 'Fix progress',
  },
  'dashboard.progressTitle': {
    AppLanguage.tr: 'Fix Center Progress',
    AppLanguage.en: 'Fix Center Progress',
  },
  'dashboard.completedEyebrow': {
    AppLanguage.tr: 'Tamamlananlar',
    AppLanguage.en: 'Completed',
  },
  'dashboard.completedTitle': {
    AppLanguage.tr: 'Completed Fixes',
    AppLanguage.en: 'Completed Fixes',
  },
  'dashboard.completedEmpty': {
    AppLanguage.tr: 'Henüz tamamlanan fix yok.',
    AppLanguage.en: 'No completed fixes yet.',
  },
  'products.subtitle': {
    AppLanguage.tr:
        'Her ürün için skor, açık iyileştirme listesi, AI açıklama taslağı ve satın alma öncesi uyarı.',
    AppLanguage.en:
        'Score, open fixes, AI description draft, and buyer warning for every product.',
  },
  'returns.subtitle': {
    AppLanguage.tr:
        'İade sebeplerini ürün, kategori ve problem teması bazında grafiklerle oku.',
    AppLanguage.en:
        'Read return reasons by product, category, and problem theme.',
  },
  'fix.subtitle': {
    AppLanguage.tr:
        'Önce parayı kaçıran ürünlere dokun: yüksek iade, düşük skor ve net yapılacaklar.',
    AppLanguage.en:
        'Start with the products leaking revenue: high returns, low scores, clear fixes.',
  },
  'button.csv': {AppLanguage.tr: 'CSV yapıştır', AppLanguage.en: 'Paste CSV'},
  'button.manual': {
    AppLanguage.tr: 'Manuel ürün',
    AppLanguage.en: 'Manual product'
  },
  'button.manualLong': {
    AppLanguage.tr: 'Manuel ürün gir',
    AppLanguage.en: 'Add manually',
  },
  'button.done': {AppLanguage.tr: 'Tamamlandı', AppLanguage.en: 'Done'},
  'button.undo': {AppLanguage.tr: 'Geri al', AppLanguage.en: 'Undo'},
  'button.close': {AppLanguage.tr: 'Kapat', AppLanguage.en: 'Close'},
  'section.priority': {AppLanguage.tr: 'Öncelik', AppLanguage.en: 'Priority'},
  'section.worstProducts': {
    AppLanguage.tr: 'En problemli ürünler',
    AppLanguage.en: 'Most problematic products',
  },
  'section.signal': {
    AppLanguage.tr: 'Sinyal dağılımı',
    AppLanguage.en: 'Signal distribution',
  },
  'section.problemThemes': {
    AppLanguage.tr: 'Ana problem temaları',
    AppLanguage.en: 'Main problem themes',
  },
  'section.funnel': {
    AppLanguage.tr: 'Funnel sağlığı',
    AppLanguage.en: 'Funnel health',
  },
  'section.funnelTitle': {
    AppLanguage.tr: 'Görüntüleme, sepete ekleme ve satın alma akışı',
    AppLanguage.en: 'Views, add-to-cart, and purchase flow',
  },
  'section.themeChart': {
    AppLanguage.tr: 'Tema grafiği',
    AppLanguage.en: 'Theme chart',
  },
  'section.returnSignal': {
    AppLanguage.tr: 'İade sinyali yoğunluğu',
    AppLanguage.en: 'Return signal density',
  },
  'section.productChart': {
    AppLanguage.tr: 'Ürün grafiği',
    AppLanguage.en: 'Product chart',
  },
  'section.productReturn': {
    AppLanguage.tr: 'Ürün bazlı iade oranı',
    AppLanguage.en: 'Return rate by product',
  },
  'section.category': {
    AppLanguage.tr: 'Kategori kırılımı',
    AppLanguage.en: 'Category breakdown',
  },
  'section.categoryRisk': {
    AppLanguage.tr: 'Kategoriye göre risk',
    AppLanguage.en: 'Risk by category',
  },
  'section.matrix': {
    AppLanguage.tr: 'Sebep matrisi',
    AppLanguage.en: 'Reason matrix',
  },
  'section.repeating': {
    AppLanguage.tr: 'Ürünlerde tekrar eden problemler',
    AppLanguage.en: 'Recurring product issues',
  },
  'section.reasonable': {
    AppLanguage.tr: 'Reasonable öncelik',
    AppLanguage.en: 'Reasonable priority',
  },
  'section.today': {
    AppLanguage.tr: 'Bugün yapılacak işler',
    AppLanguage.en: "Today's fixes",
  },
  'empty.doneTitle': {
    AppLanguage.tr: 'Bugün yapılacak iş kalmadı',
    AppLanguage.en: 'No fixes left for today',
  },
  'empty.doneMessage': {
    AppLanguage.tr: 'Tamamlanan fixler ürün kartlarında yeşil olarak görünür.',
    AppLanguage.en: 'Completed fixes appear in green on product cards.',
  },
  'metric.products': {AppLanguage.tr: 'Ürün', AppLanguage.en: 'Products'},
  'metric.avgScore': {
    AppLanguage.tr: 'Ortalama skor',
    AppLanguage.en: 'Average score',
  },
  'metric.highRisk': {
    AppLanguage.tr: 'Yüksek risk',
    AppLanguage.en: 'High risk',
  },
  'metric.biggestLoss': {
    AppLanguage.tr: 'En büyük kayıp',
    AppLanguage.en: 'Biggest leak',
  },
  'product.returnRate': {
    AppLanguage.tr: 'İade oranı',
    AppLanguage.en: 'Return rate',
  },
  'product.aiNoteTile': {
    AppLanguage.tr: 'Önerilen açıklama ve AI yardımcı notu',
    AppLanguage.en: 'Suggested description and AI assistant note',
  },
  'product.details': {AppLanguage.tr: 'Detay', AppLanguage.en: 'Details'},
  'product.beforeAfter': {
    AppLanguage.tr: 'Before / After açıklama preview',
    AppLanguage.en: 'Before / After description preview',
  },
  'product.before': {AppLanguage.tr: 'Before', AppLanguage.en: 'Before'},
  'product.after': {AppLanguage.tr: 'After', AppLanguage.en: 'After'},
  'fix.improvements': {
    AppLanguage.tr: 'Net yapılacak iyileştirmeler',
    AppLanguage.en: 'Clear fixes to make',
  },
  'fix.none': {
    AppLanguage.tr: 'Bu üründe açık fix kalmadı.',
    AppLanguage.en: 'No open fixes left for this product.',
  },
  'fix.goProduct': {
    AppLanguage.tr: 'İlgili ürüne gitmek için tıkla',
    AppLanguage.en: 'Click to open product',
  },
  'ai.description': {
    AppLanguage.tr: 'AI açıklama taslağı',
    AppLanguage.en: 'AI description draft',
  },
  'ai.check': {
    AppLanguage.tr: 'AI kontrol notu',
    AppLanguage.en: 'AI check note'
  },
  'ai.warning': {
    AppLanguage.tr: 'Satın alma öncesi mini uyarı',
    AppLanguage.en: 'Pre-purchase mini warning',
  },
  'fix.count': {AppLanguage.tr: 'aksiyon', AppLanguage.en: 'actions'},
  'fix.boardTitle': {
    AppLanguage.tr: 'Trello tarzı fix panosu',
    AppLanguage.en: 'Trello-style fix board',
  },
  'fix.open': {AppLanguage.tr: 'Open Fixes', AppLanguage.en: 'Open Fixes'},
  'fix.inProgress': {
    AppLanguage.tr: 'In Progress',
    AppLanguage.en: 'In Progress',
  },
  'fix.completed': {AppLanguage.tr: 'Completed', AppLanguage.en: 'Completed'},
  'fix.openEmpty': {
    AppLanguage.tr: 'Açık fix kalmadı.',
    AppLanguage.en: 'No open fixes left.',
  },
  'fix.inProgressEmpty': {
    AppLanguage.tr: 'Devam eden fix yok.',
    AppLanguage.en: 'No fixes in progress.',
  },
  'fix.completedEmpty': {
    AppLanguage.tr: 'Tamamlanan fix yok.',
    AppLanguage.en: 'No completed fixes.',
  },
  'fix.moveInProgress': {
    AppLanguage.tr: 'Başlat',
    AppLanguage.en: 'Start',
  },
  'risk.low': {AppLanguage.tr: 'Düşük risk', AppLanguage.en: 'Low risk'},
  'risk.medium': {AppLanguage.tr: 'Orta risk', AppLanguage.en: 'Medium risk'},
  'risk.high': {AppLanguage.tr: 'Yüksek risk', AppLanguage.en: 'High risk'},
  'chip.conversion': {AppLanguage.tr: 'Dönüşüm', AppLanguage.en: 'Conversion'},
  'chip.cartPurchase': {
    AppLanguage.tr: 'Sepetten satın alma',
    AppLanguage.en: 'Cart to purchase',
  },
  'chip.photo': {AppLanguage.tr: 'Fotoğraf', AppLanguage.en: 'Photo'},
  'funnel.views': {AppLanguage.tr: 'Görüntülenme', AppLanguage.en: 'Views'},
  'funnel.carts': {
    AppLanguage.tr: 'Sepete ekleme',
    AppLanguage.en: 'Add to cart',
  },
  'funnel.purchases': {
    AppLanguage.tr: 'Satın alma',
    AppLanguage.en: 'Purchases',
  },
  'funnel.returns': {AppLanguage.tr: 'İade', AppLanguage.en: 'Returns'},
  'button.cancel': {AppLanguage.tr: 'Vazgeç', AppLanguage.en: 'Cancel'},
  'button.analyze': {AppLanguage.tr: 'Analiz et', AppLanguage.en: 'Analyze'},
  'csv.help': {
    AppLanguage.tr:
        'Aynı kolon başlıklarıyla ürünleri yapıştır. Veriler analiz hattına alınır.',
    AppLanguage.en:
        'Paste products with the same column headers. The data will enter the analysis pipeline.',
  },
  'csv.error': {
    AppLanguage.tr: 'CSV okunamadı. Başlıkları ve virgülleri kontrol et.',
    AppLanguage.en: 'CSV could not be read. Check the headers and commas.',
  },
  'manual.title': {
    AppLanguage.tr: 'Manuel ürün girişi',
    AppLanguage.en: 'Manual product entry',
  },
  'manual.productName': {
    AppLanguage.tr: 'Ürün adı',
    AppLanguage.en: 'Product name'
  },
  'manual.category': {AppLanguage.tr: 'Kategori', AppLanguage.en: 'Category'},
  'manual.views': {AppLanguage.tr: 'Görüntülenme', AppLanguage.en: 'Views'},
  'manual.addToCart': {
    AppLanguage.tr: 'Sepete ekleme',
    AppLanguage.en: 'Add to cart',
  },
  'manual.purchases': {
    AppLanguage.tr: 'Satın alma',
    AppLanguage.en: 'Purchases'
  },
  'manual.returns': {AppLanguage.tr: 'İade', AppLanguage.en: 'Returns'},
  'manual.photoCount': {
    AppLanguage.tr: 'Fotoğraf sayısı',
    AppLanguage.en: 'Photo count',
  },
  'manual.description': {
    AppLanguage.tr: 'Açıklama',
    AppLanguage.en: 'Description'
  },
  'manual.reviews': {AppLanguage.tr: 'Yorumlar', AppLanguage.en: 'Reviews'},
  'manual.returnReasons': {
    AppLanguage.tr: 'İade nedenleri',
    AppLanguage.en: 'Return reasons',
  },
  'manual.sizeChart': {
    AppLanguage.tr: 'Beden tablosu var',
    AppLanguage.en: 'Has size chart',
  },
  'manual.modelPhoto': {
    AppLanguage.tr: 'Kullanım/model fotoğrafı var',
    AppLanguage.en: 'Has use/model photo',
  },
  'manual.convert': {
    AppLanguage.tr: 'CSV’ye çevir ve analiz et',
    AppLanguage.en: 'Convert to CSV and analyze',
  },
  'validation.required': {
    AppLanguage.tr: 'Zorunlu',
    AppLanguage.en: 'Required'
  },
};

class ProductFixApp extends StatelessWidget {
  const ProductFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ProductFix AI',
      theme: _buildTheme(false),
      home: const ProductFixShell(),
    );
  }
}

class ProductFixShell extends StatefulWidget {
  const ProductFixShell({super.key});

  @override
  State<ProductFixShell> createState() => _ProductFixShellState();
}

class _ProductFixShellState extends State<ProductFixShell> {
  AppSection selectedSection = AppSection.dashboard;
  String? highlightedSku;
  AppLanguage language = AppLanguage.tr;
  bool darkMode = false;
  final List<RawProduct> rawProducts = [...sampleProducts];
  final Set<String> completedFixIds = {};
  final Set<String> completedFixKeys = {};
  final Set<String> inProgressFixIds = {};
  final Set<String> inProgressFixKeys = {};

  List<ProductInsight> get products {
    return rawProducts.map(analyzeProduct).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
  }

  @override
  void initState() {
    super.initState();
    _loadUiSettings();
    _loadCompletedFixes();
  }

  @override
  Widget build(BuildContext context) {
    final insights = products;
    final summary = Summary.fromProducts(insights);
    final themes = themeCounts(insights);
    final actions = buildFixActions(insights);
    final completedActions = actions.where(_isFixCompleted).toList();
    final inProgressActions = actions
        .where((action) => _isFixInProgress(action) && !_isFixCompleted(action))
        .toList();
    final openActions = actions
        .where(
            (action) => !_isFixCompleted(action) && !_isFixInProgress(action))
        .toList();

    final palette = AppPalette(darkMode);
    return AppScope(
      language: language,
      darkMode: darkMode,
      onLanguageChanged: _setLanguage,
      onDarkModeChanged: _setDarkMode,
      child: Theme(
        data: _buildTheme(darkMode),
        child: Scaffold(
          backgroundColor: palette.page,
          body: SafeArea(
            child: Row(
              children: [
                _Sidebar(
                  selectedSection: selectedSection,
                  onSelected: (section) {
                    setState(() {
                      selectedSection = section;
                      highlightedSku = null;
                    });
                  },
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _SectionBody(
                      key: ValueKey(selectedSection),
                      selectedSection: selectedSection,
                      products: insights,
                      summary: summary,
                      themes: themes,
                      openActions: openActions,
                      inProgressActions: inProgressActions,
                      completedActions: completedActions,
                      actions: openActions,
                      completedFixIds: completedFixIds,
                      completedFixKeys: completedFixKeys,
                      highlightedSku: highlightedSku,
                      onAddManual: _openManualProductDialog,
                      onPasteCsv: _openCsvDialog,
                      onActionTap: (action) {
                        setState(() {
                          selectedSection = AppSection.products;
                          highlightedSku = action.sku;
                        });
                      },
                      onToggleFix: _toggleFix,
                      onStartFix: _startFix,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _loadUiSettings() {
    final raw = html.window.localStorage[appSettingsStorageKey];
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      language = decoded['language'] == 'en' ? AppLanguage.en : AppLanguage.tr;
      darkMode = decoded['darkMode'] == true;
    } catch (_) {
      html.window.localStorage.remove(appSettingsStorageKey);
    }
  }

  void _setLanguage(AppLanguage value) {
    setState(() => language = value);
    _saveUiSettings();
  }

  void _setDarkMode(bool value) {
    setState(() => darkMode = value);
    _saveUiSettings();
  }

  void _saveUiSettings() {
    html.window.localStorage[appSettingsStorageKey] = jsonEncode({
      'language': language.name,
      'darkMode': darkMode,
    });
  }

  Future<void> _openManualProductDialog() async {
    final product = await showDialog<RawProduct>(
      context: context,
      builder: (context) => const _ManualProductDialog(),
    );

    if (product == null) return;

    setState(() {
      rawProducts.add(product);
      selectedSection = AppSection.products;
      highlightedSku = product.sku;
    });

    if (!mounted) return;
    final csvLine = productToCsvLine(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Ürün CSV satırına dönüştürüldü ve analiz edildi: $csvLine'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openCsvDialog() async {
    final rows = await showDialog<List<RawProduct>>(
      context: context,
      builder: (context) => const _CsvPasteDialog(),
    );

    if (rows == null || rows.isEmpty) return;

    setState(() {
      rawProducts.addAll(rows);
      selectedSection = AppSection.products;
      highlightedSku = rows.first.sku;
    });
  }

  void _toggleFix(FixAction action) {
    final wasCompleted = _isFixCompleted(action);
    setState(() {
      if (wasCompleted) {
        completedFixIds.remove(action.id);
        completedFixKeys.remove(action.matchKey);
      } else {
        completedFixIds.add(action.id);
        completedFixKeys.add(action.matchKey);
        inProgressFixIds.remove(action.id);
        inProgressFixKeys.remove(action.matchKey);
      }
    });

    _saveCompletedFixes();
    unawaited(_syncFixCompletion(action, completed: !wasCompleted));
  }

  bool _isFixCompleted(FixAction action) {
    return completedFixIds.contains(action.id) ||
        completedFixKeys.contains(action.matchKey);
  }

  void _startFix(FixAction action) {
    setState(() {
      if (_isFixInProgress(action)) {
        inProgressFixIds.remove(action.id);
        inProgressFixKeys.remove(action.matchKey);
      } else {
        inProgressFixIds.add(action.id);
        inProgressFixKeys.add(action.matchKey);
      }
    });
  }

  bool _isFixInProgress(FixAction action) {
    return inProgressFixIds.contains(action.id) ||
        inProgressFixKeys.contains(action.matchKey);
  }

  Future<void> _loadCompletedFixes() async {
    _loadCompletedFixesFromBrowser();
    await _loadCompletedFixesFromApi();
  }

  void _loadCompletedFixesFromBrowser() {
    final raw = html.window.localStorage[completedFixStorageKey];
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      setState(() {
        if (decoded is Map<String, dynamic>) {
          completedFixIds
              .addAll((decoded['ids'] as List? ?? []).cast<String>());
          completedFixKeys
              .addAll((decoded['keys'] as List? ?? []).cast<String>());
        } else if (decoded is List) {
          for (final item in decoded) {
            final fix = CompletedFix.fromJson(item as Map<String, dynamic>);
            completedFixIds.add(fix.id);
            if (fix.matchKey.isNotEmpty) completedFixKeys.add(fix.matchKey);
          }
        }
      });
    } catch (_) {
      html.window.localStorage.remove(completedFixStorageKey);
    }
  }

  Future<void> _loadCompletedFixesFromApi() async {
    try {
      final fixes = await ProductFixApi.fetchCompletedFixes();
      if (!mounted) return;
      setState(() {
        for (final fix in fixes) {
          completedFixIds.add(fix.id);
          completedFixKeys.add(fix.matchKey);
        }
      });
      _saveCompletedFixes();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Backend tamamlanan fix listesi okunamadı; tarayıcı kaydı kullanılıyor.'),
        ),
      );
    }
  }

  Future<void> _syncFixCompletion(
    FixAction action, {
    required bool completed,
  }) async {
    try {
      await ProductFixApi.setFixCompleted(action, completed: completed);
      await _loadCompletedFixesFromApi();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Fix yerelde kaydedildi, backend bağlantısı kurulunca tekrar senkronlanmalı.'),
        ),
      );
    }
  }

  void _saveCompletedFixes() {
    final payload = {
      'ids': completedFixIds.toList()..sort(),
      'keys': completedFixKeys.toList()..sort(),
    };
    html.window.localStorage[completedFixStorageKey] = jsonEncode(payload);
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    super.key,
    required this.selectedSection,
    required this.products,
    required this.summary,
    required this.themes,
    required this.openActions,
    required this.inProgressActions,
    required this.completedActions,
    required this.actions,
    required this.completedFixIds,
    required this.completedFixKeys,
    required this.highlightedSku,
    required this.onAddManual,
    required this.onPasteCsv,
    required this.onActionTap,
    required this.onToggleFix,
    required this.onStartFix,
  });

  final AppSection selectedSection;
  final List<ProductInsight> products;
  final Summary summary;
  final List<ThemeCount> themes;
  final List<FixAction> openActions;
  final List<FixAction> inProgressActions;
  final List<FixAction> completedActions;
  final List<FixAction> actions;
  final Set<String> completedFixIds;
  final Set<String> completedFixKeys;
  final String? highlightedSku;
  final VoidCallback onAddManual;
  final VoidCallback onPasteCsv;
  final ValueChanged<FixAction> onActionTap;
  final ValueChanged<FixAction> onToggleFix;
  final ValueChanged<FixAction> onStartFix;

  @override
  Widget build(BuildContext context) {
    final child = switch (selectedSection) {
      AppSection.dashboard => DashboardView(
          products: products,
          summary: summary,
          themes: themes,
          openActions: openActions,
          inProgressActions: inProgressActions,
          completedActions: completedActions,
          onAddManual: onAddManual,
          onPasteCsv: onPasteCsv,
        ),
      AppSection.products => ProductsView(
          products: products,
          highlightedSku: highlightedSku,
          completedFixIds: completedFixIds,
          completedFixKeys: completedFixKeys,
          onToggleFix: onToggleFix,
          onAddManual: onAddManual,
          onPasteCsv: onPasteCsv,
        ),
      AppSection.returns => ReturnsView(products: products, themes: themes),
      AppSection.fixCenter => FixCenterView(
          actions: actions,
          inProgressActions: inProgressActions,
          completedActions: completedActions,
          onActionTap: onActionTap,
          onToggleFix: onToggleFix,
          onStartFix: onStartFix,
        ),
    };

    return child;
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.products,
    required this.summary,
    required this.themes,
    required this.openActions,
    required this.inProgressActions,
    required this.completedActions,
    required this.onAddManual,
    required this.onPasteCsv,
  });

  final List<ProductInsight> products;
  final Summary summary;
  final List<ThemeCount> themes;
  final List<FixAction> openActions;
  final List<FixAction> inProgressActions;
  final List<FixAction> completedActions;
  final VoidCallback onAddManual;
  final VoidCallback onPasteCsv;

  @override
  Widget build(BuildContext context) {
    final worstProducts = products.take(4).toList();

    return _Page(
      title: 'Dashboard',
      subtitle: tr(context, 'dashboard.subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: onPasteCsv,
          icon: const Icon(Icons.table_chart_outlined),
          label: Text(tr(context, 'button.csv')),
        ),
        FilledButton.icon(
          onPressed: onAddManual,
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'button.manual')),
        ),
      ],
      children: [
        _MetricGrid(summary: summary),
        const SizedBox(height: 16),
        _DashboardDemoGrid(
          products: products,
          themes: themes,
          openActions: openActions,
          inProgressActions: inProgressActions,
          completedActions: completedActions,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final widgets = [
              _PanelSection(
                eyebrow: tr(context, 'section.priority'),
                title: tr(context, 'section.worstProducts'),
                child: Column(
                  children: [
                    for (final product in worstProducts)
                      _MiniProductRow(product: product, showCategory: true),
                  ],
                ),
              ),
              _PanelSection(
                eyebrow: tr(context, 'section.signal'),
                title: tr(context, 'section.problemThemes'),
                child: Column(
                  children: [
                    for (final theme in themes)
                      _HorizontalBar(
                          label: translateIssueLabel(context, theme.rule),
                          value: theme.count,
                          max: summary.totalProducts),
                  ],
                ),
              ),
            ];

            if (narrow) {
              return Column(children: [
                widgets[0],
                const SizedBox(height: 16),
                widgets[1]
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: widgets[0]),
                const SizedBox(width: 16),
                Expanded(child: widgets[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _PanelSection(
          eyebrow: tr(context, 'section.funnel'),
          title: tr(context, 'section.funnelTitle'),
          child: _FunnelChart(products: products),
        ),
      ],
    );
  }
}

class ProductsView extends StatelessWidget {
  const ProductsView({
    super.key,
    required this.products,
    required this.highlightedSku,
    required this.completedFixIds,
    required this.completedFixKeys,
    required this.onToggleFix,
    required this.onAddManual,
    required this.onPasteCsv,
  });

  final List<ProductInsight> products;
  final String? highlightedSku;
  final Set<String> completedFixIds;
  final Set<String> completedFixKeys;
  final ValueChanged<FixAction> onToggleFix;
  final VoidCallback onAddManual;
  final VoidCallback onPasteCsv;

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: tr(context, 'nav.products'),
      subtitle: tr(context, 'products.subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: onPasteCsv,
          icon: const Icon(Icons.table_rows_outlined),
          label: Text(tr(context, 'button.csv')),
        ),
        FilledButton.icon(
          onPressed: onAddManual,
          icon: const Icon(Icons.add_box_outlined),
          label: Text(tr(context, 'button.manualLong')),
        ),
      ],
      children: [
        for (final product in products)
          _ProductCard(
            product: product,
            highlighted: product.sku == highlightedSku,
            completedFixIds: completedFixIds,
            completedFixKeys: completedFixKeys,
            onToggleFix: onToggleFix,
          ),
      ],
    );
  }
}

class ReturnsView extends StatelessWidget {
  const ReturnsView({super.key, required this.products, required this.themes});

  final List<ProductInsight> products;
  final List<ThemeCount> themes;

  @override
  Widget build(BuildContext context) {
    final maxReturn = products.fold<double>(0,
        (max, product) => product.returnRate > max ? product.returnRate : max);

    return _Page(
      title: tr(context, 'nav.returns'),
      subtitle: tr(context, 'returns.subtitle'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 940;
            final left = _PanelSection(
              eyebrow: tr(context, 'section.themeChart'),
              title: tr(context, 'section.returnSignal'),
              child: Column(
                children: [
                  for (final theme in themes)
                    _HorizontalBar(
                      label: translateIssueLabel(context, theme.rule),
                      value: theme.count,
                      max: products.length,
                      color: issueColor(theme.rule.key),
                    ),
                ],
              ),
            );
            final right = _PanelSection(
              eyebrow: tr(context, 'section.productChart'),
              title: tr(context, 'section.productReturn'),
              child: Column(
                children: [
                  for (final product in products)
                    _HorizontalBar(
                      label: product.name,
                      value: (product.returnRate * 100).round(),
                      max: (maxReturn * 100).ceil().clamp(1, 100),
                      suffix: '%',
                      color:
                          scoreColor(100 - (product.returnRate * 200).round()),
                    ),
                ],
              ),
            );

            if (narrow) {
              return Column(
                  children: [left, const SizedBox(height: 16), right]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                Expanded(child: right)
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 940;
            final charts = [
              _PanelSection(
                eyebrow: tr(context, 'section.category'),
                title: tr(context, 'section.categoryRisk'),
                child: _CategoryRiskChart(products: products),
              ),
              _PanelSection(
                eyebrow: tr(context, 'section.matrix'),
                title: tr(context, 'section.repeating'),
                child: _IssueMatrix(products: products),
              ),
            ];

            if (narrow) {
              return Column(
                  children: [charts[0], const SizedBox(height: 16), charts[1]]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: charts[0]),
                const SizedBox(width: 16),
                Expanded(child: charts[1])
              ],
            );
          },
        ),
      ],
    );
  }
}

class FixCenterView extends StatelessWidget {
  const FixCenterView({
    super.key,
    required this.actions,
    required this.inProgressActions,
    required this.completedActions,
    required this.onActionTap,
    required this.onToggleFix,
    required this.onStartFix,
  });

  final List<FixAction> actions;
  final List<FixAction> inProgressActions;
  final List<FixAction> completedActions;
  final ValueChanged<FixAction> onActionTap;
  final ValueChanged<FixAction> onToggleFix;
  final ValueChanged<FixAction> onStartFix;

  @override
  Widget build(BuildContext context) {
    final total =
        actions.length + inProgressActions.length + completedActions.length;
    return _Page(
      title: 'Fix Center',
      subtitle: tr(context, 'fix.subtitle'),
      children: [
        _PanelSection(
          eyebrow: tr(context, 'section.reasonable'),
          title: tr(context, 'fix.boardTitle'),
          trailing: _Pill('$total ${tr(context, 'fix.count')}',
              color: AppColors.blue),
          child: total == 0
              ? _EmptyState(
                  icon: Icons.verified_outlined,
                  title: tr(context, 'empty.doneTitle'),
                  message: tr(context, 'empty.doneMessage'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 980;
                    final columns = [
                      _FixBoardColumn(
                        title: tr(context, 'fix.open'),
                        color: AppColors.blue,
                        actions: actions,
                        emptyText: tr(context, 'fix.openEmpty'),
                        itemBuilder: (action) => _FixActionCard(
                          action: action,
                          onTap: () => onActionTap(action),
                          onStart: () => onStartFix(action),
                          onToggle: () => onToggleFix(action),
                        ),
                      ),
                      _FixBoardColumn(
                        title: tr(context, 'fix.inProgress'),
                        color: AppColors.amber,
                        actions: inProgressActions,
                        emptyText: tr(context, 'fix.inProgressEmpty'),
                        itemBuilder: (action) => _FixActionCard(
                          action: action,
                          onTap: () => onActionTap(action),
                          onToggle: () => onToggleFix(action),
                        ),
                      ),
                      _FixBoardColumn(
                        title: tr(context, 'fix.completed'),
                        color: AppColors.green,
                        actions: completedActions,
                        emptyText: tr(context, 'fix.completedEmpty'),
                        itemBuilder: (action) => _FixActionCard(
                          action: action,
                          onTap: () => onActionTap(action),
                          onToggle: () => onToggleFix(action),
                          completed: true,
                        ),
                      ),
                    ];

                    if (narrow) {
                      return Column(
                        children: [
                          for (final column in columns) ...[
                            column,
                            const SizedBox(height: 14),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: columns[0]),
                        const SizedBox(width: 14),
                        Expanded(child: columns[1]),
                        const SizedBox(width: 14),
                        Expanded(child: columns[2]),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FixBoardColumn extends StatelessWidget {
  const _FixBoardColumn({
    required this.title,
    required this.color,
    required this.actions,
    required this.emptyText,
    required this.itemBuilder,
  });

  final String title;
  final Color color;
  final List<FixAction> actions;
  final String emptyText;
  final Widget Function(FixAction action) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill('${actions.length}', color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (actions.isEmpty)
            Text(emptyText, style: TextStyle(color: palette.muted)),
          for (final action in actions) itemBuilder(action),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedSection, required this.onSelected});

  final AppSection selectedSection;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final palette = scope.colors;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.sidebar,
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PF',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ProductFix AI',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      tr(context, 'sidebar.subtitle'),
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.tr, label: Text('TR')),
              ButtonSegment(value: AppLanguage.en, label: Text('EN')),
            ],
            selected: {scope.language},
            onSelectionChanged: (values) {
              scope.onLanguageChanged(values.first);
            },
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(tr(context, 'settings.background')),
            value: scope.darkMode,
            onChanged: scope.onDarkModeChanged,
          ),
          const SizedBox(height: 18),
          for (final section in AppSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                selected: section == selectedSection,
                selectedTileColor: scope.darkMode
                    ? AppColors.green.withValues(alpha: 0.18)
                    : AppColors.greenSoft,
                dense: true,
                leading: Icon(section.icon, size: 20),
                title: Text(section.label(context)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () => onSelected(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    this.actions = const [],
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                        color: palette.muted, fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        tr(context, 'metric.products'),
        '${summary.totalProducts}',
        Icons.inventory_2_outlined
      ),
      (
        tr(context, 'metric.avgScore'),
        '${summary.averageScore}',
        Icons.speed_outlined
      ),
      (
        tr(context, 'metric.highRisk'),
        '${summary.highRiskProducts}',
        Icons.warning_amber_outlined
      ),
      (
        tr(context, 'metric.biggestLoss'),
        translateIssueLabelText(context, summary.topProblem),
        Icons.insights_outlined
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620
            ? 1
            : constraints.maxWidth < 980
                ? 2
                : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 120,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _Panel(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    _IconBox(icon: metric.$3),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metric.$1,
                              style: const TextStyle(color: AppColors.muted)),
                          const Spacer(),
                          Text(
                            metric.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DashboardDemoGrid extends StatelessWidget {
  const _DashboardDemoGrid({
    required this.products,
    required this.themes,
    required this.openActions,
    required this.inProgressActions,
    required this.completedActions,
  });

  final List<ProductInsight> products;
  final List<ThemeCount> themes;
  final List<FixAction> openActions;
  final List<FixAction> inProgressActions;
  final List<FixAction> completedActions;

  @override
  Widget build(BuildContext context) {
    final highRisk = products
        .where((product) => product.risk == RiskLevel.high)
        .take(3)
        .toList();
    final totalFixes =
        openActions.length + inProgressActions.length + completedActions.length;
    final completedPercent = totalFixes == 0
        ? 0
        : ((completedActions.length / totalFixes) * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 1040;
        final cards = [
          _PanelSection(
            eyebrow: tr(context, 'dashboard.highRiskEyebrow'),
            title: tr(context, 'dashboard.highRiskTitle'),
            child: Column(
              children: [
                for (final product in highRisk)
                  _MiniProductRow(product: product, showCategory: true),
              ],
            ),
          ),
          _PanelSection(
            eyebrow: tr(context, 'dashboard.returnReasonsEyebrow'),
            title: tr(context, 'dashboard.returnReasonsTitle'),
            child: Column(
              children: [
                for (final theme in themes.take(4))
                  _HorizontalBar(
                    label: translateIssueLabel(context, theme.rule),
                    value: theme.count,
                    max: products.length,
                    color: issueColor(theme.rule.key),
                  ),
              ],
            ),
          ),
          _PanelSection(
            eyebrow: tr(context, 'dashboard.progressEyebrow'),
            title: tr(context, 'dashboard.progressTitle'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HorizontalBar(
                  label: tr(context, 'fix.completed'),
                  value: completedPercent,
                  max: 100,
                  suffix: '%',
                  color: AppColors.green,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill('${openActions.length} ${tr(context, 'fix.open')}',
                        color: AppColors.blue),
                    _Pill(
                        '${inProgressActions.length} ${tr(context, 'fix.inProgress')}',
                        color: AppColors.amber),
                    _Pill(
                        '${completedActions.length} ${tr(context, 'fix.completed')}',
                        color: AppColors.green),
                  ],
                ),
              ],
            ),
          ),
          _PanelSection(
            eyebrow: tr(context, 'dashboard.completedEyebrow'),
            title: tr(context, 'dashboard.completedTitle'),
            child: completedActions.isEmpty
                ? Text(
                    tr(context, 'dashboard.completedEmpty'),
                    style: TextStyle(color: AppScope.of(context).colors.muted),
                  )
                : Column(
                    children: [
                      for (final action in completedActions.take(3))
                        _CompactFixRow(action: action),
                    ],
                  ),
          ),
        ];

        if (narrow) {
          return Column(
            children: [
              for (final card in cards) ...[card, const SizedBox(height: 16)],
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 16),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 16),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.highlighted,
    required this.completedFixIds,
    required this.completedFixKeys,
    required this.onToggleFix,
  });

  final ProductInsight product;
  final bool highlighted;
  final Set<String> completedFixIds;
  final Set<String> completedFixKeys;
  final ValueChanged<FixAction> onToggleFix;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(product.score);
    final palette = AppScope.of(context).colors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? palette.highlight : palette.surfaceAlt,
        border: Border.all(
            color: highlighted ? AppColors.amber : palette.line,
            width: highlighted ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScoreBadge(score: product.score, color: color),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 500,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.sku,
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800),
                          ),
                          Text(
                            product.name,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    _RiskPill(risk: product.risk),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: product.score / 100,
                    color: color,
                    backgroundColor: const Color(0xFFE6ECE8),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                        '${tr(context, 'chip.conversion')}: ${percent(product.conversionRate)}'),
                    _Chip(
                        '${tr(context, 'chip.cartPurchase')}: ${percent(product.cartConversionRate)}'),
                    _Chip(
                        '${tr(context, 'product.returnRate')}: ${percent(product.returnRate)}'),
                    _Chip(
                        '${tr(context, 'chip.photo')}: ${product.photoCount}'),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) =>
                            _ProductDetailDialog(product: product),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 17),
                      label: Text(tr(context, 'product.details')),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ImprovementBox(
                  product: product,
                  completedFixIds: completedFixIds,
                  completedFixKeys: completedFixKeys,
                  onToggleFix: onToggleFix,
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 18, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Text(
                        tr(context, 'product.aiNoteTile'),
                        style: const TextStyle(
                            color: AppColors.blue, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  children: [
                    _AiSuggestion(product: product),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImprovementBox extends StatelessWidget {
  const _ImprovementBox({
    required this.product,
    required this.completedFixIds,
    required this.completedFixKeys,
    required this.onToggleFix,
  });

  final ProductInsight product;
  final Set<String> completedFixIds;
  final Set<String> completedFixKeys;
  final ValueChanged<FixAction> onToggleFix;

  @override
  Widget build(BuildContext context) {
    final items = product.fixActions.take(4).toList();
    final palette = AppScope.of(context).colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.warningSurface,
        border: Border.all(color: const Color(0xFFFFD28C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.priority_high, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(tr(context, 'fix.improvements'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          for (final action in items)
            _InlineFixItem(
              action: action,
              completed: completedFixIds.contains(action.id) ||
                  completedFixKeys.contains(action.matchKey),
              onToggle: () => onToggleFix(action),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tr(context, 'fix.none'),
                style: const TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineFixItem extends StatelessWidget {
  const _InlineFixItem({
    required this.action,
    required this.completed,
    required this.onToggle,
  });

  final FixAction action;
  final bool completed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.green.withValues(alpha: 0.1)
            : palette.surface,
        border: Border.all(
            color: completed ? AppColors.green : const Color(0xFFFFD28C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? AppColors.green : AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              translateFixText(context, action.title),
              style: TextStyle(
                height: 1.35,
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed ? AppColors.muted : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onToggle,
            child: Text(completed
                ? tr(context, 'button.undo')
                : tr(context, 'button.done')),
          ),
        ],
      ),
    );
  }
}

class _AiSuggestion extends StatelessWidget {
  const _AiSuggestion({required this.product});

  final ProductInsight product;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blueSoft),
        borderRadius: BorderRadius.circular(8),
        color: palette.aiSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'ai.description'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(product.suggestedDescription,
              style: TextStyle(color: palette.muted, height: 1.55)),
          const SizedBox(height: 12),
          Text(tr(context, 'ai.check'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(product.aiAssistantNote,
              style: TextStyle(color: palette.muted, height: 1.55)),
          const SizedBox(height: 12),
          Text(tr(context, 'ai.warning'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(product.buyerWarning,
              style: TextStyle(color: palette.muted, height: 1.55)),
        ],
      ),
    );
  }
}

class _ProductDetailDialog extends StatelessWidget {
  const _ProductDetailDialog({required this.product});

  final ProductInsight product;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(product.name)),
          _RiskPill(risk: product.risk),
        ],
      ),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip('SKU: ${product.sku}'),
                  _Chip('${tr(context, 'metric.avgScore')}: ${product.score}'),
                  _Chip(
                      '${tr(context, 'product.returnRate')}: ${percent(product.returnRate)}'),
                ],
              ),
              const SizedBox(height: 18),
              Text(tr(context, 'product.beforeAfter'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 720;
                  final before = _DescriptionPreview(
                    title: tr(context, 'product.before'),
                    text: product.raw.description,
                    color: AppColors.red,
                  );
                  final after = _DescriptionPreview(
                    title: tr(context, 'product.after'),
                    text: product.suggestedDescription,
                    color: AppColors.green,
                  );
                  if (narrow) {
                    return Column(
                      children: [before, const SizedBox(height: 12), after],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: before),
                      const SizedBox(width: 12),
                      Expanded(child: after),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(tr(context, 'fix.improvements'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final action in product.fixActions.take(5))
                _CompactFixRow(action: action),
              const SizedBox(height: 12),
              Text(product.buyerWarning,
                  style: TextStyle(color: palette.muted, height: 1.45)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'button.close')),
        ),
      ],
    );
  }
}

class _DescriptionPreview extends StatelessWidget {
  const _DescriptionPreview({
    required this.title,
    required this.text,
    required this.color,
  });

  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(text.isEmpty ? '-' : text,
              style: TextStyle(color: palette.text, height: 1.5)),
        ],
      ),
    );
  }
}

class _CompactFixRow extends StatelessWidget {
  const _CompactFixRow({required this.action});

  final FixAction action;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.task_alt, size: 18, color: riskColor(action.risk)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              translateFixText(context, action.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixActionCard extends StatelessWidget {
  const _FixActionCard({
    required this.action,
    required this.onTap,
    required this.onToggle,
    this.onStart,
    this.completed = false,
  });

  final FixAction action;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onStart;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(8),
            color: palette.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(icon: Icons.task_alt, color: riskColor(action.risk)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(translateFixText(context, action.title),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(action.detail,
                        style: TextStyle(color: palette.muted, height: 1.45)),
                    const SizedBox(height: 8),
                    Text(tr(context, 'fix.goProduct'),
                        style: TextStyle(
                            color: riskColor(action.risk),
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (onStart != null)
                          TextButton.icon(
                            onPressed: onStart,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(tr(context, 'fix.moveInProgress')),
                          ),
                        TextButton.icon(
                          onPressed: onToggle,
                          icon: Icon(
                            completed ? Icons.undo : Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: Text(completed
                              ? tr(context, 'button.undo')
                              : tr(context, 'button.done')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RiskPill(risk: action.risk),
                  const SizedBox(height: 8),
                  Text('${action.score}/100',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.green),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ManualProductDialog extends StatefulWidget {
  const _ManualProductDialog();

  @override
  State<_ManualProductDialog> createState() => _ManualProductDialogState();
}

class _ManualProductDialogState extends State<_ManualProductDialog> {
  final formKey = GlobalKey<FormState>();
  final sku = TextEditingController(text: 'NEW-001');
  final name = TextEditingController();
  final category = TextEditingController(text: 'Giyim');
  final views = TextEditingController(text: '1000');
  final addToCart = TextEditingController(text: '120');
  final purchases = TextEditingController(text: '30');
  final returns = TextEditingController(text: '5');
  final description = TextEditingController();
  final reviews = TextEditingController();
  final returnReasons = TextEditingController();
  final photoCount = TextEditingController(text: '3');
  bool hasSizeChart = false;
  bool hasModelPhoto = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'manual.title')),
      content: SizedBox(
        width: 760,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Field(controller: sku, label: 'SKU'),
                    _Field(
                        controller: name,
                        label: tr(context, 'manual.productName'),
                        required: true),
                    _Field(
                        controller: category,
                        label: tr(context, 'manual.category')),
                    _Field(
                        controller: views,
                        label: tr(context, 'manual.views'),
                        numeric: true),
                    _Field(
                        controller: addToCart,
                        label: tr(context, 'manual.addToCart'),
                        numeric: true),
                    _Field(
                        controller: purchases,
                        label: tr(context, 'manual.purchases'),
                        numeric: true),
                    _Field(
                        controller: returns,
                        label: tr(context, 'manual.returns'),
                        numeric: true),
                    _Field(
                        controller: photoCount,
                        label: tr(context, 'manual.photoCount'),
                        numeric: true),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                    controller: description,
                    label: tr(context, 'manual.description'),
                    wide: true,
                    maxLines: 3),
                const SizedBox(height: 12),
                _Field(
                    controller: reviews,
                    label: tr(context, 'manual.reviews'),
                    wide: true,
                    maxLines: 3),
                const SizedBox(height: 12),
                _Field(
                    controller: returnReasons,
                    label: tr(context, 'manual.returnReasons'),
                    wide: true,
                    maxLines: 3),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: hasSizeChart,
                  onChanged: (value) =>
                      setState(() => hasSizeChart = value ?? false),
                  title: Text(tr(context, 'manual.sizeChart')),
                ),
                CheckboxListTile(
                  value: hasModelPhoto,
                  onChanged: (value) =>
                      setState(() => hasModelPhoto = value ?? false),
                  title: Text(tr(context, 'manual.modelPhoto')),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'button.cancel'))),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              RawProduct(
                sku: sku.text.trim(),
                name: name.text.trim(),
                category: category.text.trim(),
                views: intValue(views.text),
                addToCart: intValue(addToCart.text),
                purchases: intValue(purchases.text),
                returns: intValue(returns.text),
                description: description.text.trim(),
                reviews: reviews.text.trim(),
                returnReasons: returnReasons.text.trim(),
                photoCount: intValue(photoCount.text),
                hasSizeChart: hasSizeChart,
                hasModelPhoto: hasModelPhoto,
              ),
            );
          },
          child: Text(tr(context, 'manual.convert')),
        ),
      ],
    );
  }
}

class _CsvPasteDialog extends StatefulWidget {
  const _CsvPasteDialog();

  @override
  State<_CsvPasteDialog> createState() => _CsvPasteDialogState();
}

class _CsvPasteDialogState extends State<_CsvPasteDialog> {
  final controller = TextEditingController(text: sampleCsv);
  String? error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'button.csv')),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'csv.help')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 12,
              maxLines: 16,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'button.cancel'))),
        FilledButton(
          onPressed: () {
            final rows = parseCsvProducts(controller.text);
            if (rows.isEmpty) {
              setState(() => error = tr(context, 'csv.error'));
              return;
            }
            Navigator.pop(context, rows);
          },
          child: Text(tr(context, 'button.analyze')),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.required = false,
    this.numeric = false,
    this.wide = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool numeric;
  final bool wide;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? double.infinity : 170,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return tr(context, 'validation.required');
          }
          return null;
        },
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Eyebrow(eyebrow),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C2D2A)
                .withValues(alpha: palette.dark ? 0.28 : 0.09),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.green,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.color = AppColors.green});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 7),
      ),
      child: Text('$score',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.risk});

  final RiskLevel risk;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(risk);
    return _Pill(risk.label(context), color: color);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(8),
        color: palette.surface,
      ),
      child: Text(text, style: TextStyle(color: palette.muted, fontSize: 13)),
    );
  }
}

class _MiniProductRow extends StatelessWidget {
  const _MiniProductRow({required this.product, required this.showCategory});

  final ProductInsight product;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final palette = AppScope.of(context).colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ScoreBadge(score: product.score, color: scoreColor(product.score)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  showCategory
                      ? '${translateCategory(context, product.raw.category)} • ${translateFixText(context, product.priorityImprovements.first)}'
                      : translateFixText(
                          context, product.priorityImprovements.first),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RiskPill(risk: product.risk),
        ],
      ),
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  const _HorizontalBar({
    required this.label,
    required this.value,
    required this.max,
    this.suffix = '',
    this.color = AppColors.green,
  });

  final String label;
  final int value;
  final int max;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('$value$suffix',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              color: color,
              backgroundColor: const Color(0xFFE6ECE8),
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelChart extends StatelessWidget {
  const _FunnelChart({required this.products});

  final List<ProductInsight> products;

  @override
  Widget build(BuildContext context) {
    final views =
        products.fold<int>(0, (sum, product) => sum + product.raw.views);
    final carts =
        products.fold<int>(0, (sum, product) => sum + product.raw.addToCart);
    final purchases =
        products.fold<int>(0, (sum, product) => sum + product.raw.purchases);
    final returns =
        products.fold<int>(0, (sum, product) => sum + product.raw.returns);
    final max =
        [views, carts, purchases, returns].reduce((a, b) => a > b ? a : b);
    final rows = [
      (tr(context, 'funnel.views'), views, AppColors.blue),
      (tr(context, 'funnel.carts'), carts, AppColors.green),
      (tr(context, 'funnel.purchases'), purchases, AppColors.amber),
      (tr(context, 'funnel.returns'), returns, AppColors.red),
    ];

    return Column(
      children: [
        for (final row in rows)
          _HorizontalBar(
            label: row.$1,
            value: row.$2,
            max: max,
            color: row.$3,
          ),
      ],
    );
  }
}

class _CategoryRiskChart extends StatelessWidget {
  const _CategoryRiskChart({required this.products});

  final List<ProductInsight> products;

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<ProductInsight>>{};
    for (final product in products) {
      categories.putIfAbsent(product.raw.category, () => []).add(product);
    }

    return Column(
      children: [
        for (final entry in categories.entries)
          _HorizontalBar(
            label: translateCategory(context, entry.key),
            value: (entry.value.fold<double>(
                        0, (sum, product) => sum + product.returnRate) /
                    entry.value.length *
                    100)
                .round(),
            max: 40,
            suffix: '%',
            color: AppColors.amber,
          ),
      ],
    );
  }
}

class _IssueMatrix extends StatelessWidget {
  const _IssueMatrix({required this.products});

  final List<ProductInsight> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final product in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 190,
                  child: Text(product.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final rule in issueRules)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: product.issues
                                    .any((issue) => issue.key == rule.key)
                                ? issueColor(rule.key)
                                : const Color(0xFFE6ECE8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final rule in issueRules)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, color: issueColor(rule.key)),
                  const SizedBox(width: 5),
                  Text(rule.label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

enum AppSection {
  dashboard('nav.dashboard', Icons.dashboard_outlined),
  products('nav.products', Icons.inventory_2_outlined),
  returns('nav.returns', Icons.bar_chart_outlined),
  fixCenter('nav.fixCenter', Icons.task_alt_outlined);

  const AppSection(this.labelKey, this.icon);
  final String labelKey;
  final IconData icon;

  String label(BuildContext context) => tr(context, labelKey);
}

class RawProduct {
  const RawProduct({
    required this.sku,
    required this.name,
    required this.category,
    required this.views,
    required this.addToCart,
    required this.purchases,
    required this.returns,
    required this.description,
    required this.reviews,
    required this.returnReasons,
    required this.photoCount,
    required this.hasSizeChart,
    required this.hasModelPhoto,
  });

  final String sku;
  final String name;
  final String category;
  final int views;
  final int addToCart;
  final int purchases;
  final int returns;
  final String description;
  final String reviews;
  final String returnReasons;
  final int photoCount;
  final bool hasSizeChart;
  final bool hasModelPhoto;
}

class CompletedFix {
  const CompletedFix({
    required this.id,
    required this.sku,
    required this.title,
    required this.matchKey,
  });

  factory CompletedFix.fromJson(Map<String, dynamic> json) {
    final sku = '${json['sku'] ?? ''}';
    final title = '${json['title'] ?? ''}';
    return CompletedFix(
      id: '${json['fix_id'] ?? json['id'] ?? ''}',
      sku: sku,
      title: title,
      matchKey: '${json['match_key'] ?? fixMatchKey(sku, title)}',
    );
  }

  final String id;
  final String sku;
  final String title;
  final String matchKey;
}

class ProductFixApi {
  const ProductFixApi._();

  static Future<List<CompletedFix>> fetchCompletedFixes() async {
    final response = await html.HttpRequest.request(
      '$apiBaseUrl/tenants/$appTenantId/fixes/completed',
      method: 'GET',
      requestHeaders: {'Accept': 'application/json'},
    );
    final decoded =
        jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;
    final fixes = (decoded['completed_fixes'] as List? ?? []).cast<dynamic>();
    return fixes
        .map((item) => CompletedFix.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> setFixCompleted(
    FixAction action, {
    required bool completed,
  }) async {
    await html.HttpRequest.request(
      '$apiBaseUrl/tenants/$appTenantId/fixes/${Uri.encodeComponent(action.id)}/complete',
      method: 'POST',
      requestHeaders: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      sendData: jsonEncode({
        'sku': action.sku,
        'title': action.title,
        'detail': action.detail,
        'completed': completed,
      }),
    );
  }
}

class IssueRule {
  const IssueRule({
    required this.key,
    required this.label,
    required this.words,
    required this.fix,
  });

  final String key;
  final String label;
  final List<String> words;
  final String fix;
}

enum RiskLevel {
  low('risk.low'),
  medium('risk.medium'),
  high('risk.high');

  const RiskLevel(this.labelKey);
  final String labelKey;

  String label(BuildContext context) => tr(context, labelKey);
}

class ProductInsight {
  const ProductInsight({
    required this.raw,
    required this.score,
    required this.risk,
    required this.conversionRate,
    required this.cartConversionRate,
    required this.returnRate,
    required this.issues,
    required this.missingInfo,
    required this.suggestedDescription,
    required this.buyerWarning,
    required this.aiAssistantNote,
    required this.priorityImprovements,
    required this.fixActions,
  });

  final RawProduct raw;
  final int score;
  final RiskLevel risk;
  final double conversionRate;
  final double cartConversionRate;
  final double returnRate;
  final List<IssueRule> issues;
  final List<String> missingInfo;
  final String suggestedDescription;
  final String buyerWarning;
  final String aiAssistantNote;
  final List<String> priorityImprovements;
  final List<FixAction> fixActions;

  String get sku => raw.sku;
  String get name => raw.name;
  int get photoCount => raw.photoCount;
}

class Summary {
  const Summary({
    required this.totalProducts,
    required this.averageScore,
    required this.highRiskProducts,
    required this.topProblem,
  });

  factory Summary.fromProducts(List<ProductInsight> products) {
    final average = products.isEmpty
        ? 0
        : (products.map((product) => product.score).reduce((a, b) => a + b) /
                products.length)
            .round();
    final highRisk =
        products.where((product) => product.risk == RiskLevel.high).length;
    final topProblem = themeCounts(products).firstOrNull?.rule.label;

    return Summary(
      totalProducts: products.length,
      averageScore: average,
      highRiskProducts: highRisk,
      topProblem: topProblem,
    );
  }

  final int totalProducts;
  final int averageScore;
  final int highRiskProducts;
  final String? topProblem;
}

class ThemeCount {
  const ThemeCount({required this.rule, required this.count});

  final IssueRule rule;
  final int count;
}

class FixAction {
  const FixAction({
    required this.id,
    required this.sku,
    required this.title,
    required this.detail,
    required this.score,
    required this.risk,
  });

  final String id;
  final String sku;
  final String title;
  final String detail;
  final int score;
  final RiskLevel risk;

  String get matchKey => fixMatchKey(sku, title);
}

ProductInsight analyzeProduct(RawProduct product) {
  final combinedText =
      '${product.description} ${product.reviews} ${product.returnReasons}'
          .toLowerCase();
  final issues = issueRules
      .where((rule) => rule.words.any((word) => combinedText.contains(word)))
      .toList();
  final conversionRate = safeRate(product.purchases, product.views);
  final cartConversionRate = safeRate(product.purchases, product.addToCart);
  final returnRate = safeRate(product.returns, product.purchases);
  final missing = missingInfo(product);

  final issuePenalty = issues.length * 8;
  final returnPenalty = (returnRate * 180).round().clamp(0, 35).toInt();
  final conversionPenalty = conversionRate < 0.04
      ? 16
      : conversionRate < 0.08
          ? 8
          : 0;
  final cartPenalty = cartConversionRate < 0.25
      ? 10
      : cartConversionRate < 0.4
          ? 5
          : 0;
  final missingPenalty = missing.length * 7;
  final score = (100 -
          issuePenalty -
          returnPenalty -
          conversionPenalty -
          cartPenalty -
          missingPenalty)
      .clamp(0, 100)
      .toInt();
  final risk = score < 50 || returnRate > 0.22
      ? RiskLevel.high
      : score < 70 || returnRate > 0.12
          ? RiskLevel.medium
          : RiskLevel.low;
  final improvements = priorityImprovements(product, issues, missing);
  final actions = fixActionsForProduct(
    product: product,
    improvements: improvements,
    score: score,
    risk: risk,
    returnRate: returnRate,
  );

  return ProductInsight(
    raw: product,
    score: score,
    risk: risk,
    conversionRate: conversionRate,
    cartConversionRate: cartConversionRate,
    returnRate: returnRate,
    issues: issues,
    missingInfo: missing,
    suggestedDescription: suggestedDescription(product, issues, missing),
    buyerWarning: buyerWarning(product, issues),
    aiAssistantNote: aiAssistantNote(product, issues, missing),
    priorityImprovements: improvements,
    fixActions: actions,
  );
}

List<String> missingInfo(RawProduct product) {
  final missing = <String>[];
  final category = product.category.toLowerCase();
  final description = product.description.toLowerCase();

  if (product.description.length < 80) missing.add('Açıklama kısa');
  if (!product.hasSizeChart &&
      ['giyim', 'ayakkabi', 'ayakkabı'].contains(category)) {
    missing.add('Beden tablosu yok');
  }
  if (!product.hasModelPhoto) missing.add('Kullanım/model fotoğrafı yok');
  if (product.photoCount < 4) missing.add('Fotoğraf sayısı az');
  if (!['ölç', 'beden', 'numara'].any((token) => description.contains(token))) {
    missing.add('Ölçü bilgisi zayıf');
  }

  return missing;
}

List<String> priorityImprovements(
    RawProduct product, List<IssueRule> issues, List<String> missing) {
  final items = <String>[];
  for (final issue in issues) {
    items.add(issue.fix);
  }
  for (final missingItem in missing) {
    items.add(switch (missingItem) {
      'Açıklama kısa' =>
        'Açıklamaya kullanım senaryosu, malzeme ve beklenti bilgisini 3 net cümleyle ekle.',
      'Beden tablosu yok' =>
        'Beden tablosunu ürün fiyatının hemen altına sabitle.',
      'Kullanım/model fotoğrafı yok' =>
        'İlk 4 görsel içine gerçek kullanım veya model fotoğrafı ekle.',
      'Fotoğraf sayısı az' =>
        'En az 5 fotoğraf kullan: ön, yan, detay, kullanım, ölçek.',
      'Ölçü bilgisi zayıf' =>
        'Ölçü/numara/boyut bilgisini madde madde görünür hale getir.',
      _ => missingItem,
    });
  }
  return items.isEmpty
      ? ['Bu üründe kritik iyileştirme sinyali yok; haftalık izlemeye al.']
      : items;
}

String suggestedDescription(
    RawProduct product, List<IssueRule> issues, List<String> missing) {
  final issueText = issues.map((issue) => issue.label.toLowerCase()).join(', ');
  final missingText =
      missing.isEmpty ? '' : ' Eksik kalan alanlar: ${missing.join(', ')}.';
  return '${product.description} ${product.name}, satın almadan önce doğru beklenti kurmak isteyen müşteriler için netleştirildi. Bu sayfada özellikle ${issueText.isEmpty ? 'ürün beklentisi' : issueText} konusu açıklığa kavuşturulmalı.$missingText Kullanım alanı, ölçü/teknik bilgi ve gerçek görünüm bilgisi ürün açıklamasında açıkça yer almalı.';
}

String aiAssistantNote(
    RawProduct product, List<IssueRule> issues, List<String> missing) {
  final primary = issues.isNotEmpty
      ? issues.first.label
      : missing.isNotEmpty
          ? missing.first
          : 'dönüşüm takibi';
  return 'AI önerisi: ${product.name} için ilk düzeltme odağı "$primary" olmalı. Açıklama metnini müşteri itirazını cevaplayacak şekilde yeniden yaz, ardından aynı ürünü 7 gün izleyip iade oranı ve sepete ekleme-satın alma oranını karşılaştır.';
}

String buyerWarning(RawProduct product, List<IssueRule> issues) {
  if (issues.isEmpty) {
    return 'Bu ürün için satın alma öncesi ekstra uyarı gerekmiyor.';
  }

  return switch (issues.first.key) {
    'size' =>
      'Mini uyarı: Bu üründe beden/kalıp yorumu hassas. Satın almadan önce beden bilgisini kontrol edin.',
    'color' =>
      'Mini uyarı: Ürün rengi ışık ve ekran ayarlarına göre farklı algılanabilir.',
    'technical' =>
      'Mini uyarı: Teknik özellikleri ve kutu içeriğini satın almadan önce kontrol edin.',
    _ =>
      'Mini uyarı: ${product.name} için müşteri beklentisini netleştiren kısa bir not göster.',
  };
}

List<ThemeCount> themeCounts(List<ProductInsight> products) {
  return issueRules
      .map((rule) => ThemeCount(
            rule: rule,
            count: products
                .where((product) =>
                    product.issues.any((issue) => issue.key == rule.key))
                .length,
          ))
      .where((theme) => theme.count > 0)
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
}

List<FixAction> buildFixActions(List<ProductInsight> products) {
  final actions = <FixAction>[];
  for (final product in products) {
    actions.addAll(product.fixActions.take(3));
  }

  actions.sort((a, b) {
    final riskCompare = b.risk.index.compareTo(a.risk.index);
    return riskCompare == 0 ? a.score.compareTo(b.score) : riskCompare;
  });
  return actions.take(12).toList();
}

List<FixAction> fixActionsForProduct({
  required RawProduct product,
  required List<String> improvements,
  required int score,
  required RiskLevel risk,
  required double returnRate,
}) {
  return improvements.asMap().entries.map((entry) {
    final title = entry.value;
    return FixAction(
      id: fixActionId(product.sku, title),
      sku: product.sku,
      title: title,
      detail:
          '${product.name}: skor $score/100, iade oranı ${percent(returnRate)}. Önce bu düzeltme yapılmalı.',
      score: score,
      risk: risk,
    );
  }).toList();
}

String fixActionId(String sku, String title) {
  return fixMatchKey(sku, title);
}

String fixMatchKey(String sku, String title) {
  return '${sku.trim().toUpperCase()}:${normalizeFixTitle(title)}';
}

String normalizeFixTitle(String title) {
  const replacements = {
    'ı': 'i',
    'İ': 'i',
    'ğ': 'g',
    'Ğ': 'g',
    'ü': 'u',
    'Ü': 'u',
    'ş': 's',
    'Ş': 's',
    'ö': 'o',
    'Ö': 'o',
    'ç': 'c',
    'Ç': 'c',
  };
  final buffer = StringBuffer();
  for (final rune in title.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String translateFixText(BuildContext context, String text) {
  if (AppScope.of(context).language == AppLanguage.tr) return text;
  return _fixTextTranslations[text] ?? text;
}

String translateIssueLabel(BuildContext context, IssueRule rule) {
  if (AppScope.of(context).language == AppLanguage.tr) return rule.label;
  return switch (rule.key) {
    'size' => 'Unclear size/fit',
    'color' => 'Visual expectation gap',
    'quality' => 'Quality perception',
    'technical' => 'Missing technical info',
    'price' => 'Price perception problem',
    'shipping' => 'Shipping or delivery problem',
    'trust' => 'Trust problem',
    _ => rule.label,
  };
}

String translateIssueLabelText(BuildContext context, String? label) {
  if (label == null || label.isEmpty) return '-';
  if (AppScope.of(context).language == AppLanguage.tr) return label;
  final normalized = normalizeFixTitle(label);
  return switch (normalized) {
    'beden-kalip-belirsizligi' => 'Unclear size/fit',
    'gorsel-beklenti-farki' => 'Visual expectation gap',
    'kalite-algisi' => 'Quality perception',
    'teknik-bilgi-eksikligi' => 'Missing technical info',
    'fiyat-algisi-problemi' => 'Price perception problem',
    'kargo-veya-teslimat-problemi' => 'Shipping or delivery problem',
    'guven-problemi' => 'Trust problem',
    _ => label,
  };
}

String translateCategory(BuildContext context, String category) {
  if (AppScope.of(context).language == AppLanguage.tr) return category;
  final normalized = normalizeFixTitle(category);
  return switch (normalized) {
    'ayakkabi' => 'Shoes',
    'giyim' => 'Apparel',
    'elektronik' => 'Electronics',
    'aksesuar' => 'Accessories',
    'kozmetik' => 'Cosmetics',
    'genel' => 'General',
    _ => category,
  };
}

const _fixTextTranslations = {
  'Beden veya kalıp bilgisini fiyatın hemen altına taşı.':
      'Move size/fit information directly under the price.',
  'Ürün görsellerine doğal ışık ve gerçek kullanım fotoğrafı ekle.':
      'Add natural-light and real-use product photos.',
  'Malzeme, doku ve kullanım hissini açıklamaya net ekle.':
      'Clearly add material, texture, and usage feel to the description.',
  'Teknik özellikleri madde madde ve eksiksiz göster.':
      'Show technical specs as a complete bullet list.',
  'Fiyat algısını güçlendirmek için ürün değerini açıklayan kısa bir bölüm ekle.':
      'Add a short section that explains product value to strengthen price perception.',
  'Kargo süresi, paketleme ve teslimat beklentisini ürün sayfasında netleştir.':
      'Clarify shipping time, packaging, and delivery expectations on the product page.',
  'Garanti, iade koşulları ve orijinallik bilgisini görünür hale getir.':
      'Make warranty, return policy, and authenticity information visible.',
  'Açıklamaya kullanım senaryosu, malzeme ve beklenti bilgisini 3 net cümleyle ekle.':
      'Add use case, material, and expectation details in three clear sentences.',
  'Beden tablosunu ürün fiyatının hemen altına sabitle.':
      'Pin the size chart directly under the product price.',
  'İlk 4 görsel içine gerçek kullanım veya model fotoğrafı ekle.':
      'Add a real-use or model photo among the first four images.',
  'En az 5 fotoğraf kullan: ön, yan, detay, kullanım, ölçek.':
      'Use at least five photos: front, side, detail, use, and scale.',
  'Ölçü/numara/boyut bilgisini madde madde görünür hale getir.':
      'Make measurement, size, and dimension details visible as bullets.',
  'Bu üründe kritik iyileştirme sinyali yok; haftalık izlemeye al.':
      'No critical fix signal for this product; monitor it weekly.',
};

List<RawProduct> parseCsvProducts(String csv) {
  final rows = parseCsv(csv);
  if (rows.length < 2) return [];

  final headers =
      rows.first.map((header) => header.trim().toLowerCase()).toList();
  return rows
      .skip(1)
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .map((row) {
    String value(String header) {
      final index = headers.indexOf(header);
      return index >= 0 && index < row.length ? row[index].trim() : '';
    }

    return RawProduct(
      sku: value('sku').isEmpty
          ? 'SKU-${DateTime.now().millisecondsSinceEpoch}'
          : value('sku'),
      name: value('name').isEmpty ? 'Adsız ürün' : value('name'),
      category: value('category').isEmpty ? 'Genel' : value('category'),
      views: intValue(value('views')),
      addToCart: intValue(value('add_to_cart')),
      purchases: intValue(value('purchases')),
      returns: intValue(value('returns')),
      description: value('description'),
      reviews: value('reviews'),
      returnReasons: value('return_reasons'),
      photoCount: intValue(value('photo_count')),
      hasSizeChart: boolValue(value('has_size_chart')),
      hasModelPhoto: boolValue(value('has_model_photo')),
    );
  }).toList();
}

List<List<String>> parseCsv(String csv) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;

  for (var index = 0; index < csv.length; index += 1) {
    final char = csv[index];
    final next = index + 1 < csv.length ? csv[index + 1] : '';

    if (char == '"' && quoted && next == '"') {
      field.write('"');
      index += 1;
    } else if (char == '"') {
      quoted = !quoted;
    } else if (char == ',' && !quoted) {
      row.add(field.toString());
      field = StringBuffer();
    } else if ((char == '\n' || char == '\r') && !quoted) {
      if (char == '\r' && next == '\n') index += 1;
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field = StringBuffer();
    } else {
      field.write(char);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }

  return rows;
}

String productToCsvLine(RawProduct product) {
  return [
    product.sku,
    product.name,
    product.category,
    '${product.views}',
    '${product.addToCart}',
    '${product.purchases}',
    '${product.returns}',
    product.description,
    product.reviews,
    product.returnReasons,
    '${product.photoCount}',
    '${product.hasSizeChart}',
    '${product.hasModelPhoto}',
  ].map(csvEscape).join(',');
}

String csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

int intValue(String value) => int.tryParse(value.trim()) ?? 0;

bool boolValue(String value) =>
    ['true', 'yes', '1', 'evet'].contains(value.trim().toLowerCase());

double safeRate(int part, int total) => total == 0 ? 0 : part / total;

String percent(double value) => '${(value * 100).round()}%';

ThemeData _buildTheme(bool darkMode) {
  final palette = AppPalette(darkMode);
  final brightness = darkMode ? Brightness.dark : Brightness.light;
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: palette.page,
    canvasColor: palette.page,
    dialogTheme: DialogThemeData(backgroundColor: palette.surface),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: palette.text,
          displayColor: palette.text,
        ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      filled: darkMode,
      fillColor: palette.surfaceAlt,
    ),
    useMaterial3: true,
  );
}

Color scoreColor(int score) {
  if (score < 50) return AppColors.red;
  if (score < 70) return AppColors.amber;
  return AppColors.green;
}

Color riskColor(RiskLevel risk) {
  return switch (risk) {
    RiskLevel.low => AppColors.green,
    RiskLevel.medium => AppColors.amber,
    RiskLevel.high => AppColors.red,
  };
}

Color issueColor(String key) {
  return switch (key) {
    'size' => AppColors.red,
    'color' => AppColors.blue,
    'quality' => AppColors.amber,
    'technical' => AppColors.green,
    'price' => AppColors.purple,
    'shipping' => AppColors.cyan,
    'trust' => AppColors.ink,
    _ => AppColors.muted,
  };
}

extension FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class AppColors {
  static const page = Color(0xFFEEF3EF);
  static const line = Color(0xFFDCE3E1);
  static const muted = Color(0xFF657174);
  static const green = Color(0xFF1D7A5F);
  static const greenSoft = Color(0xFFDFF1E7);
  static const amber = Color(0xFFB06B16);
  static const red = Color(0xFFB83D3D);
  static const blue = Color(0xFF2F64A3);
  static const blueSoft = Color(0xFFC9DDF4);
  static const purple = Color(0xFF7450A8);
  static const cyan = Color(0xFF247C88);
  static const ink = Color(0xFF4F5C68);
}

const issueRules = [
  IssueRule(
    key: 'size',
    label: 'Beden/Kalıp belirsizliği',
    words: ['beden', 'kalıp', 'numara', 'dar', 'büyük', 'küçük', 'boy'],
    fix: 'Beden veya kalıp bilgisini fiyatın hemen altına taşı.',
  ),
  IssueRule(
    key: 'color',
    label: 'Görsel beklenti farkı',
    words: ['renk', 'fotoğraf', 'görsel', 'koyu', 'açık'],
    fix: 'Ürün görsellerine doğal ışık ve gerçek kullanım fotoğrafı ekle.',
  ),
  IssueRule(
    key: 'quality',
    label: 'Kalite algısı',
    words: ['kumaş', 'ince', 'kalite', 'sert', 'yumuşak', 'malzeme'],
    fix: 'Malzeme, doku ve kullanım hissini açıklamaya net ekle.',
  ),
  IssueRule(
    key: 'technical',
    label: 'Teknik bilgi eksikliği',
    words: ['bağlantı', 'pil', 'içerik', 'kutu', 'ölçü', 'özellik'],
    fix: 'Teknik özellikleri madde madde ve eksiksiz göster.',
  ),
  IssueRule(
    key: 'price',
    label: 'Fiyat algısı problemi',
    words: ['pahali', 'pahalı', 'fiyat', 'eder', 'ucuz', 'kampanya'],
    fix:
        'Fiyat algısını güçlendirmek için ürün değerini açıklayan kısa bir bölüm ekle.',
  ),
  IssueRule(
    key: 'shipping',
    label: 'Kargo veya teslimat problemi',
    words: ['kargo', 'gecikti', 'geç', 'teslimat', 'paket', 'hasarlı'],
    fix:
        'Kargo süresi, paketleme ve teslimat beklentisini ürün sayfasında netleştir.',
  ),
  IssueRule(
    key: 'trust',
    label: 'Güven problemi',
    words: ['orijinal', 'sahte', 'güven', 'garanti', 'iade', 'sertifika'],
    fix: 'Garanti, iade koşulları ve orijinallik bilgisini görünür hale getir.',
  ),
];

const sampleProducts = [
  RawProduct(
    sku: 'SNK-101',
    name: 'Beyaz Platform Sneaker',
    category: 'Ayakkabi',
    views: 4200,
    addToCart: 510,
    purchases: 118,
    returns: 34,
    description: 'Rahat ve şık günlük sneaker.',
    reviews:
        'Ürün güzel ama kalıbı çok dar. Fotoğrafta daha yumuşak duruyor. Bir numara küçük geldi.',
    returnReasons:
        'Numara küçük geldi; kalıbı dar; ayakta beklediğim gibi durmadı',
    photoCount: 4,
    hasSizeChart: true,
    hasModelPhoto: false,
  ),
  RawProduct(
    sku: 'DRS-220',
    name: 'Siyah Kruvaze Elbise',
    category: 'Giyim',
    views: 3100,
    addToCart: 430,
    purchases: 86,
    returns: 29,
    description:
        'Kruvaze kesim siyah elbise. Günlük ve davet kullanımı için uygundur.',
    reviews: 'Kumaşı ince. Bedeni büyük geldi. Boyu modeldeki gibi durmadı.',
    returnReasons: 'Bedeni büyük geldi; kumaşı beklediğimden ince; boyu kısa',
    photoCount: 3,
    hasSizeChart: false,
    hasModelPhoto: true,
  ),
  RawProduct(
    sku: 'HDP-044',
    name: 'Bluetooth Kulaklık',
    category: 'Elektronik',
    views: 2800,
    addToCart: 260,
    purchases: 74,
    returns: 8,
    description: 'Bluetooth kulaklık, uzun pil ömrü.',
    reviews:
        'Ses iyi ama bağlantı bazen kopuyor. Kutu içeriği açıklamada yoktu.',
    returnReasons: 'Bağlantı sorunu; açıklama eksik',
    photoCount: 5,
    hasSizeChart: false,
    hasModelPhoto: false,
  ),
  RawProduct(
    sku: 'BAG-018',
    name: 'Mini Deri Çanta',
    category: 'Aksesuar',
    views: 1900,
    addToCart: 250,
    purchases: 112,
    returns: 6,
    description: 'Şık mini çanta.',
    reviews: 'Rengi fotoğraftan koyu. Boyutu küçük ama kullanışlı.',
    returnReasons: 'Rengi farklı; boyut beklediğimden küçük',
    photoCount: 6,
    hasSizeChart: false,
    hasModelPhoto: true,
  ),
  RawProduct(
    sku: 'COS-330',
    name: 'Nemlendirici Krem',
    category: 'Kozmetik',
    views: 3600,
    addToCart: 390,
    purchases: 141,
    returns: 17,
    description: 'Tüm cilt tipleri için nemlendirici krem.',
    reviews:
        'Kokusu yoğun. Hassas cildimde kızarıklık yaptı. İçerik bilgisi eksik.',
    returnReasons: 'Koku yoğun; ciltte kızarıklık; içerik bilgisi eksik',
    photoCount: 2,
    hasSizeChart: false,
    hasModelPhoto: false,
  ),
];

const sampleCsv =
    '''sku,name,category,views,add_to_cart,purchases,returns,description,reviews,return_reasons,photo_count,has_size_chart,has_model_photo
TSH-555,Oversize Tişört,Giyim,1500,190,42,11,"Pamuk oversize tişört.","Kalıbı çok büyük. Kumaşı güzel ama boyu uzun.","Bedeni büyük geldi; boyu uzun",3,false,true''';
