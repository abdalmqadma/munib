import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/prayer_day.dart';
import '../../data/services/prayer_time_validator.dart';
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
  final PrayerTimeValidator _validator = PrayerTimeValidator();

  @override
  void initState() {
    super.initState();
    _data = widget.initialData
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> get _currentDay => _data[_currentDayIndex];

  List<String> get _currentWarnings => _validator.validateDay(_currentDay);

  List<String> get _allWarnings => _validator.validateAll(_data);

  void _updateValue(String key, String newValue) {
    setState(() {
      _data[_currentDayIndex][key] = newValue;
    });
  }

  Future<void> _editTime(String label, String key, String currentValue) async {
    final parts = currentValue.split(':');
    final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: hour != null && hour <= 23 ? hour : 0,
        minute: minute != null && minute <= 59 ? minute : 0,
      ),
    );

    if (picked != null) {
      _updateValue(
        key,
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _editDate() async {
    final current = DateTime.tryParse(_currentDay['date']?.toString() ?? '');
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _updateValue(
        'date',
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF071019),
        body: Center(
          child: Text(
            'لا توجد بيانات للمراجعة',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: SafeArea(
        child: Column(
          children: [
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Text(
              'تحقق من الأوقات وعدّل عند الحاجة',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _editDate,
                    icon: const Icon(Icons.edit_calendar, color: Colors.blue),
                  ),
                  Expanded(
                    child: Text(
                      _currentDay['date']?.toString().isNotEmpty == true
                          ? _currentDay['date'].toString()
                          : 'التاريخ غير معروف',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_month, color: Colors.white38),
                ],
              ),
            ),

            const SizedBox(height: 14),

            if (_data.length > 1)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    final selected = _currentDayIndex == index;
                    final hasWarnings = _validator.validateDay(_data[index]).isNotEmpty;
                    return GestureDetector(
                      onTap: () => setState(() => _currentDayIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: selected ? Colors.blue : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Row(
                            children: [
                              if (hasWarnings)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                                ),
                              Text(
                                'يوم ${index + 1}',
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (_currentWarnings.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _currentWarnings
                      .map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $warning',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.amber, fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            const SizedBox(height: 14),

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
                    _buildPrayerRow('الفجر', _currentDay['fajr'], 'fajr', '🌅'),
                    _buildPrayerRow('الشروق', _currentDay['sunrise'], 'sunrise', '☀️'),
                    _buildPrayerRow('الظهر', _currentDay['dhuhr'], 'dhuhr', '🌤️'),
                    _buildPrayerRow('العصر', _currentDay['asr'], 'asr', '🏙️'),
                    _buildPrayerRow('المغرب', _currentDay['maghrib'], 'maghrib', '🌇'),
                    _buildPrayerRow('العشاء', _currentDay['isha'], 'isha', '🌙'),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
              child: SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton(
                  onPressed: _allWarnings.isEmpty ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Text(
                    _allWarnings.isEmpty ? 'حفظ الأوقات ✓' : 'صحّح التحذيرات أولاً',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final prayers = _data.map((e) => PrayerDay.fromJson(e)).toList();
    await context.read<PrayerProvider>().setMonthlyPrayers(prayers);
    if (context.mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Widget _buildPrayerRow(
    String name,
    dynamic rawTime,
    String key,
    String icon,
  ) {
    final time = rawTime?.toString() ?? '';
    final valid = RegExp(r'^\d{1,2}:\d{2}\$').hasMatch(time);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _editTime(name, key, valid ? time : ''),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: valid
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                valid ? Icons.edit : Icons.warning_amber_rounded,
                color: valid ? Colors.blue : Colors.amber,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          Text(
            valid ? time : '--:--',
            style: TextStyle(
              color: valid ? Colors.blue : Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
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
