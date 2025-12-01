import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardChart extends StatelessWidget {
  final String title;
  final List<FlSpot> dataPoints;
  final Color? color;
  final double minY;
  final double maxY;
  final String unit;

  const DashboardChart({
    super.key,
    required this.title,
    required this.dataPoints,
    this.color,
    this.minY = 0,
    this.maxY = 100,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartColor = color ?? theme.primaryColor;

    double minX = 0;
    double maxX = 10;
    if (dataPoints.isNotEmpty) {
      minX = dataPoints.first.x;
      maxX = dataPoints.last.x;
      // Ensure we have a range
      if (minX == maxX) {
        minX -= 1000 * 60; // -1 min
        maxX += 1000 * 60; // +1 min
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: theme.cardColor,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                        final dateStr = DateFormat('MMM d, HH:mm:ss').format(date);
                        return LineTooltipItem(
                          '$dateStr\n${spot.y.toStringAsFixed(1)} $unit',
                          theme.textTheme.bodySmall!.copyWith(
                            color: chartColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.dividerColor.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxX - minX) / 3 <= 0 ? 1 : (maxX - minX) / 3,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('HH:mm').format(date),
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY - minY) / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: theme.textTheme.bodySmall,
                        );
                      },
                      reservedSize: 42,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: dataPoints,
                    isCurved: false,
                    color: chartColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(
                      show: true,
                      getDotPainter: _getDotPainter,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: chartColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static FlDotPainter _getDotPainter(
    FlSpot spot,
    double xPercentage,
    LineChartBarData bar,
    int index,
  ) {
    return FlDotCirclePainter(
      radius: 2,
      color: bar.color ?? Colors.white,
      strokeWidth: 0,
    );
  }
}

