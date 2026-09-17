import 'package:flutter/material.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';
import 'reports_screen.dart';
import 'profits_screen.dart';
import 'customers_screen.dart';
const _primary = Color(0xFF0F5132);

class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const PosScreen(),
    const InventoryScreen(),
    const InvoicesScreen(),
    const CustomersScreen(),
    const ReportsScreen(),
    const ProfitsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _primary,
          unselectedItemColor: Colors.grey[500],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: 'نقطة البيع',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'المخزون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'الفواتير',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined),
              activeIcon: Icon(Icons.people_alt),
              label: 'العملاء',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'التقارير',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.savings_outlined),
              activeIcon: Icon(Icons.savings),
              label: 'الأرباح',
            ),
          ],
        ),
      ),
    );
  }
}
