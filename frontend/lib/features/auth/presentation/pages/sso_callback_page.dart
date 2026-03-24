import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_notifier.dart';

/// Handles the Azure AD SSO redirect callback.
/// Extracts the authorization code from the URL and exchanges it for a local JWT.
class SsoCallbackPage extends ConsumerStatefulWidget {
  final String? code;
  final String? error;
  final String? errorDescription;

  const SsoCallbackPage({
    super.key,
    this.code,
    this.error,
    this.errorDescription,
  });

  @override
  ConsumerState<SsoCallbackPage> createState() => _SsoCallbackPageState();
}

class _SsoCallbackPageState extends ConsumerState<SsoCallbackPage> {
  bool _processing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    // Check if Azure AD returned an error
    if (widget.error != null) {
      setState(() {
        _processing = false;
        _errorMessage = widget.errorDescription ?? 'SSO authentication was cancelled or failed.';
      });
      return;
    }

    if (widget.code == null || widget.code!.isEmpty) {
      setState(() {
        _processing = false;
        _errorMessage = 'No authorization code received from Azure AD.';
      });
      return;
    }

    // Build the redirect URI (must match what was sent to Azure AD)
    final uri = Uri.base;
    final redirectUri = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/sso-callback';

    // Exchange the code for a local JWT
    await ref.read(authNotifierProvider.notifier).ssoLogin(widget.code!, redirectUri);

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    if (authState.isAuthenticated) {
      // SSO login succeeded — router redirect will handle navigation
      context.go('/login');
    } else {
      setState(() {
        _processing = false;
        _errorMessage = authState.error ?? 'SSO login failed. Your account may not exist in the system.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF2563EB)],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: _processing
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2563EB)),
                        SizedBox(height: 24),
                        Text(
                          'Completing sign-in...',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Sign-in Failed',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Text(
                            _errorMessage ?? 'An unknown error occurred.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Back to Login', style: TextStyle(color: Colors.white)),
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
