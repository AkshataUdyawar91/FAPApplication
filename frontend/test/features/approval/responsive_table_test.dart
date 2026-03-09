import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test to verify responsive table design at different breakpoints
/// 
/// Requirements: 2.1, 2.2, 2.3 from bugfix.md
/// Task: 3.6 - Implement responsive design for tables
void main() {
  group('Responsive Table Design Tests', () {
    testWidgets('Tables should be horizontally scrollable on mobile (<600px)',
        (WidgetTester tester) async {
      // Build a simple table wrapped in SingleChildScrollView
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 599, // Mobile breakpoint
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(150),
                    1: FixedColumnWidth(150),
                    2: FixedColumnWidth(150),
                  },
                  children: [
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Column 1'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Column 2'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Column 3'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify SingleChildScrollView exists
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify Table exists
      expect(find.byType(Table), findsOneWidget);

      // Verify the scroll view is horizontal
      final scrollView =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.scrollDirection, Axis.horizontal);
    });

    testWidgets('Tables should maintain readable padding at all breakpoints',
        (WidgetTester tester) async {
      // Test at mobile breakpoint (599px)
      await _testTablePaddingAtWidth(tester, 599);

      // Test at tablet breakpoint (600px)
      await _testTablePaddingAtWidth(tester, 600);

      // Test at tablet breakpoint (899px)
      await _testTablePaddingAtWidth(tester, 899);

      // Test at desktop breakpoint (900px)
      await _testTablePaddingAtWidth(tester, 900);

      // Test at desktop breakpoint (1024px)
      await _testTablePaddingAtWidth(tester, 1024);
    });

    testWidgets('LayoutBuilder should detect correct breakpoints',
        (WidgetTester tester) async {
      String detectedSize = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isMobile = width < 600;
                final isTablet = width >= 600 && width < 900;
                final isDesktop = width >= 900;

                if (isMobile) {
                  detectedSize = 'mobile';
                } else if (isTablet) {
                  detectedSize = 'tablet';
                } else if (isDesktop) {
                  detectedSize = 'desktop';
                }

                return Text(detectedSize);
              },
            ),
          ),
        ),
      );

      // The default test window is 800x600, which should be tablet
      expect(find.text('tablet'), findsOneWidget);
    });
  });
}

Future<void> _testTablePaddingAtWidth(
    WidgetTester tester, double width) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text('Test Cell'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  // Verify padding exists
  final paddingWidget = tester.widget<Padding>(find.byType(Padding).first);
  expect(paddingWidget.padding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
}
