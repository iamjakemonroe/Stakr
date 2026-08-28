import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';

/// Entry point for signed-out users: play immediately as a guest, or go
/// straight to email sign-in/sign-up. The router's redirect moves the user
/// to `/home` automatically once either path produces a session.
class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  bool _isSigningInAsGuest = false;
  String? _error;

  Future<void> _playAsGuest() async {
    setState(() {
      _isSigningInAsGuest = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
      // Navigation happens via the router's redirect once the auth state
      // stream emits the new session.
    } catch (e) {
      debugPrint('signInAnonymously failed: $e');
      setState(() => _error = 'Could not start a guest session. Try again.');
    } finally {
      if (mounted) setState(() => _isSigningInAsGuest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Stakr', style: AppTextStyles.display(fontSize: 44)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Compete for coins in classic games, online.',
                style: AppTextStyles.body(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Play as Guest',
                isLoading: _isSigningInAsGuest,
                onPressed: _playAsGuest,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.push('/auth/link'),
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Log In or Sign Up', textAlign: TextAlign.center),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
