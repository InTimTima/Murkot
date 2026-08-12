import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../widgets/unlumen/murkot_fx.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final strings = context.strings;
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = strings.enterEmailCode);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    final error = await widget.authService.verifyEmailCode(code);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = error;
    });
  }

  Future<void> _resend() async {
    final strings = context.strings;
    setState(() {
      _isResending = true;
      _error = null;
      _info = null;
    });

    final error = await widget.authService.resendVerificationEmail();

    if (!mounted) return;
    setState(() {
      _isResending = false;
      if (error != null) {
        _error = error;
      } else {
        _info = strings.emailResent;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    final email = widget.authService.pendingEmail;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.emailVerificationTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email == null
                        ? strings.emailVerificationSent
                        : strings.emailVerificationSentTo(email),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '000000',
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _info!,
                      style: TextStyle(color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _verify,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: MurkotLoaderCompact(),
                          )
                        : Text(strings.confirmAction),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (_isLoading || _isResending) ? null : _resend,
                    child: _isResending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: MurkotLoaderCompact(size: 18),
                          )
                        : Text(strings.resendCode),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => widget.authService.cancelVerification(),
                    child: Text(strings.back),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
