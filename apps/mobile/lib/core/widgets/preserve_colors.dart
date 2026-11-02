import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../services/app_settings.dart';

/// Re-applies the global dark-mode filter so a subtree keeps its original
/// colours. Used for photos, avatars, QR codes and the full-screen crop editor:
/// those surfaces should look the same in light and dark mode.
class PreserveColors extends StatelessWidget {
  const PreserveColors({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    if (!settings.isDarkFor(context)) return child;
    return ColorFiltered(colorFilter: AppTheme.darkModeFilter, child: child);
  }
}
