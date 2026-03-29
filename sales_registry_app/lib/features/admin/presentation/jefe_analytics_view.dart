import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

class JefeAnalyticsView extends ConsumerStatefulWidget {
  const JefeAnalyticsView({super.key});

  @override
  ConsumerState<JefeAnalyticsView> createState() => _JefeAnalyticsViewState();
}

class _JefeAnalyticsViewState extends ConsumerState<JefeAnalyticsView> {
  bool _loading = true;
  double _totalRevenue = 0;
  double _totalDebt = 0;
  
  // Para Dona
  double _cashSales = 0;
  double _cardSales = 0;

  // Para L7D
  List<double> _last7DaysSales = List.filled(7, 0);
  List<String> _last7DaysLabels = [];

  // Para Ranking Productos
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;

    try {
      final responses = await Future.wait([
        Supabase.instance.client
            .from('sales')
            .select('amount, is_debt, payment_method, is_voided, timestamp, product_name_snapshot, access_keys(employee_name)')
            .eq('store_id', session.storeId)
            .eq('is_voided', false),
        Supabase.instance.client
            .from('products')
            .select('name, stock')
            .eq('store_id', session.storeId)
      ]);

      final List<dynamic> sales = responses[0] as List<dynamic>;
      final List<dynamic> productsData = responses[1] as List<dynamic>;
      
      Map<String, int> invMap = {};
      for (var p in productsData) {
         invMap[p['name'] ?? ''] = (p['stock'] as num?)?.toInt() ?? 0;
      }

      double revenue = 0;
      double debt = 0;
                      double cash = 0;
      double card = 0;
      Map<String, double> prodMap = {};

      // Prepare last 7 days metrics
      final now = DateTime.now();
      List<String> labels = [];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        labels.add('${d.day}/${d.month}');
      }
      List<double> l7dSales = List.filled(7, 0);

      for (var s in sales) {
        final double amount = (s['amount'] as num).toDouble();
        final bool isDebt = s['is_debt'] == true;
        final String pm = s['payment_method'] ?? 'cash';
        
        if (isDebt) {
          debt += amount;
        } else {
          revenue += amount;
          if (pm == 'card') {
            card += amount;
          } else {
            cash += amount;
          }

          // Products stats (only paid)
          final String prodName = s['product_name_snapshot'] ?? 'Desconocido';
          prodMap[prodName] = (prodMap[prodName] ?? 0) + 1; // Count ranking

          // Time stats
          if (s['timestamp'] != null) {
            final saleDate = DateTime.parse(s['timestamp']).toLocal();
            final diff = now.difference(DateTime(saleDate.year, saleDate.month, saleDate.day)).inDays;
            if (diff >= 0 && diff < 7) {
              l7dSales[6 - diff] += amount;
            }
          }
        }
      }

      final sortedProducts = prodMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final List<Map<String, dynamic>> finalTop = sortedProducts.take(15).map((e) {
          return {
             'name': e.key,
             'sold': e.value,
             'stock': invMap[e.key] ?? 0
          };
      }).toList();

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _totalDebt = debt;
          _cashSales = cash;
          _cardSales = card;
          _last7DaysSales = l7dSales;
          _last7DaysLabels = labels;
          _topProducts = finalTop;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Totals
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161b22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ingreso Neto Mágico', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('\$${_totalRevenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 26, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Cobros Pendientes', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('\$${_totalDebt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 26, fontWeight: FontWeight.w900)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pie Chart
          _buildCard(
            title: 'Distribución de Pagos',
            icon: Icons.pie_chart,
            iconColor: Colors.indigoAccent,
            child: SizedBox(
              height: 200,
              child: _totalRevenue + _totalDebt == 0
                  ? const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white54)))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 40,
                        sections: [
                          if (_cashSales > 0) PieChartSectionData(color: Colors.indigo, value: _cashSales, title: 'Efectivo', radius: 40, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          if (_cardSales > 0) PieChartSectionData(color: Colors.lightBlue, value: _cardSales, title: 'Digital', radius: 40, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          if (_totalDebt > 0) PieChartSectionData(color: Colors.orange, value: _totalDebt, title: 'Fiado', radius: 45, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 800),
                      swapAnimationCurve: Curves.easeInOutBack,
                    ),
            )
          ),

          const SizedBox(height: 20),

          // L7D Chart
          _buildCard(
            title: 'Ingresos Últimos 7 Días',
            icon: Icons.bar_chart,
            iconColor: Colors.greenAccent,
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _last7DaysSales.reduce((a, b) => a > b ? a : b) * 1.2 + 10, // Add padding
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey.shade800.withOpacity(0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '\$${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                        );
                      }
                    )
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= _last7DaysLabels.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_last7DaysLabels[value.toInt()], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: _last7DaysSales.asMap().entries.map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: Colors.greenAccent,
                        width: 16,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      )
                    ]
                  )).toList(),
                ),
                swapAnimationDuration: const Duration(milliseconds: 600),
                swapAnimationCurve: Curves.easeInOut,
              )
            )
          ),

          const SizedBox(height: 20),

          // Top Products Ranking
          _buildCard(
            title: 'Top 15 Productos Vendidos',
            icon: Icons.star,
            iconColor: Colors.amber,
            child: _topProducts.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay datos suficientes', style: TextStyle(color: Colors.white54))))
              : Column(
                  children: _topProducts.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2, color: Colors.amber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        Column(
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                               Text('${(p['sold'] as num).toInt()} vendidos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                               Text('${(p['stock'] as num).toInt()} en stock fisíco', style: TextStyle(color: (p['stock'] as num) <= 5 ? Colors.redAccent : Colors.white54, fontSize: 11)),
                           ]
                        ),
                      ],
                    ),
                  )).toList(),
              )
          ),
          
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Color iconColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
