import 'package:flutter/foundation.dart';

enum ActivityKind { request, joined, backup, approved }

@immutable
class FamilyActivity {
  const FamilyActivity({
    required this.id,
    required this.actor,
    required this.action,
    required this.detail,
    required this.time,
    required this.kind,
    this.needsReview = false,
  });

  final String id;
  final String actor;
  final String action;
  final String detail;
  final String time;
  final ActivityKind kind;
  final bool needsReview;
}

enum RequestStatus { pending, approved, rejected, cancelled }

@immutable
class EditRequest {
  const EditRequest({
    required this.id,
    required this.title,
    required this.targetName,
    required this.changedFields,
    required this.submittedAt,
    required this.status,
    this.reviewNote,
    this.reviewedAt,
  });

  final String id;
  final String title;
  final String targetName;
  final List<String> changedFields;
  final String submittedAt;
  final RequestStatus status;
  final String? reviewNote;
  final String? reviewedAt;
}

enum MessageKind { review, family, system }

@immutable
class FamilyMessage {
  const FamilyMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.kind,
    this.unread = false,
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final MessageKind kind;
  final bool unread;
}
