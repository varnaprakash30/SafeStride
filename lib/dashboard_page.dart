import 'package:flutter/material.dart';
import 'package:safe_stride/home_page.dart';
import 'main.dart';
import 'package:fl_chart/fl_chart.dart';

int getTodayAlertCount() {
  int alertCount = 0;
  for (final log in logEntries) {
    if (log.time.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
      alertCount++;
    }
  }
  return alertCount;
}

Color getSafetyStatusColor(int count) {
  if (count >= 10) {
    return Colors.red;
  } else if (count >= 5) {
    return Colors.orange;
  }
  return Colors.green;
}

class DashboardPage extends StatefulWidget {
  final List<LogEntry> logEntries;

  const DashboardPage({super.key, required this.logEntries});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  

  @override
  void initState() {
    super.initState();
    
  }

  @override
  Widget build(BuildContext context) {
    final liveLogs = widget.logEntries.isEmpty ? logEntries : widget.logEntries;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFF121212),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                SafetyStatusCard(logEntries: liveLogs),
                const SizedBox(height: 16),
                AlertBarChart(logEntries: liveLogs),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LogsPage()),
                    );
                  },
                  child: const Text('View Logs'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildSafetyStatusCard() {
  final count = getTodayAlertCount();
  final color = getSafetyStatusColor(count);

  String message;
  if (count >= 10) {
    message = 'High-risk zone today ($count alerts). Please be more cautious near roadways.';
  } else if (count >= 5) {
    message = 'Moderate activity today ($count alerts). Stay alert in busy areas.';
  } else {
    message = 'Safe zone today ($count alerts). Low traffic exposure recorded.';
  }

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color, width: 1.5),
    ),
    child: Row(
      children: [
        Icon(Icons.shield, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Safety Status: ${count >= 10 ? "High Risk" : count >= 5 ? "Moderate" : "Safe"}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AlertBarChart extends StatelessWidget {
  final List<LogEntry> logEntries;

  const AlertBarChart({super.key, required this.logEntries});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final hourlyCounts = List<double>.filled(24, 0.0);

    for (final entry in logEntries) {
      final diff = entry.time.difference(startOfDay);
      if (diff.isNegative || diff.inHours >= 24) {
        continue;
      }
      final hourIndex = entry.time.hour;
      if (hourIndex >= 0 && hourIndex < hourlyCounts.length) {
        hourlyCounts[hourIndex] += 1;
      }
    }

    final groups = <BarChartGroupData>[];
    final labels = List<String>.generate(24, (index) {
      final hour = index;
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final suffix = hour < 12 ? 'AM' : 'PM';
      return '$displayHour:00 $suffix';
    });

    for (var i = 0; i < hourlyCounts.length; i++) {
      final count = hourlyCounts[i];
      var barColor = Colors.green;
      if (count >= 10) {
        barColor = Colors.red;
      } else if (count >= 5) {
        barColor = Colors.amber;
      }

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count > 0 ? count : 0.2,
              color: barColor,
              width: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 15,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hourly Alert Distribution',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 15,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < labels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  labels[index],
                                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white10,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: groups,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SafetyStatusCard extends StatelessWidget {
  final List<LogEntry> logEntries;

  const SafetyStatusCard({
    super.key,
    required this.logEntries,
  });

  int get _alertCount {
    int alertCount = 0;
    for (final log in logEntries) {
      if (log.time.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
        alertCount++;
      }
    }
    return alertCount;
  }

  Color get _statusColor {
    if (_alertCount >= 10) {
      return Colors.red;
    } else if (_alertCount >= 5) {
      return Colors.orange;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final count = _alertCount;
    final color = _statusColor;
    final title = count >= 10
        ? 'High Risk'
        : count >= 5
            ? 'Moderate'
            : 'Safe';

    final message = count >= 10
        ? 'High-risk zone today ($count alerts). Please be more cautious near roadways.'
        : count >= 5
            ? 'Moderate activity today ($count alerts). Stay alert in busy areas.'
            : 'Safe zone today ($count alerts). Low traffic exposure recorded.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Safety Status: $title',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

