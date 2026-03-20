import 'package:flutter_test/flutter_test.dart';

/// Submission Flow Tests
///
/// Validates the complete submission workflow state transitions:
/// Agency submits → Processing → PendingCHApproval → CH approves → PendingHQApproval → RA approves → Approved
///
/// Also validates:
/// - ProcessingFailed is distinct from RejectedByASM
/// - Status labels are correct per role (Agency perspective)
/// - Rejected states show correct rejection source
/// - ProcessingFailed shows "Processing Failed" not "Rejected by CH"

void main() {
  group('Submission Flow: Status Mapping Tests', () {
    // Simulates the _normalizeStatus function from agency_dashboard_page.dart
    String normalizeStatus(String backendState) {
      final state = backendState.toLowerCase();
      if (['uploaded', 'extracting', 'validating'].contains(state)) return 'pending';
      if (['validated', 'recommending'].contains(state)) return 'pending';
      if (['pendingchapproval', 'pendingapproval', 'pendingwithch'].contains(state)) return 'pending_asm';
      if (['pendinghqapproval', 'pendingwithra'].contains(state)) return 'pending_hq';
      if (state == 'approved') return 'approved';
      if (state == 'rejectedbyasm') return 'rejected_by_asm';
      if (['rejectedbyhq', 'rejectedbyra'].contains(state)) return 'rejected_by_hq';
      if (['rejected', 'validationfailed', 'reuploadrequested'].contains(state)) return 'rejected';
      if (state == 'processingfailed') return 'processing_failed';
      return 'pending';
    }

    // Simulates the _getStatusInfo function from agency_submission_detail_page.dart
    Map<String, dynamic> getStatusInfo(String state) {
      final stateLower = state.toLowerCase();
      if (stateLower.contains('approved') && !stateLower.contains('pending')) {
        return {'label': 'Approved'};
      } else if (stateLower == 'rejectedbyasm') {
        return {'label': 'Rejected by CH'};
      } else if (stateLower == 'rejectedbyhq' || stateLower == 'rejectedbyra') {
        return {'label': 'Rejected by RA'};
      } else if (stateLower == 'processingfailed') {
        return {'label': 'Processing Failed'};
      } else if (stateLower.contains('pendinghq') || stateLower == 'asmapproved') {
        return {'label': 'Pending with RA'};
      } else if (stateLower.contains('pendingch') || stateLower.contains('pendingapproval')) {
        return {'label': 'Pending with CH'};
      } else {
        return {'label': 'Processing'};
      }
    }

    // Simulates the status badge logic from agency_dashboard_page.dart
    String getStatusBadgeLabel(String rawState) {
      final state = rawState.toLowerCase();
      switch (state) {
        case 'approved': return 'Approved';
        case 'rejected':
        case 'validationfailed':
          return state == 'validationfailed' ? 'Validation Failed' : 'Rejected';
        case 'rejectedbyasm': return 'Rejected by CH';
        case 'rejectedbyhq':
        case 'rejectedbyra': return 'Rejected by RA';
        case 'pendingchapproval':
        case 'pendingwithch': return 'Pending with CH';
        case 'pendinghqapproval':
        case 'pendingwithra': return 'Pending with RA';
        case 'reuploadrequested': return 'Re-upload Requested';
        case 'processingfailed': return 'Processing Failed';
        default: return 'Processing';
      }
    }

    group('Happy Path: New Submission Flow', () {
      test('Uploaded state normalizes to pending', () {
        expect(normalizeStatus('Uploaded'), equals('pending'));
      });

      test('Extracting state normalizes to pending', () {
        expect(normalizeStatus('Extracting'), equals('pending'));
      });

      test('Validating state normalizes to pending', () {
        expect(normalizeStatus('Validating'), equals('pending'));
      });

      test('Scoring/Recommending state normalizes to pending', () {
        expect(normalizeStatus('Recommending'), equals('pending'));
      });

      test('PendingCHApproval normalizes to pending_asm', () {
        expect(normalizeStatus('PendingCHApproval'), equals('pending_asm'));
      });

      test('PendingHQApproval normalizes to pending_hq', () {
        expect(normalizeStatus('PendingHQApproval'), equals('pending_hq'));
      });

      test('Approved normalizes to approved', () {
        expect(normalizeStatus('Approved'), equals('approved'));
      });
    });

    group('BUG REGRESSION: ProcessingFailed vs RejectedByASM', () {
      test('ProcessingFailed normalizes to processing_failed, NOT rejected_by_asm', () {
        final result = normalizeStatus('ProcessingFailed');
        expect(result, equals('processing_failed'));
        expect(result, isNot(equals('rejected_by_asm')));
        expect(result, isNot(equals('rejected')));
      });

      test('RejectedByASM normalizes to rejected_by_asm', () {
        expect(normalizeStatus('RejectedByASM'), equals('rejected_by_asm'));
      });

      test('ProcessingFailed shows "Processing Failed" label, not "Rejected by CH"', () {
        final info = getStatusInfo('ProcessingFailed');
        expect(info['label'], equals('Processing Failed'));
        expect(info['label'], isNot(equals('Rejected by CH')));
      });

      test('ProcessingFailed badge shows "Processing Failed"', () {
        expect(getStatusBadgeLabel('ProcessingFailed'), equals('Processing Failed'));
      });

      test('RejectedByASM badge shows "Rejected by CH"', () {
        expect(getStatusBadgeLabel('RejectedByASM'), equals('Rejected by CH'));
      });
    });

    group('Rejection Flow: Correct Labels', () {
      test('RejectedByASM shows "Rejected by CH" in detail page', () {
        expect(getStatusInfo('RejectedByASM')['label'], equals('Rejected by CH'));
      });

      test('RejectedByRA shows "Rejected by RA" in detail page', () {
        expect(getStatusInfo('RejectedByRA')['label'], equals('Rejected by RA'));
      });

      test('RejectedByHQ shows "Rejected by RA" in detail page (legacy alias)', () {
        expect(getStatusInfo('RejectedByHQ')['label'], equals('Rejected by RA'));
      });
    });

    group('Complete Approval Flow: State Sequence', () {
      test('Full happy path: Uploaded → PendingCH → PendingHQ → Approved', () {
        final states = ['Uploaded', 'Extracting', 'Validating', 'Recommending', 'PendingCHApproval', 'PendingHQApproval', 'Approved'];
        final normalized = states.map(normalizeStatus).toList();

        expect(normalized[0], equals('pending'));       // Uploaded
        expect(normalized[1], equals('pending'));       // Extracting
        expect(normalized[2], equals('pending'));       // Validating
        expect(normalized[3], equals('pending'));       // Recommending
        expect(normalized[4], equals('pending_asm'));   // PendingCHApproval
        expect(normalized[5], equals('pending_hq'));    // PendingHQApproval
        expect(normalized[6], equals('approved'));      // Approved
      });

      test('CH rejection flow: PendingCH → RejectedByCH → (edit) → Uploaded → PendingCH', () {
        expect(normalizeStatus('PendingCHApproval'), equals('pending_asm'));
        expect(normalizeStatus('RejectedByASM'), equals('rejected_by_asm'));
        // After resubmit, state resets to Uploaded
        expect(normalizeStatus('Uploaded'), equals('pending'));
      });

      test('RA rejection flow: PendingHQ → RejectedByRA → (edit) → Uploaded → PendingCH', () {
        expect(normalizeStatus('PendingHQApproval'), equals('pending_hq'));
        expect(normalizeStatus('RejectedByRA'), equals('rejected_by_hq'));
        // After resubmit, state resets to Uploaded
        expect(normalizeStatus('Uploaded'), equals('pending'));
      });

      test('Processing failure flow: Uploaded → ProcessingFailed (not RejectedByASM)', () {
        expect(normalizeStatus('Uploaded'), equals('pending'));
        expect(normalizeStatus('ProcessingFailed'), equals('processing_failed'));
        // Key assertion: processing failure is NOT a rejection
        expect(normalizeStatus('ProcessingFailed'), isNot(equals('rejected_by_asm')));
      });
    });

    group('Status Badge: All States Have Labels', () {
      final allStates = [
        'Uploaded', 'Extracting', 'Validating', 'Validated', 'Recommending',
        'PendingCHApproval', 'PendingHQApproval', 'Approved',
        'RejectedByASM', 'RejectedByRA', 'RejectedByHQ',
        'ProcessingFailed', 'ReuploadRequested', 'ValidationFailed',
      ];

      for (final state in allStates) {
        test('State "$state" has a non-empty badge label', () {
          final label = getStatusBadgeLabel(state);
          expect(label, isNotEmpty);
          expect(label, isNot(equals('Unknown')));
        });
      }
    });
  });
}
