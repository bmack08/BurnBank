// lib/screens/auth/phone_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:burnbank/services/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key}); // ✅ Fixed: removed duplication

  @override
  PhoneAuthScreenState createState() => PhoneAuthScreenState();
}

class PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String _verificationId = '';
  String _errorMessage = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _codeSent = true;
      _verificationId = '123456';
    });
  }

  Future<void> _submitCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithPhoneNumber(
        _verificationId,
        _codeController.text.trim(),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid code. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Authentication'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'assets/images/LOGO.png',
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 24),
            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1 234 567 8900',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyPhone,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send Verification Code'),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  hintText: '6-digit code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify Code'),
              ),
            ],
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
