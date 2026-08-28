import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// Shown momentarily while the router's redirect decides between `/auth`
/// and `/home` based on whether a Supabase session was restored. Supabase
/// finishes restoring any persisted session before `runApp` (see main.dart),
/// so in practice this redirect happens almost immediately.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stakr', style: AppTextStyles.display(fontSize: 40)),
            const SizedBox(height: AppSpacing.lg),
            const CircularProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
