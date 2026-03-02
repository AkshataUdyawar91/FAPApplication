import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bajaj_document_processing/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BajajDocumentProcessingApp(),
      ),
    );

    expect(find.text('Bajaj Document Processing System'), findsOneWidget);
  });
}
