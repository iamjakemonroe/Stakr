import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/pop_card.dart';
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

  /// True when an anonymous (guest) user tried to save their account with
  /// an email that's already registered to a different account. Supabase
  /// correctly refuses to *link* it (that would silently merge two
  /// separate identities), but the guest still needs a way forward instead
  /// of a dead-end error — see [_loginWithExistingAccountInstead].
  bool _emailBelongsToAnotherAccount = false;

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
      _emailBelongsToAnotherAccount = false;
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
      setState(() => _error = _messageFor(e, wasLinking: isAnonymous));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// A guest hit `email_exists` trying to save their account — instead of
  /// leaving them stuck, send a normal sign-in code for the *existing*
  /// account. They'll be logged into that account (guest coins on the
  /// abandoned anonymous session are not carried over — Supabase has no
  /// way to merge two already-separate identities), which is what the
  /// person almost certainly wants: to get back into the account they
  /// already have, not to stay locked out of it.
  Future<void> _loginWithExistingAccountInstead() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _emailBelongsToAnotherAccount = false;
      _isLinking = false;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithEmailOtp(_emailController.text.trim());
      if (mounted) setState(() => _step = _Step.enterCode);
    } catch (e) {
      debugPrint('login-instead failed: $e');
      setState(() => _error = _messageFor(e, wasLinking: false));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps the handful of failures users actually hit to plain language,
  /// instead of one generic message that hides what's actually wrong
  /// (rate-limited vs. a real delivery failure vs. an already-registered
  /// email all need different next steps). Checked against the base
  /// [AuthException] — `code`/`statusCode` live there, but which concrete
  /// subclass shows up varies (e.g. a mid-send failure surfaces as
  /// [AuthRetryableFetchException], not [AuthApiException]), so narrowing
  /// to one subclass would silently miss real cases.
  String _messageFor(Object e, {required bool wasLinking}) {
    if (e is AuthException) {
      if (e.code == 'email_exists' && wasLinking) {
        _emailBelongsToAnotherAccount = true;
        return 'That email already has an account.';
      }
      if (e.code == 'over_email_send_rate_limit') {
        return 'Too many code requests — wait a few minutes and try again.';
      }
      if (e.statusCode == '500') {
        return 'We couldn\'t send that email right now. Try again shortly.';
      }
    }
    return 'Could not send a code. Check the address and try again.';
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
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                PopCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      if (_emailBelongsToAnotherAccount) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : _loginWithExistingAccountInstead,
                          child: const Text('Log in with this email instead'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
