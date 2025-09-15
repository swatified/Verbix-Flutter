import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:verbix/services/screen_time_service.dart';

class ParentChildDashboardScreen extends StatefulWidget {
  final String childId;

  const ParentChildDashboardScreen({
    super.key,
    required this.childId,
  });

  @override
  State<ParentChildDashboardScreen> createState() => _ParentChildDashboardScreenState();
}

class _ParentChildDashboardScreenState extends State<ParentChildDashboardScreen> {
  bool _isLoading = true;
  String _childName = '';
  
    List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _yearlyData = [];
  
  // Screen time settings
  int _dailyTimeLimitMinutes = 120; // Default 2 hours (120 minutes)
  bool _screenTimeEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
            final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .get();
          
      if (childDoc.exists) {
        setState(() {
          _childName = '${childDoc.data()?['firstName'] ?? ''} ${childDoc.data()?['lastName'] ?? ''}';
        });
      }
      
            await Future.wait([
        _loadWeeklyData(),
        _loadMonthlyData(),
        _loadYearlyData(),
        _loadScreenTimeSettings(),
      ]);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadScreenTimeSettings() async {
    try {
      final enabled = await ScreenTimeService.isScreenTimeEnabled(widget.childId);
      final limitMinutes = await ScreenTimeService.getDailyTimeLimit(widget.childId);
      setState(() {
        _screenTimeEnabled = enabled;
        _dailyTimeLimitMinutes = limitMinutes; // Store directly in minutes
      });
    } catch (e) {
      debugPrint('Error loading screen time settings: $e');
    }
  }

  Future<void> _loadWeeklyData() async {
    final List<Map<String, dynamic>> weekData = [];
    
        final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.childId)
            .collection('progress')
            .doc(dateStr)
            .get();
        
        final String dayName = DateFormat('E').format(date);
        
        if (docSnapshot.exists) {
          weekData.add({
            'date': date,
            'label': dayName,
            'value': docSnapshot.data()?['practice_done'] ?? 0,
          });
        } else {
          weekData.add({
            'date': date,
            'label': dayName,
            'value': 0,
          });
        }
      } catch (e) {
        debugPrint('Error loading data for $dateStr: $e');
        final String dayName = DateFormat('E').format(date);
        weekData.add({
          'date': date,
          'label': dayName,
          'value': 0,
        });
      }
    }
    
    setState(() {
      _weeklyData = weekData;
    });
  }

  Future<void> _loadMonthlyData() async {
    final List<Map<String, dynamic>> monthData = [];
    
        final now = DateTime.now();
    
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.childId)
            .collection('progress')
            .doc(dateStr)
            .get();
        
        if (docSnapshot.exists) {
          monthData.add({
            'date': date,
            'label': DateFormat('MMM d').format(date),             'value': docSnapshot.data()?['practice_done'] ?? 0,
          });
        } else {
          monthData.add({
            'date': date,
            'label': DateFormat('MMM d').format(date),
            'value': 0,
          });
        }
      } catch (e) {
        debugPrint('Error loading data for $dateStr: $e');
        monthData.add({
          'date': date,
          'label': DateFormat('MMM d').format(date),
          'value': 0,
        });
      }
    }
    
    setState(() {
      _monthlyData = monthData;
    });
  }

  Future<void> _loadYearlyData() async {
    final List<Map<String, dynamic>> yearData = [];
    
        try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.childId)
          .collection('progress')
          .orderBy('date')
          .get();
      
      for (var doc in querySnapshot.docs) {
        final dateStr = doc.data()['date'] as String;
        final dateParts = dateStr.split('-');
        
        if (dateParts.length == 3) {
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          
          final date = DateTime(year, month, day);
          
          yearData.add({
            'date': date,
            'label': DateFormat('MMM d').format(date),
            'value': doc.data()['practice_done'] ?? 0,
          });
        }
      }
      
      setState(() {
        _yearlyData = yearData;
      });
    } catch (e) {
      debugPrint('Error loading yearly data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '$_childName\'s Dashboard',
          style: const TextStyle(
            color: Color(0xFF324259),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatisticsSummary(),
                  const SizedBox(height: 12),
                  _buildScreenTimeSettings(),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(),
                  const SizedBox(height: 12),
                  _buildMonthlyChart(),
                  const SizedBox(height: 14),
                  _buildYearlyContributionChart(),
                  const SizedBox(height: 26),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsSummary() {
        final int totalWeeklyPractices = _weeklyData.fold(0, (total, item) => total + (item['value'] as int));
    final int totalMonthlyPractices = _monthlyData.fold(0, (total, item) => total + (item['value'] as int));
    final int totalYearlyPractices = _yearlyData.fold(0, (total, item) => total + (item['value'] as int));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Practice Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324259),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'This Week',
                totalWeeklyPractices.toString(),
                Icons.calendar_today,
                const Color(0xFF1F5377),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'This Month',
                totalMonthlyPractices.toString(),
                Icons.date_range,
                const Color(0xFF3498DB),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Total',
                totalYearlyPractices.toString(),
                Icons.bar_chart,
                const Color(0xFF607D8B),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTimeSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: const Color(0xFF1F5377),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Screen Time Controls',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324259),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: const Text(
                  'BETA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Enable/Disable Toggle
          Row(
            children: [
              const Text(
                'Enable Screen Time Limits',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF324259),
                ),
              ),
              const Spacer(),
              Switch(
                value: _screenTimeEnabled,
                onChanged: (value) async {
                  setState(() {
                    _screenTimeEnabled = value;
                  });
                  
                  // Save to service
                  await ScreenTimeService.setScreenTimeEnabled(widget.childId, value);
                  
                  // Show confirmation
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value 
                            ? 'Screen time limits enabled' 
                            : 'Screen time limits disabled'
                        ),
                        backgroundColor: const Color(0xFF1F5377),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                activeColor: const Color(0xFF1F5377),
              ),
            ],
          ),
          
          if (_screenTimeEnabled) ...[
            const SizedBox(height: 16),
            
            // Time Limit Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Time Limit: ${_formatTimeLimit(_dailyTimeLimitMinutes)} per day',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF324259),
                  ),
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF1F5377),
                    inactiveTrackColor: const Color(0xFF1F5377).withValues(alpha: 0.3),
                    thumbColor: const Color(0xFF1F5377),
                    overlayColor: const Color(0xFF1F5377).withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _dailyTimeLimitMinutes.toDouble(),
                    min: 10.0, // 10 minutes minimum
                    max: 240.0, // 4 hours maximum (240 minutes)
                    divisions: 23, // (240-10)/10 = 23 divisions for 10-minute increments
                    onChanged: (value) {
                      setState(() {
                        _dailyTimeLimitMinutes = value.round();
                      });
                    },
                    onChangeEnd: (value) async {
                      // Save when user finishes adjusting
                      await ScreenTimeService.setDailyTimeLimit(widget.childId, value.round());
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Daily limit set to ${_formatTimeLimit(value.round())}'
                            ),
                            backgroundColor: const Color(0xFF1F5377),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                
                // Time markers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '10 min',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '4 hours',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Info message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Screen time limits help promote healthy usage habits. Your child will receive gentle reminders when approaching the limit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324259),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _weeklyData.isEmpty
                ? const Center(child: Text('No data available'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 10,                       barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${_weeklyData[groupIndex]['label']}: ${_weeklyData[groupIndex]['value']}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < _weeklyData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _weeklyData[value.toInt()]['label'],
                                    style: const TextStyle(
                                      color: Color(0xFF324259),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value % 2 == 0) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF324259),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      barGroups: List.generate(
                        _weeklyData.length,
                        (index) => BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: _weeklyData[index]['value'].toDouble(),
                              color: const Color(0xFF1F5377),
                              width: 20,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 2,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: const Color(0xFFE0E0E0),
                            strokeWidth: 1,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324259),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: _monthlyData.isEmpty
                ? const Center(child: Text('No data available'))
                : LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot spot) {
                              final index = spot.x.toInt();
                              if (index >= 0 && index < _monthlyData.length) {
                                return LineTooltipItem(
                                  '${_monthlyData[index]['label']}: ${spot.y.toInt()}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                              return LineTooltipItem('', const TextStyle());
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            _monthlyData.length, 
                            (index) => FlSpot(index.toDouble(), _monthlyData[index]['value'].toDouble()),
                          ),
                          isCurved: true,
                          color: const Color(0xFF1F5377),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: false,
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF1F5377).withValues(alpha:0.2),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() % 5 == 0 && value.toInt() < _monthlyData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _monthlyData[value.toInt()]['label'],
                                    style: const TextStyle(
                                      color: Color(0xFF324259),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value % 2 == 0) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF324259),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: const Color(0xFFE0E0E0),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      minX: 0,
                      maxX: _monthlyData.length.toDouble() - 1,
                      maxY: 10,                     ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyContributionChart() {
        if (_yearlyData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha:0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(child: Text('No yearly data available')),
      );
    }
    
        final int daysInYear = 365;
    final int cellsPerRow = 7;     final int numWeeks = (daysInYear / cellsPerRow).ceil();
    
        final Map<String, int> dateValueMap = {};
    for (var data in _yearlyData) {
      final date = data['date'] as DateTime;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      dateValueMap[dateStr] = data['value'] as int;
    }
    
        final List<DateTime> allDates = [];
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    
    for (int i = 0; i < daysInYear; i++) {
      final date = yearStart.add(Duration(days: i));
      if (date.isBefore(now.add(const Duration(days: 1)))) {
        allDates.add(date);
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Yearly Contribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324259),
            ),
          ),
          const SizedBox(height: 12),
          
                    AspectRatio(
            aspectRatio: 3.5,             child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(numWeeks, (weekIndex) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (dayIndex) {
                      final cellIndex = weekIndex * 7 + dayIndex;
                      
                      if (cellIndex >= allDates.length) {
                        return const Padding(
                          padding: EdgeInsets.all(1.0),
                          child: SizedBox(width: 8, height: 8),
                        );
                      }
                      
                      final date = allDates[cellIndex];
                      final dateStr = DateFormat('yyyy-MM-dd').format(date);
                      final value = dateValueMap[dateStr] ?? 0;
                      
                                            Color cellColor;
                      if (value == 0) {
                        cellColor = const Color(0xFFEEEEEE);
                      } else if (value <= 2) {
                        cellColor = const Color(0xFFAED6F1);
                      } else if (value <= 5) {
                        cellColor = const Color(0xFF5DADE2);
                      } else if (value <= 8) {
                        cellColor = const Color(0xFF3498DB);
                      } else {
                        cellColor = const Color(0xFF1F5377);
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.all(1.0),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
                    Wrap(
            spacing: 12.0,             runSpacing: 8.0,             children: [
              _buildColorLegendItem('None', const Color(0xFFEEEEEE)),
              _buildColorLegendItem('1-2', const Color(0xFFAED6F1)),
              _buildColorLegendItem('3-5', const Color(0xFF5DADE2)),
              _buildColorLegendItem('6-8', const Color(0xFF3498DB)),
              _buildColorLegendItem('9+', const Color(0xFF1F5377)),
            ],
          ),
        ],
      ),
    );
  }

    Widget _buildColorLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,            height: 8,            decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  /// Format time limit in minutes to readable string
  String _formatTimeLimit(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours hour${hours == 1 ? '' : 's'}';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours hour${hours == 1 ? '' : 's'} $remainingMinutes minutes';
    }
  }
}