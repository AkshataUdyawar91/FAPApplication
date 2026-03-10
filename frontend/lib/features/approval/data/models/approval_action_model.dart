/// Model representing an approval action record from the API.
class ApprovalActionModel {
  final String id;
  final String packageId;
  final String actorName;
  final String actorRole;
  final String actionType;
  final String previousState;
  final String newState;
  final String comment;
  final DateTime actionTimestamp;

  const ApprovalActionModel({
    required this.id,
    required this.packageId,
    required this.actorName,
    required this.actorRole,
    required this.actionType,
    required this.previousState,
    required this.newState,
    required this.comment,
    required this.actionTimestamp,
  });

  factory ApprovalActionModel.fromJson(Map<String, dynamic> json) {
    return ApprovalActionModel(
      id: json['id'] as String,
      packageId: json['packageId'] as String,
      actorName: json['actorName'] as String,
      actorRole: json['actorRole'] as String,
      actionType: json['actionType'] as String,
      previousState: json['previousState'] as String,
      newState: json['newState'] as String,
      comment: json['comment'] as String,
      actionTimestamp: DateTime.parse(json['actionTimestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageId': packageId,
      'actorName': actorName,
      'actorRole': actorRole,
      'actionType': actionType,
      'previousState': previousState,
      'newState': newState,
      'comment': comment,
      'actionTimestamp': actionTimestamp.toIso8601String(),
    };
  }
}
