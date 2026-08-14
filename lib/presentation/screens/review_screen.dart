import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/prayer_day.dart';
import '../providers/prayer_provider.dart';

class ReviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialData;
  const ReviewScreen({super.key, required this.initialData});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<Map<String, dynamic>> _data;
  int _currentDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _data = List<Map<String, dynamic>>.from(widget.initialData);
  }

  void _updateTime(String prayerKey, String newValue) {
    setState(() {
      _data[_currentDayIndex][prayerKey] = newValue;
    });
  }

  Future<void> _editTime(String label, String key, String currentValue) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(currentValue.split(':')[0]),
        minute: int.parse(currentValue.split(':')[1]),
      ),
    );
    if (picked != null) {
      final newTime = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      _updateTime(key, newTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF071019),
        body: Center(
          child: Text("لا توجد بيانات للمراجعة", style: TextStyle(color: Colors.white60)),
        ),
      );
    }

    final currentDay = _data[_currentDayIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'مراجعة الأوقات',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Text(
              'تحقق من الأوقات وعدّل عند الحاجة',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Date Selector (if multiple days)
            if (_data.length > 1)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _currentDayIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _currentDayIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Text(
                            "يوم ${index + 1}",
                            style: TextStyle(color: isSelected ? Colors.white : Colors.white60),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Table Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 35),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تعديل', style: TextStyle(color: Colors.white38, fontSize: 14)),
                  Text('الوقت', style: TextStyle(color: Colors.white38, fontSize: 14)),
                  Text('الصلاة', style: TextStyle(color: Colors.white38, fontSize: 14)),
                ],
              ),
            ),

            // Prayer Table Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    _buildPrayerRow('الفجر', currentDay['fajr'], 'fajr', '🌅'),
                    _buildPrayerRow('الشروق', currentDay['sunrise'], 'sunrise', '☀️'),
                    _buildPrayerRow('الظهر', currentDay['dhuhr'], 'dhuhr', '🌤️'),
                    _buildPrayerRow('العصر', currentDay['asr'], 'asr', '🏙️'),
                    _buildPrayerRow('المغرب', currentDay['maghrib'], 'maghrib', '🌇'),
                    _buildPrayerRow('العشاء', currentDay['isha'], 'isha', '🌙'),
                  ],
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: () async {
                    final prayers = _data.map((e) => PrayerDay.fromJson(e)).toList();
                    await context.read<PrayerProvider>().setMonthlyPrayers(prayers);
                    if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text(
                    'حفظ الأوقات ✓',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRow(String name, String time, String key, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          // Edit Button
          GestureDetector(
            onTap: () => _editTime(name, key, time),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit, color: Colors.blue, size: 18),
            ),
          ),
          const Spacer(),
          // Time
          Text(
            time,
            style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // Prayer Name and Icon
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              Text(icon, style: const TextStyle(fontSize: 20)),
            ],
          ),
        ],
      ),
    );
  }
}
