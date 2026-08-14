import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/services/azkar_data.dart';
import '../providers/prayer_provider.dart';

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final isEn = provider.language == 'English';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: provider.isDarkMode ? const Color(0xFF071019) : const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              mainAxisAlignment: isEn ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Text(
                  isEn ? 'Azkar' : 'الأذكار',
                  style: TextStyle(
                    color: provider.isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFFFFD166),
            unselectedLabelColor: Colors.white24,
            indicatorColor: Colors.transparent,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            tabs: [
              _AzkarTab(title: isEn ? 'Morning' : 'الصباح'),
              _AzkarTab(title: isEn ? 'Evening' : 'المساء'),
              _AzkarTab(title: isEn ? 'Prayers' : 'بعد الصلاة'),
              _AzkarTab(title: isEn ? 'Sleep' : 'النوم'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AzkarList(category: "Morning", isEn: isEn),
            AzkarList(category: "Evening", isEn: isEn),
            AzkarList(category: "After Prayer", isEn: isEn),
            AzkarList(category: "Sleep", isEn: isEn),
          ],
        ),
      ),
    );
  }
}

class _AzkarTab extends StatelessWidget {
  final String title;
  const _AzkarTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(child: Text(title, style: const TextStyle(fontSize: 16))),
      ),
    );
  }
}

class AzkarList extends StatelessWidget {
  final String category;
  final bool isEn;
  const AzkarList({super.key, required this.category, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final azkarData = AzkarData.allAzkar[category] ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: azkarData.length,
      itemBuilder: (context, index) {
        return AzkarCard(azkar: azkarData[index], isEn: isEn);
      },
    );
  }
}

class AzkarCard extends StatefulWidget {
  final Map<String, dynamic> azkar;
  final bool isEn;
  const AzkarCard({super.key, required this.azkar, required this.isEn});

  @override
  State<AzkarCard> createState() => _AzkarCardState();
}

class _AzkarCardState extends State<AzkarCard> {
  int _currentCount = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();
    final bool isCompleted = _currentCount >= widget.azkar['count'];
    final isDark = provider.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isCompleted ? const Color(0xFFFFD166).withValues(alpha: 0.2) : Colors.white10,
        ),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(
            widget.azkar['text'],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.isEn ? (isCompleted ? 'Completed' : 'Once') : widget.azkar['subtitle'],
            style: TextStyle(
              color: isCompleted ? const Color(0xFFFFD166) : Colors.white24,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSmallIcon(Icons.hexagon_outlined),
                  const SizedBox(width: 12),
                  _buildSmallIcon(Icons.favorite_border, color: Colors.orangeAccent),
                ],
              ),
              if (!isCompleted)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildCounterBtn(Icons.remove, () {
                        if (_currentCount > 0) setState(() => _currentCount--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          '$_currentCount',
                          style: const TextStyle(color: Color(0xFFFFD166), fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildCounterBtn(Icons.add, () {
                        if (_currentCount < widget.azkar['count']) setState(() => _currentCount++);
                      }),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "${widget.azkar['count']}/${widget.azkar['count']} ✓",
                    style: const TextStyle(color: Color(0xFFFFD166), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallIcon(IconData icon, {Color color = Colors.white38}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
