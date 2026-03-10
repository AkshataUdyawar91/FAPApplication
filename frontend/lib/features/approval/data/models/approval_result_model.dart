/// Model representing the result of an approval workflow action from the API.
class ApprovalResultModel {
  final String packageId;
  final String newState;
  final String message;

  const ApprovalResultModel({
    required this.packageId,
    required this.newState,
    required this.message,
  });

  factory ApprovalResultModel.fromJson(Map<String, dynamic> json) {
    return ApprovalResultModel(
      packageId: json['packageId'] as String,
      newState: json['newState'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageId': packageId,
      'newState': newState,
      'message': message,
    };
  }
}
