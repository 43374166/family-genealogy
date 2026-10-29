import 'package:flutter/foundation.dart';

/// The family space a signed-in account belongs to.
///
/// The product is intentionally multi-family: branding inside the app comes
/// from this object, not from build-time constants. In the prototype it is
/// supplied by [DemoData]; after authentication it will be loaded from the
/// session / backend.
@immutable
class FamilyProfile {
  const FamilyProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.motto,
    required this.region,
    required this.subtitle,
    required this.memberCount,
    required this.branchCount,
  });

  final String id;
  final String name;
  final String surname;
  final String motto;
  final String region;
  final String subtitle;
  final int memberCount;
  final int branchCount;
}
