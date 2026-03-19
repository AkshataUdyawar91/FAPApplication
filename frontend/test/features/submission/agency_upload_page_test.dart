// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:dio/dio.dart';
// import 'package:mockito/mockito.dart';
// import 'package:mockito/annotations.dart';
// import 'package:bajaj_document_processing/features/submission/presentation/pages/agency_upload_page.dart';

// @GenerateMocks([Dio])
// import 'agency_upload_page_test.mocks.dart';

// // ---------------------------------------------------------------------------
// // Helpers
// // ---------------------------------------------------------------------------

// /// Stubs the two mandatory init calls so the widget can mount without errors.
// void _stubInitCalls(MockDio mockDio, {List<dynamic> states = const []}) {
//   // /pos — PO dropdown
//   when(mockDio.get(
//     '/pos',
//     queryParameters: anyNamed('queryParameters'),
//     options: anyNamed('options'),
//   )).thenAnswer((_) async => Response(
//         data: <dynamic>[],
//         statusCode: 200,
//         requestOptions: RequestOptions(path: '/pos'),
//       ));

//   // /pos/states — Indian states dropdown
//   when(mockDio.get(
//     '/pos/states',
//     options: anyNamed('options'),
//   )).thenAnswer((_) async => Response(
//         data: states,
//         statusCode: 200,
//         requestOptions: RequestOptions(path: '/pos/states'),
//       ));
// }

// /// Pumps the [AgencyUploadPage] and settles all async work.
// Future<void> _pumpPage(WidgetTester tester, MockDio mockDio) async {
//   await tester.pumpWidget(MaterialApp(
//     home: AgencyUploadPage(
//       token: 'test-token',
//       userName: 'Test User',
//       dio: mockDio,
//     ),
//   ));
//   // Let initState futures resolve
//   await tester.pumpAndSettle();
// }

// // ---------------------------------------------------------------------------
// // Tests
// // ---------------------------------------------------------------------------

// void main() {
//   group('AgencyUploadPage — /pos/states API', () {
//     late MockDio mockDio;

//     setUp(() {
//       mockDio = MockDio();
//     });

//     testWidgets(
//         'calls GET /pos/states on init and populates state dropdown',
//         (tester) async {
//       final statesData = [
//         {'stateName': 'Maharashtra'},
//         {'stateName': 'Karnataka'},
//         {'stateName': 'Tamil Nadu'},
//       ];

//       _stubInitCalls(mockDio, states: statesData);
//       await _pumpPage(tester, mockDio);

//       // Verify the API was called exactly once
//       verify(mockDio.get(
//         '/pos/states',
//         options: anyNamed('options'),
//       )).called(1);

//       // The dropdown hint should be visible (no state selected yet)
//       expect(find.text('Select state'), findsOneWidget);
//     });

//     testWidgets(
//         'renders state names as dropdown items after successful load',
//         (tester) async {
//       final statesData = [
//         {'stateName': 'Maharashtra'},
//         {'stateName': 'Karnataka'},
//       ];

//       _stubInitCalls(mockDio, states: statesData);
//       await _pumpPage(tester, mockDio);

//       // Open the dropdown
//       await tester.tap(find.text('Select state'));
//       await tester.pumpAndSettle();

//       expect(find.text('Maharashtra'), findsWidgets);
//       expect(find.text('Karnataka'), findsWidgets);
//     });

//     testWidgets(
//         'handles empty states list without crashing',
//         (tester) async {
//       _stubInitCalls(mockDio, states: []);
//       await _pumpPage(tester, mockDio);

//       // Dropdown hint still present, no items to show
//       expect(find.text('Select state'), findsOneWidget);
//     });

//     testWidgets(
//         'handles /pos/states API error gracefully — dropdown stays empty',
//         (tester) async {
//       // /pos succeeds
//       when(mockDio.get(
//         '/pos',
//         queryParameters: anyNamed('queryParameters'),
//         options: anyNamed('options'),
//       )).thenAnswer((_) async => Response(
//             data: <dynamic>[],
//             statusCode: 200,
//             requestOptions: RequestOptions(path: '/pos'),
//           ));

//       // /pos/states throws
//       when(mockDio.get(
//         '/pos/states',
//         options: anyNamed('options'),
//       )).thenThrow(DioException(
//         requestOptions: RequestOptions(path: '/pos/states'),
//         message: 'Network error',
//       ));

//       await _pumpPage(tester, mockDio);

//       // Page should still render — no crash
//       expect(find.text('Select state'), findsOneWidget);
//     });

//     testWidgets(
//         'selecting a state updates the dropdown value',
//         (tester) async {
//       final statesData = [
//         {'stateName': 'Rajasthan'},
//         {'stateName': 'Gujarat'},
//       ];

//       _stubInitCalls(mockDio, states: statesData);
//       await _pumpPage(tester, mockDio);

//       // Open dropdown and pick a state
//       await tester.tap(find.text('Select state'));
//       await tester.pumpAndSettle();

//       await tester.tap(find.text('Rajasthan').last);
//       await tester.pumpAndSettle();

//       // The selected value should now be visible
//       expect(find.text('Rajasthan'), findsOneWidget);
//     });
//   });
// }
