import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'report_list_page.dart';
import 'rekap_page.dart';
import 'analysis_page.dart';
import 'company_search_page.dart';
import 'binwas_page.dart';
import 'binwas_provinsi_readonly_page.dart';
import 'evaluasi_dokumen_page.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  // Tab Lazy-Loading: hanya muat Batubara di awal, tab lain hanya dimuat saat pertama kali diklik
  final Set<int> _activatedIndices = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBEB), // Soft Pastel Light Yellow
              Color(0xFFFFFDF5), // Light Warm Cream
              Colors.white,       // Clean White
            ],
            stops: [0.0, 0.3, 0.8],
          ),
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            const ReportListPage(type: ReportType.batubara),
            _activatedIndices.contains(1)
                ? const ReportListPage(type: ReportType.mineral)
                : const SizedBox.shrink(),
            _activatedIndices.contains(2)
                ? const BinwasPage()
                : const SizedBox.shrink(),
            _activatedIndices.contains(3)
                ? const BinwasProvinsiReadonlyPage()
                : const SizedBox.shrink(),
            _activatedIndices.contains(4)
                ? const EvaluasiDokumenPage()
                : const SizedBox.shrink(),
            _activatedIndices.contains(5)
                ? const RekapPage()
                : const SizedBox.shrink(),
            _activatedIndices.contains(6)
                ? const AnalysisPage()
                : const SizedBox.shrink(),
            _activatedIndices.contains(7)
                ? const CompanySearchPage()
                : const SizedBox.shrink(),
          ],
        ),
      ),
      // Sleek Floating Bottom Navigation Bar
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B), // Solid Obsidian Black
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: const Color(0xFF18181B),
              indicatorColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Color(0xFFFBBF24), size: 18);
                }
                return const IconThemeData(color: Color(0xFF71717A), size: 18);
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontSize: 7.8,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFBBF24),
                    letterSpacing: 0.05,
                  );
                }
                return const TextStyle(
                  fontSize: 7.8,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF71717A),
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              height: 60,
              elevation: 0,
              onDestinationSelected: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _activatedIndices.add(idx);
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.terrain_outlined),
                  selectedIcon: Icon(Icons.terrain),
                  label: 'Batubara',
                ),
                NavigationDestination(
                  icon: Icon(Icons.diamond_outlined),
                  selectedIcon: Icon(Icons.diamond),
                  label: 'Mineral',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Binwas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.domain_verification_outlined),
                  selectedIcon: Icon(Icons.domain_verification),
                  label: 'Binwas Prov',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: 'Evaluasi',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Rekap',
                ),
                NavigationDestination(
                  icon: Icon(Icons.trending_up_outlined),
                  selectedIcon: Icon(Icons.trending_up),
                  label: 'Analisis',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: 'Cari',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
