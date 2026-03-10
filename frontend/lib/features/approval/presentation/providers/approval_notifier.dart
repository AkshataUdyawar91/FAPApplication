import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../../submission/domain/entities/document_package.dart';
import '../../data/models/approval_action_model.dart';
import '../../domain/repositories/approval_repository.dart';
import '../../domain/usecases/approve_package_usecase.dart';
import '../../domain/usecases/reject_package_usecase.dart';
import '../../domain/usecases/request_reupload_usecase.dart';

class ApprovalState extends Equatable {
  final bool isLoading;
  final String? error;
  final DocumentPackage? currentPackage;
  final List<DocumentPackage> pendingPackages;
  final bool actionSuccess;
  final List<ApprovalActionModel> approvalHistory;
  final bool isHistoryLoading;
  final String? historyError;

  const ApprovalState({
    this.isLoading = false,
    this.error,
    this.currentPackage,
    this.pendingPackages = const [],
    this.actionSuccess = false,
    this.approvalHistory = const [],
    this.isHistoryLoading = false,
    this.historyError,
  });

  ApprovalState copyWith({
    bool? isLoading,
    String? error,
    DocumentPackage? currentPackage,
    List<DocumentPackage>? pendingPackages,
    bool? actionSuccess,
    List<ApprovalActionModel>? approvalHistory,
    bool? isHistoryLoading,
    String? historyError,
  }) {
    return ApprovalState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPackage: currentPackage ?? this.currentPackage,
      pendingPackages: pendingPackages ?? this.pendingPackages,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      approvalHistory: approvalHistory ?? this.approvalHistory,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      historyError: historyError,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        error,
        currentPackage,
        pendingPackages,
        actionSuccess,
        approvalHistory,
        isHistoryLoading,
        historyError,
      ];
}

class ApprovalNotifier extends StateNotifier<ApprovalState> {
  final ApprovalRepository repository;
  final ApprovePackageUseCase approvePackageUseCase;
  final RejectPackageUseCase rejectPackageUseCase;
  final RequestReuploadUseCase requestReuploadUseCase;

  ApprovalNotifier(
    this.repository,
    this.approvePackageUseCase,
    this.rejectPackageUseCase,
    this.requestReuploadUseCase,
  ) : super(const ApprovalState());

  Future<void> loadPendingPackages() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.getPendingPackages();

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (packages) => state = state.copyWith(
        isLoading: false,
        pendingPackages: packages,
      ),
    );
  }

  Future<void> loadPackageDetails(String packageId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.getPackageDetails(packageId);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (package) => state = state.copyWith(
        isLoading: false,
        currentPackage: package,
      ),
    );
  }

  Future<void> approvePackage(String packageId) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await approvePackageUseCase(packageId);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) => state = state.copyWith(
        isLoading: false,
        actionSuccess: true,
      ),
    );
  }

  Future<void> rejectPackage(String packageId, String reason) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await rejectPackageUseCase(packageId, reason);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) => state = state.copyWith(
        isLoading: false,
        actionSuccess: true,
      ),
    );
  }

  Future<void> requestReupload(
    String packageId,
    List<String> fields,
    String reason,
  ) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await requestReuploadUseCase(packageId, fields, reason);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) => state = state.copyWith(
        isLoading: false,
        actionSuccess: true,
      ),
    );
  }

  /// ASM approves a package. Transitions to PendingHQApproval.
  Future<void> asmApprove(String packageId, String comment) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await repository.asmApprove(packageId, comment);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) {
        state = state.copyWith(isLoading: false, actionSuccess: true);
        loadPackageDetails(packageId);
        fetchApprovalHistory(packageId);
      },
    );
  }

  /// ASM rejects a package. Transitions to RejectedByASM.
  Future<void> asmReject(String packageId, String comment) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await repository.asmReject(packageId, comment);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) {
        state = state.copyWith(isLoading: false, actionSuccess: true);
        loadPackageDetails(packageId);
        fetchApprovalHistory(packageId);
      },
    );
  }

  /// RA approves a package. Transitions to Approved.
  Future<void> raApprove(String packageId, String comment) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await repository.raApprove(packageId, comment);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) {
        state = state.copyWith(isLoading: false, actionSuccess: true);
        loadPackageDetails(packageId);
        fetchApprovalHistory(packageId);
      },
    );
  }

  /// RA rejects a package. Transitions to RejectedByRA.
  Future<void> raReject(String packageId, String comment) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await repository.raReject(packageId, comment);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) {
        state = state.copyWith(isLoading: false, actionSuccess: true);
        loadPackageDetails(packageId);
        fetchApprovalHistory(packageId);
      },
    );
  }

  /// Agency resubmits a rejected package. Transitions to PendingASMApproval.
  Future<void> resubmit(String packageId, String comment) async {
    state = state.copyWith(isLoading: true, error: null, actionSuccess: false);

    final result = await repository.resubmit(packageId, comment);

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
        actionSuccess: false,
      ),
      (_) {
        state = state.copyWith(isLoading: false, actionSuccess: true);
        loadPackageDetails(packageId);
        fetchApprovalHistory(packageId);
      },
    );
  }

  /// Fetches the approval history for a package.
  Future<void> fetchApprovalHistory(String packageId) async {
    state = state.copyWith(isHistoryLoading: true, historyError: null);

    final result = await repository.getApprovalHistory(packageId);

    result.fold(
      (failure) => state = state.copyWith(
        isHistoryLoading: false,
        historyError: failure.message,
      ),
      (history) => state = state.copyWith(
        isHistoryLoading: false,
        approvalHistory: history,
      ),
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void resetActionSuccess() {
    state = state.copyWith(actionSuccess: false);
  }
}
