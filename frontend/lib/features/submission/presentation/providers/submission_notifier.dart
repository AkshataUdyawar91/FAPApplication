import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/document_package.dart';
import '../../domain/usecases/get_submissions_usecase.dart';
import '../../domain/usecases/submit_documents_usecase.dart';

/// Submission state
class SubmissionState extends Equatable {
  final List<DocumentPackage> submissions;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final DocumentPackage? currentSubmission;

  // Files for upload
  final File? poFile;
  final File? invoiceFile;
  final File? costSummaryFile;
  final List<File> photoFiles;
  final List<File> additionalFiles;

  const SubmissionState({
    this.submissions = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.currentSubmission,
    this.poFile,
    this.invoiceFile,
    this.costSummaryFile,
    this.photoFiles = const [],
    this.additionalFiles = const [],
  });

  bool get canSubmit =>
      poFile != null &&
      invoiceFile != null &&
      costSummaryFile != null &&
      photoFiles.isNotEmpty &&
      photoFiles.length <= 20;

  SubmissionState copyWith({
    List<DocumentPackage>? submissions,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    DocumentPackage? currentSubmission,
    File? poFile,
    File? invoiceFile,
    File? costSummaryFile,
    List<File>? photoFiles,
    List<File>? additionalFiles,
  }) {
    return SubmissionState(
      submissions: submissions ?? this.submissions,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      currentSubmission: currentSubmission ?? this.currentSubmission,
      poFile: poFile ?? this.poFile,
      invoiceFile: invoiceFile ?? this.invoiceFile,
      costSummaryFile: costSummaryFile ?? this.costSummaryFile,
      photoFiles: photoFiles ?? this.photoFiles,
      additionalFiles: additionalFiles ?? this.additionalFiles,
    );
  }

  @override
  List<Object?> get props => [
        submissions,
        isLoading,
        isSubmitting,
        error,
        currentSubmission,
        poFile,
        invoiceFile,
        costSummaryFile,
        photoFiles,
        additionalFiles,
      ];
}

/// Submission state notifier
class SubmissionNotifier extends StateNotifier<SubmissionState> {
  final SubmitDocumentsUseCase submitDocumentsUseCase;
  final GetSubmissionsUseCase getSubmissionsUseCase;

  SubmissionNotifier({
    required this.submitDocumentsUseCase,
    required this.getSubmissionsUseCase,
  }) : super(const SubmissionState());

  void setPOFile(File? file) {
    state = state.copyWith(poFile: file);
  }

  void setInvoiceFile(File? file) {
    state = state.copyWith(invoiceFile: file);
  }

  void setCostSummaryFile(File? file) {
    state = state.copyWith(costSummaryFile: file);
  }

  void addPhotoFile(File file) {
    if (state.photoFiles.length < 20) {
      state = state.copyWith(photoFiles: [...state.photoFiles, file]);
    }
  }

  void removePhotoFile(int index) {
    final photos = List<File>.from(state.photoFiles);
    photos.removeAt(index);
    state = state.copyWith(photoFiles: photos);
  }

  void addAdditionalFile(File file) {
    state = state.copyWith(additionalFiles: [...state.additionalFiles, file]);
  }

  void removeAdditionalFile(int index) {
    final files = List<File>.from(state.additionalFiles);
    files.removeAt(index);
    state = state.copyWith(additionalFiles: files);
  }

  void clearFiles() {
    state = const SubmissionState();
  }

  Future<void> submitDocuments() async {
    state = state.copyWith(isSubmitting: true, error: null);

    final result = await submitDocumentsUseCase(
      poFile: state.poFile,
      invoiceFile: state.invoiceFile,
      costSummaryFile: state.costSummaryFile,
      photoFiles: state.photoFiles,
      additionalFiles: state.additionalFiles.isNotEmpty ? state.additionalFiles : null,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isSubmitting: false,
          error: failure.message,
        );
      },
      (submission) {
        state = state.copyWith(
          isSubmitting: false,
          error: null,
          currentSubmission: submission,
        );
        clearFiles();
      },
    );
  }

  Future<void> loadSubmissions({String? state}) async {
    this.state = this.state.copyWith(isLoading: true, error: null);

    final result = await getSubmissionsUseCase(state: state);

    result.fold(
      (failure) {
        this.state = this.state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (submissions) {
        this.state = this.state.copyWith(
          isLoading: false,
          error: null,
          submissions: submissions,
        );
      },
    );
  }
}
