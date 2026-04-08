import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:phytopi_dashboard/features/auth/providers/auth_provider.dart';
import 'package:phytopi_dashboard/features/dashboard/providers/device_provider.dart';
import 'package:phytopi_dashboard/features/dashboard/screens/dashboard_screen.dart';

void main() {
  group('PhytoPi Dashboard Tests', () {
    testWidgets('Dashboard renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DeviceProvider()),
          ],
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );

      // Smoke check: app bar title should exist.
      expect(find.textContaining('PhytoPi'), findsWidgets);
    });

    testWidgets('Navigation menu opens from FAB', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => DeviceProvider()),
          ],
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Landing page'), findsOneWidget);
    });
  });
}
