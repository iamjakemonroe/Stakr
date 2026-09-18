import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';

class EmailLinkScreen extends ConsumerStatefulWidget {
  const EmailLinkScreen({super.key});

  @override
  ConsumerState<EmailLinkScreen> createState() => _EmailLinkScreenState();
}

enum _Step { enterEmail, enterCode }

class _EmailLinkScreenState extends ConsumerState<EmailLinkScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  _Step _step = _Step.enterEmail;
  bool _isLinking = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    final isAnonymous = ref.read(isAnonymousProvider);
    setState(() {
      _isLoading = true;
      _isLinking = isAnonymous;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      if (isAnonymous) {
        await repo.linkEmail(email);
      } else {
        await repo.signInWithEmailOtp(email);
      }
      if (mounted) setState(() => _step = _Step.enterCode);
    } catch (e) {
      debugPrint('send code failed (isLinking=$isAnonymous): $e');
      setState(
        () =>
            _error = 'Could not send a code. Check the address and try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      if (_isLinking) {
        await repo.verifyLinkOtp(email: email, token: code);
      } else {
        await repo.verifySignInOtp(email: email, token: code);
      }
      // Navigation happens via the router's redirect.
    } catch (e) {
      setState(() => _error = 'That code didn\'t work. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In or Sign Up')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              if (_step == _Step.enterEmail) ..._buildEmailStep(),
              if (_step == _Step.enterCode) ..._buildCodeStep(),
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

  List<Widget> _buildEmailStep() {
    return [
      Text(
        'Enter your email and we\'ll send you a one-time code.',
        style: AppTextStyles.body(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Send Code',
        isLoading: _isLoading,
        onPressed: _sendCode,
      ),
    ];
  }

  List<Widget> _buildCodeStep() {
    return [
      Text(
        'Enter the code sent to ${_emailController.text.trim()}.',
        style: AppTextStyles.body(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Code',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Verify',
        isLoading: _isLoading,
        onPressed: _verifyCode,
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(
        onPressed: _isLoading
            ? null
            : () => setState(() => _step = _Step.enterEmail),
        child: const Text('Use a different email'),
      ),
    ];
  }
}
