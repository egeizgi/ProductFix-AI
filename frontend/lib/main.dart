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

void main() {
  runApp(const ProductFixApp());
}

class ProductFixApp extends StatelessWidget {
  const ProductFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ProductFix AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.page,
        useMaterial3: true,
      ),
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
  final List<RawProduct> rawProducts = [...sampleProducts];
  final Set<String> completedFixIds = {};
  final Set<String> completedFixKeys = {};

  List<ProductInsight> get products {
    return rawProducts.map(analyzeProduct).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
  }

  @override
  void initState() {
    super.initState();
    _loadCompletedFixes();
  }

  @override
  Widget build(BuildContext context) {
    final insights = products;
    final summary = Summary.fromProducts(insights);
    final themes = themeCounts(insights);
    final actions = buildFixActions(insights);
    final openActions =
        actions.where((action) => !_isFixCompleted(action)).toList();

    return Scaffold(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      }
    });

    _saveCompletedFixes();
    unawaited(_syncFixCompletion(action, completed: !wasCompleted));
  }

  bool _isFixCompleted(FixAction action) {
    return completedFixIds.contains(action.id) ||
        completedFixKeys.contains(action.matchKey);
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
    required this.actions,
    required this.completedFixIds,
    required this.completedFixKeys,
    required this.highlightedSku,
    required this.onAddManual,
    required this.onPasteCsv,
    required this.onActionTap,
    required this.onToggleFix,
  });

  final AppSection selectedSection;
  final List<ProductInsight> products;
  final Summary summary;
  final List<ThemeCount> themes;
  final List<FixAction> actions;
  final Set<String> completedFixIds;
  final Set<String> completedFixKeys;
  final String? highlightedSku;
  final VoidCallback onAddManual;
  final VoidCallback onPasteCsv;
  final ValueChanged<FixAction> onActionTap;
  final ValueChanged<FixAction> onToggleFix;

  @override
  Widget build(BuildContext context) {
    final child = switch (selectedSection) {
      AppSection.dashboard => DashboardView(
          products: products,
          summary: summary,
          themes: themes,
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
          onActionTap: onActionTap,
          onToggleFix: onToggleFix,
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
    required this.onAddManual,
    required this.onPasteCsv,
  });

  final List<ProductInsight> products;
  final Summary summary;
  final List<ThemeCount> themes;
  final VoidCallback onAddManual;
  final VoidCallback onPasteCsv;

  @override
  Widget build(BuildContext context) {
    final worstProducts = products.take(4).toList();

    return _Page(
      title: 'Dashboard',
      subtitle:
          'Ürün sayfası kalitesi, iade riski ve aksiyon önceliği tek yerde.',
      actions: [
        OutlinedButton.icon(
          onPressed: onPasteCsv,
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('CSV yapıştır'),
        ),
        FilledButton.icon(
          onPressed: onAddManual,
          icon: const Icon(Icons.add),
          label: const Text('Manuel ürün'),
        ),
      ],
      children: [
        _MetricGrid(summary: summary),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final widgets = [
              _PanelSection(
                eyebrow: 'Öncelik',
                title: 'En problemli ürünler',
                child: Column(
                  children: [
                    for (final product in worstProducts)
                      _MiniProductRow(product: product, showCategory: true),
                  ],
                ),
              ),
              _PanelSection(
                eyebrow: 'Sinyal dağılımı',
                title: 'Ana problem temaları',
                child: Column(
                  children: [
                    for (final theme in themes)
                      _HorizontalBar(
                          label: theme.rule.label,
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
          eyebrow: 'Funnel sağlığı',
          title: 'Görüntüleme, sepete ekleme ve satın alma akışı',
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
      title: 'Ürünler',
      subtitle:
          'Her ürün için skor, açık iyileştirme listesi, AI açıklama taslağı ve satın alma öncesi uyarı.',
      actions: [
        OutlinedButton.icon(
          onPressed: onPasteCsv,
          icon: const Icon(Icons.table_rows_outlined),
          label: const Text('CSV yapıştır'),
        ),
        FilledButton.icon(
          onPressed: onAddManual,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Manuel ürün gir'),
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
      title: 'İade Analizi',
      subtitle:
          'İade sebeplerini ürün, kategori ve problem teması bazında grafiklerle oku.',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 940;
            final left = _PanelSection(
              eyebrow: 'Tema grafiği',
              title: 'İade sinyali yoğunluğu',
              child: Column(
                children: [
                  for (final theme in themes)
                    _HorizontalBar(
                      label: theme.rule.label,
                      value: theme.count,
                      max: products.length,
                      color: issueColor(theme.rule.key),
                    ),
                ],
              ),
            );
            final right = _PanelSection(
              eyebrow: 'Ürün grafiği',
              title: 'Ürün bazlı iade oranı',
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
                eyebrow: 'Kategori kırılımı',
                title: 'Kategoriye göre risk',
                child: _CategoryRiskChart(products: products),
              ),
              _PanelSection(
                eyebrow: 'Sebep matrisi',
                title: 'Ürünlerde tekrar eden problemler',
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
    required this.onActionTap,
    required this.onToggleFix,
  });

  final List<FixAction> actions;
  final ValueChanged<FixAction> onActionTap;
  final ValueChanged<FixAction> onToggleFix;

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Fix Center',
      subtitle:
          'Önce parayı kaçıran ürünlere dokun: yüksek iade, düşük skor ve net yapılacaklar.',
      children: [
        _PanelSection(
          eyebrow: 'Reasonable öncelik',
          title: 'Bugün yapılacak işler',
          trailing: _Pill('${actions.length} aksiyon', color: AppColors.blue),
          child: actions.isEmpty
              ? const _EmptyState(
                  icon: Icons.verified_outlined,
                  title: 'Bugün yapılacak iş kalmadı',
                  message:
                      'Tamamlanan fixler ürün kartlarında yeşil olarak görünür.',
                )
              : Column(
                  children: [
                    for (final action in actions)
                      _FixActionCard(
                        action: action,
                        onTap: () => onActionTap(action),
                        onToggle: () => onToggleFix(action),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedSection, required this.onSelected});

  final AppSection selectedSection;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFFBFCFA),
        border: Border(right: BorderSide(color: AppColors.line)),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ProductFix AI',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text(
                      'Ürün sayfası analiz motoru',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          for (final section in AppSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                selected: section == selectedSection,
                selectedTileColor: AppColors.greenSoft,
                dense: true,
                leading: Icon(section.icon, size: 20),
                title: Text(section.label),
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
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 16, height: 1.5),
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
      ('Ürün', '${summary.totalProducts}', Icons.inventory_2_outlined),
      ('Ortalama skor', '${summary.averageScore}', Icons.speed_outlined),
      (
        'Yüksek risk',
        '${summary.highRiskProducts}',
        Icons.warning_amber_outlined
      ),
      ('En büyük kayıp', summary.topProblem ?? '-', Icons.insights_outlined),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF8E8) : const Color(0xFFFCFDFC),
        border: Border.all(
            color: highlighted ? AppColors.amber : AppColors.line,
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
                    _Chip('Dönüşüm: ${percent(product.conversionRate)}'),
                    _Chip(
                        'Sepetten satın alma: ${percent(product.cartConversionRate)}'),
                    _Chip('İade oranı: ${percent(product.returnRate)}'),
                    _Chip('Fotoğraf: ${product.photoCount}'),
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
                  title: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: AppColors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Önerilen açıklama ve AI yardımcı notu',
                        style: TextStyle(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        border: Border.all(color: const Color(0xFFFFD28C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.priority_high, size: 18, color: AppColors.amber),
              SizedBox(width: 8),
              Text('Net yapılacak iyileştirmeler',
                  style: TextStyle(fontWeight: FontWeight.w900)),
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
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Bu üründe açık fix kalmadı.',
                style: TextStyle(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            completed ? AppColors.green.withValues(alpha: 0.1) : Colors.white,
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
              action.title,
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
            child: Text(completed ? 'Geri al' : 'Tamamlandı'),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blueSoft),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFF4F8FE),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI açıklama taslağı',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(product.suggestedDescription,
              style: const TextStyle(color: AppColors.muted, height: 1.55)),
          const SizedBox(height: 12),
          const Text('AI kontrol notu',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(product.aiAssistantNote,
              style: const TextStyle(color: AppColors.muted, height: 1.55)),
          const SizedBox(height: 12),
          const Text('Satın alma öncesi mini uyarı',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(product.buyerWarning,
              style: const TextStyle(color: AppColors.muted, height: 1.55)),
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
  });

  final FixAction action;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
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
                    Text(action.title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(action.detail,
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.45)),
                    const SizedBox(height: 8),
                    Text('İlgili ürüne gitmek için tıkla',
                        style: TextStyle(
                            color: riskColor(action.risk),
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onToggle,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Tamamlandı'),
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
            style: const TextStyle(color: AppColors.muted),
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
      title: const Text('Manuel ürün girişi'),
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
                    _Field(controller: name, label: 'Ürün adı', required: true),
                    _Field(controller: category, label: 'Kategori'),
                    _Field(
                        controller: views,
                        label: 'Görüntülenme',
                        numeric: true),
                    _Field(
                        controller: addToCart,
                        label: 'Sepete ekleme',
                        numeric: true),
                    _Field(
                        controller: purchases,
                        label: 'Satın alma',
                        numeric: true),
                    _Field(controller: returns, label: 'İade', numeric: true),
                    _Field(
                        controller: photoCount,
                        label: 'Fotoğraf sayısı',
                        numeric: true),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                    controller: description,
                    label: 'Açıklama',
                    wide: true,
                    maxLines: 3),
                const SizedBox(height: 12),
                _Field(
                    controller: reviews,
                    label: 'Yorumlar',
                    wide: true,
                    maxLines: 3),
                const SizedBox(height: 12),
                _Field(
                    controller: returnReasons,
                    label: 'İade nedenleri',
                    wide: true,
                    maxLines: 3),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: hasSizeChart,
                  onChanged: (value) =>
                      setState(() => hasSizeChart = value ?? false),
                  title: const Text('Beden tablosu var'),
                ),
                CheckboxListTile(
                  value: hasModelPhoto,
                  onChanged: (value) =>
                      setState(() => hasModelPhoto = value ?? false),
                  title: const Text('Kullanım/model fotoğrafı var'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
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
          child: const Text('CSV’ye çevir ve analiz et'),
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
      title: const Text('CSV yapıştır'),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Aynı kolon başlıklarıyla ürünleri yapıştır. Veriler analiz hattına alınır.'),
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
            child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final rows = parseCsvProducts(controller.text);
            if (rows.isEmpty) {
              setState(() => error =
                  'CSV okunamadı. Başlıkları ve virgülleri kontrol et.');
              return;
            }
            Navigator.pop(context, rows);
          },
          child: const Text('Analiz et'),
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
            return 'Zorunlu';
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C2D2A).withValues(alpha: 0.09),
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
    return _Pill(risk.label, color: color);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Text(text,
          style: const TextStyle(color: AppColors.muted, fontSize: 13)),
    );
  }
}

class _MiniProductRow extends StatelessWidget {
  const _MiniProductRow({required this.product, required this.showCategory});

  final ProductInsight product;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFC),
        border: Border.all(color: AppColors.line),
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
                      ? '${product.raw.category} • ${product.priorityImprovements.first}'
                      : product.priorityImprovements.first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
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
      ('Görüntüleme', views, AppColors.blue),
      ('Sepete ekleme', carts, AppColors.green),
      ('Satın alma', purchases, AppColors.amber),
      ('İade', returns, AppColors.red),
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
            label: entry.key,
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
  dashboard('Dashboard', Icons.dashboard_outlined),
  products('Ürünler', Icons.inventory_2_outlined),
  returns('İade Analizi', Icons.bar_chart_outlined),
  fixCenter('Fix Center', Icons.task_alt_outlined);

  const AppSection(this.label, this.icon);
  final String label;
  final IconData icon;
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
  low('Düşük risk'),
  medium('Orta risk'),
  high('Yüksek risk');

  const RiskLevel(this.label);
  final String label;
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
