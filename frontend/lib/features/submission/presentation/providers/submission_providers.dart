import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/document_remote_datasource.dart';
import '../../data/repositories/document_repository_impl.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/usecases/get_submissions_usecase.dart';
import '../../domain/usecases/submit_documents_usecase.dart';
import 'submission_notifier.dart';

// Data source
final documentRemoteDataSourceProvider = Provider<DocumentRemoteDataSource>((ref) {
  return DocumentRemoteDataSourceImpl(ref.watch(dioClientProvider));
});

// Repository
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(
    remoteDataSource: ref.watch(documentRemoteDataSourceProvider),
  );
});

// Use cases
final submitDocumentsUseCaseProvider = Provider<SubmitDocumentsUseCase>((ref) {
  return SubmitDocumentsUseCase(ref.watch(documentRepositoryProvider));
});

final getSubmissionsUseCaseProvider = Provider<GetSubmissionsUseCase>((ref) {
  return GetSubmissionsUseCase(ref.watch(documentRepositoryProvider));
});

// State notifier
final submissionNotifierProvider =
    StateNotifierProvider<SubmissionNotifier, SubmissionState>((ref) {
  return SubmissionNotifier(
    submitDocumentsUseCase: ref.watch(submitDocumentsUseCaseProvider),
    getSubmissionsUseCase: ref.watch(getSubmissionsUseCaseProvider),
  );
});
