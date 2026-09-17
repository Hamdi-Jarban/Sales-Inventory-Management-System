import 'package:flutter/material.dart';
import 'dart:math' as math;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _periodIndex = 1;
  bool _loading = false;

  final List<String> _periods = ['اليوم', 'أسبوع', 'شهر', 'سنة'];

  // ============ بيانات وهمية ============

  final List<Map<String, dynamic>> _dailySales = [
    {'day': 'السبت', 'sales': 1250.0, 'profit': 320.0, 'invoices': 18},
    {'day': 'الأحد', 'sales': 980.0, 'profit': 245.0, 'invoices': 14},
    {'day': 'الاثنين', 'sales': 1420.0, 'profit': 385.0, 'invoices': 22},
    {'day': 'الثلاثاء', 'sales': 1100.0, 'profit': 290.0, 'invoices': 16},
    {'day': 'الأربعاء', 'sales': 1680.0, 'profit': 450.0, 'invoices': 25},
    {'day': 'الخميس', 'sales': 2050.0, 'profit': 560.0, 'invoices': 31},
    {'day': 'الجمعة', 'sales': 1890.0, 'profit': 510.0, 'invoices': 28},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'name': 'بقالة', 'value': 42.0, 'color': const Color(0xFF0F5132)},
    {'name': 'ألبان', 'value': 28.0, 'color': const Color(0xFF198754)},
    {'name': 'مشروبات', 'value': 18.0, 'color': const Color(0xFFFFB300)},
    {'name': 'أخرى', 'value': 12.0, 'color': const Color(0xFF9C27B0)},
  ];

  final List<Map<String, dynamic>> _topProducts = [
    {'name': 'أرز الشعلان 5 كجم', 'profit': 315.0, 'qty': 45},
    {'name': 'زيت عافية 1.5 لتر', 'profit': 280.0, 'qty': 80},
    {'name': 'حليب المراعي 1 لتر', 'profit': 240.0, 'qty': 160},
    {'name': 'شاي العروسة 250 جم', 'profit': 220.0, 'qty': 55},
    {'name': 'جبن كرافت 200 جم', 'profit': 186.0, 'qty': 62},
  ];

  final List<Map<String, dynamic>> _needRestock = [
    {'name': 'حليب المراعي 1 لتر', 'stock': 3, 'min': 5},
    {'name': 'شاي العروسة 250 جم', 'stock': 2, 'min': 5},
    {'name': 'بيض طازج 30 حبة', 'stock': 0, 'min': 6},
    {'name': 'زيت عافية 1.5 لتر', 'stock': 1, 'min': 4},
  ];

  // ============ الحسابات ============

  double get _totalSales =>
      _dailySales.fold(0, (s, d) => s + (d['sales'] as double));
  double get _totalProfit =>
      _dailySales.fold(0, (s, d) => s + (d['profit'] as double));
  int get _totalInvoices =>
      _dailySales.fold(0, (s, d) => s + (d['invoices'] as int));
  double get _avgInvoice => _totalInvoices == 0 ? 0 : _totalSales / _totalInvoices;
  double get _profitMargin =>
      _totalSales == 0 ? 0 : (_totalProfit / _totalSales) * 100;

  double get _maxSales =>
      _dailySales.map((d) => d['sales'] as double).reduce(math.max);
  double get _maxProfit =>
      _dailySales.map((d) => d['profit'] as double).reduce(math.max);

  double get _todaySales => _dailySales.last['sales'] as double;
  double get _todayProfit => _dailySales.last['profit'] as double;

  String _money(num v) => '${v.toStringAsFixed(2)} ر.س';
  String _moneyShort(num v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('الأرباح والتقارير'),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              tooltip: 'التاريخ',
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'تصدير',
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _refresh,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              _buildHeroBanner(),
              const SizedBox(height: 16),
              _buildKpiGrid(),
              const SizedBox(height: 24),
              _sectionTitle('المبيعات والأرباح', Icons.bar_chart),
              const SizedBox(height: 10),
              _buildSalesProfitChart(),
              const SizedBox(height: 24),
              _sectionTitle('المبيعات حسب الفئة',
                  Icons.pie_chart_outline),
              const SizedBox(height: 10),
              _buildCategoryPieChart(),
              const SizedBox(height: 24),
              _sectionTitle('الأكثر ربحية',
                  Icons.workspace_premium_outlined),
              const SizedBox(height: 10),
              _buildTopProducts(),
              const SizedBox(height: 24),
              _sectionTitle('حالة المخزون',
                  Icons.inventory_2_outlined),
              const SizedBox(height: 10),
              _buildStockStatus(),
              const SizedBox(height: 24),
              _sectionTitle('يحتاج إعادة طلب',
                  Icons.warning_amber_rounded),
              const SizedBox(height: 10),
              _buildRestockCard(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 1. فلتر الفترة ============

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: _periods.asMap().entries.map((e) {
          final selected = _periodIndex == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _periodIndex = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                    colors: [
                      Color(0xFF0F5132),
                      Color(0xFF198754),
                    ],
                  )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: const Color(0xFF0F5132)
                          .withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============ 2. البانر الرئيسي ============

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5132), Color(0xFF198754)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5132).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.savings_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صافي أرباح ${_periods[_periodIndex]}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'آخر تحديث قبل 3 دقائق',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF20C997).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF20C997).withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_upward,
                        color: Color(0xFF20C997), size: 12),
                    SizedBox(width: 2),
                    Text(
                      '12.4%',
                      style: TextStyle(
                        color: Color(0xFF20C997),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _money(_totalProfit),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'هامش الربح: ${_profitMargin.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _bannerStat(
                  'إجمالي المبيعات',
                  _money(_totalSales),
                  Icons.trending_up,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.15),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              Expanded(
                child: _bannerStat(
                  'عدد الفواتير',
                  '$_totalInvoices',
                  Icons.receipt_long_outlined,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.15),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              Expanded(
                child: _bannerStat(
                  'متوسط الفاتورة',
                  _moneyShort(_avgInvoice),
                  Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white60, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ============ 3. شبكة KPIs ============

  Widget _buildKpiGrid() {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            'مبيعات اليوم',
            _moneyShort(_todaySales),
            Icons.trending_up,
            const Color(0xFF0F5132),
            change: 8.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            'ربح اليوم',
            _moneyShort(_todayProfit),
            Icons.savings_outlined,
            const Color(0xFF20C997),
            change: 5.2,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(
      String title,
      String value,
      IconData icon,
      Color color, {
        required double change,
      }) {
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.red)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 10,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${change.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color:
                        isPositive ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============ 4. رسم بياني مبيعات + أرباح ============

  Widget _buildSalesProfitChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // وسيلة الإيضاح
          Row(
            children: [
              _legendDot('المبيعات', const Color(0xFF0F5132)),
              const SizedBox(width: 14),
              _legendDot('الأرباح', const Color(0xFF20C997)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5132).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'آخر 7 أيام',
                  style: TextStyle(
                    color: Color(0xFF0F5132),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // الرسم البياني
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                // خطوط الشبكة
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      return Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              _moneyShort(_maxSales * (1 - i / 4)),
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey[200],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                // الأعمدة
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: _dailySales.asMap().entries.map((e) {
                        final i = e.key;
                        final sales = e.value['sales'] as double;
                        final profit = e.value['profit'] as double;
                        final salesRatio = sales / _maxSales;
                        final profitRatio = profit / _maxSales;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3),
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.end,
                              children: [
                                // أعمدة مزدوجة
                                SizedBox(
                                  height: 160,
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      // عمود المبيعات
                                      AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 600),
                                        width: 10,
                                        height: 160 * salesRatio,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF0F5132),
                                              Color(0xFF198754),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                          const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      // عمود الربح
                                      AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 600),
                                        width: 10,
                                        height: 160 * profitRatio,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF20C997),
                                              Color(0xFF198754),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                          const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // أيام الأسبوع
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              children: _dailySales.map((d) {
                return Expanded(
                  child: Center(
                    child: Text(
                      d['day'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============ 5. رسم دائري للفئات ============

  Widget _buildCategoryPieChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // الرسم الدائري
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(150, 150),
                  painter: _DonutChartPainter(
                    data: _categories
                        .map((c) => (
                    c['value'] as double,
                    c['color'] as Color,
                    ))
                        .toList(),
                    strokeWidth: 24,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_totalInvoices',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F5132),
                      ),
                    ),
                    Text(
                      'فاتورة',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // وسيلة الإيضاح
          Expanded(
            child: Column(
              children: _categories.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: c['color'] as Color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c['name'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (c['color'] as Color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(c['value'] as double).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: c['color'] as Color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 6. الأكثر ربحية ============

  Widget _buildTopProducts() {
    final maxProfit = _topProducts.first['profit'] as double;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _topProducts.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final profit = p['profit'] as double;
          final progress = profit / maxProfit;
          final isLast = i == _topProducts.length - 1;
          final medalColor = _medalColor(i);
          final medalIcon = _medalIcon(i);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // الميدالية
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: medalColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: medalColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: i < 3
                          ? Icon(
                        medalIcon,
                        color: medalColor,
                        size: 16,
                      )
                          : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: medalColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // التفاصيل
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // شريط التقدم
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                medalColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'مبيع: ${p['qty']} وحدة',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // الربح
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${profit.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Text(
                            'ر.س',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Colors.grey[200],
                  indent: 58,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _medalColor(int i) {
    switch (i) {
      case 0:
        return const Color(0xFFFFB300);
      case 1:
        return const Color(0xFF9E9E9E);
      case 2:
        return const Color(0xFFBF8970);
      default:
        return const Color(0xFF0F5132);
    }
  }

  IconData _medalIcon(int i) {
    return Icons.emoji_events;
  }

  // ============ 7. حالة المخزون ============

  Widget _buildStockStatus() {
    const available = 79;
    const low = 6;
    const out = 2;
    const total = 87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // الدائرة
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _DonutChartPainter(
                    data: [
                      (available / total, Colors.green),
                      (low / total, Colors.orange),
                      (out / total, Colors.red),
                    ],
                    strokeWidth: 22,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$available',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F5132),
                      ),
                    ),
                    Text(
                      'منتج متوفر',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // التفاصيل
          Expanded(
            child: Column(
              children: [
                _stockRow(
                  'متوفر',
                  available,
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(height: 10),
                _stockRow(
                  'قريب من النفاد',
                  low,
                  Icons.warning_amber_rounded,
                  Colors.orange,
                ),
                const SizedBox(height: 10),
                _stockRow(
                  'نفد',
                  out,
                  Icons.error_outline,
                  Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockRow(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 8. يحتاج إعادة طلب ============

  Widget _buildRestockCard() {
    if (_needRestock.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'كل المنتجات بمخزون جيد',
                style: TextStyle(
                  color: Colors.green[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _needRestock.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final stock = p['stock'] as int;
          final min = p['min'] as int;
          final isOut = stock == 0;
          final isLast = i == _needRestock.length - 1;

          final urgency = isOut
              ? 'نفد'
              : stock <= min / 2
              ? 'عاجل'
              : 'منخفض';
          final urgencyColor = isOut
              ? Colors.red
              : stock <= min / 2
              ? Colors.deepOrange
              : Colors.orange;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isOut
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        color: urgencyColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'المخزون: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '$stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: urgencyColor,
                                ),
                              ),
                              Text(
                                ' / $min',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: urgencyColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        urgency,
                        style: TextStyle(
                          color: urgencyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Colors.grey[200],
                  indent: 66,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ============ عنوان قسم ============

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF0F5132).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF0F5132), size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF0F5132),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ============ راسم الرسم الدائري المجوّف ============
// ============================================================

class _DonutChartPainter extends CustomPainter {
  final List<(double, Color)> data;
  final double strokeWidth;

  _DonutChartPainter({
    required this.data,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<double>(0, (s, d) => s + d.$1);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        (size.width < size.height ? size.width : size.height) / 2;

    double startAngle = -math.pi / 2;

    for (final item in data) {
      final sweepAngle = (item.$1 / total) * 2 * math.pi;

      // الخلفية الرمادية
      final bgPaint = Paint()
        ..color = item.$2.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(
            center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        bgPaint,
      );

      // الجزء الملون
      final paint = Paint()
        ..color = item.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(
            center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.03,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter old) =>
      old.data != data || old.strokeWidth != strokeWidth;
}