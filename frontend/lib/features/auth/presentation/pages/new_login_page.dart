import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class NewLoginPage extends StatefulWidget {
  const NewLoginPage({super.key});

  @override
  State<NewLoginPage> createState() => _NewLoginPageState();
}

class _NewLoginPageState extends State<NewLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'));

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = 'agency@bajaj.com';
    _passwordController.text = 'Password123!';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post('/auth/login', data: {
        'email': _emailController.text,
        'password': _passwordController.text,
      });

      if (response.statusCode == 200 && mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/agency/conversational-submission',
          arguments: {
            'token': response.data['token'],
            'userName': response.data['fullName'],
          },
        );
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.response?.statusCode == 401
            ? 'Invalid email or password'
            : 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF1E40AF),
              Color(0xFF2563EB),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: const BoxDecoration(
                          color: Color(0xFF003087),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 32,
                                  color: Color(0xFF003087),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ClaimsIQ',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Agency Claim Submission Portal',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFBFDBFE),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Enter your email',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF003087), width: 2)),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 20),
                            Text('Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF003087), width: 2)),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              enabled: !_isLoading,
                              onSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20, height: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: _isLoading ? null : (v) => setState(() => _rememberMe = v ?? false),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Remember me', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                  ],
                                ),
                                TextButton(
                                  onPressed: _isLoading ? null : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Password reset coming soon')),
                                    );
                                  },
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  child: const Text('Forgot password?', style: TextStyle(fontSize: 14, color: Color(0xFF003087))),
                                ),
                              ],
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_errorMessage!, style: const TextStyle(fontSize: 14, color: Color(0xFFDC2626)))),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF003087),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Protected by Enterprise SSO. Authorized Personnel Only',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
