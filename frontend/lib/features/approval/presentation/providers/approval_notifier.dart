import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../../submission/domain/entities/document_package.dart';
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

  const ApprovalState({
    this.isLoading = false,
    this.error,
    this.currentPackage,
    this.pendingPackages = const [],
    this.actionSuccess = false,
  });

  ApprovalState copyWith({
    bool? isLoading,
    String? error,
    DocumentPackage? currentPackage,
    List<DocumentPackage>? pendingPackages,
    bool? actionSuccess,
  }) {
    return ApprovalState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPackage: currentPackage ?? this.currentPackage,
      pendingPackages: pendingPackages ?? this.pendingPackages,
      actionSuccess: actionSuccess ?? this.actionSuccess,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        error,
        currentPackage,
        pendingPackages,
        actionSuccess,
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

  void clearError() {
    state = state.copyWith(error: null);
  }

  void resetActionSuccess() {
    state = state.copyWith(actionSuccess: false);
  }
}
