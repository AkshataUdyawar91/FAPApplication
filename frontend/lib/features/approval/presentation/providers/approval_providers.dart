import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/approval_remote_datasource.dart';
import '../../data/repositories/approval_repository_impl.dart';
import '../../domain/repositories/approval_repository.dart';
import '../../domain/usecases/approve_package_usecase.dart';
import '../../domain/usecases/reject_package_usecase.dart';
import '../../domain/usecases/request_reupload_usecase.dart';
import 'approval_notifier.dart';

final approvalRemoteDataSourceProvider = Provider<ApprovalRemoteDataSource>(
  (ref) => ApprovalRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final approvalRepositoryProvider = Provider<ApprovalRepository>(
  (ref) => ApprovalRepositoryImpl(ref.watch(approvalRemoteDataSourceProvider)),
);

final approvePackageUseCaseProvider = Provider<ApprovePackageUseCase>(
  (ref) => ApprovePackageUseCase(ref.watch(approvalRepositoryProvider)),
);

final rejectPackageUseCaseProvider = Provider<RejectPackageUseCase>(
  (ref) => RejectPackageUseCase(ref.watch(approvalRepositoryProvider)),
);

final requestReuploadUseCaseProvider = Provider<RequestReuploadUseCase>(
  (ref) => RequestReuploadUseCase(ref.watch(approvalRepositoryProvider)),
);

final approvalNotifierProvider =
    StateNotifierProvider<ApprovalNotifier, ApprovalState>(
  (ref) => ApprovalNotifier(
    ref.watch(approvalRepositoryProvider),
    ref.watch(approvePackageUseCaseProvider),
    ref.watch(rejectPackageUseCaseProvider),
    ref.watch(requestReuploadUseCaseProvider),
  ),
);
