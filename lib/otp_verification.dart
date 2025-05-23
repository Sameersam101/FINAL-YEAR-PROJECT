import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:email_otp/email_otp.dart';

class OTPVerificationDialog extends StatefulWidget {
  final EmailOTP emailOTP;
  final String email;

  const OTPVerificationDialog({
    super.key,
    required this.emailOTP,
    required this.email,
  });

  @override
  _OTPVerificationDialogState createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final _otpController = TextEditingController();
  String? _errorMessage;
  int _verificationAttempts = 0;

  Future<void> _verifyOTP() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      bool isVerified = await widget.emailOTP.verifyOTP(otp: _otpController.text.trim());
      if (isVerified) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _verificationAttempts++;
          _errorMessage = 'Invalid OTP';
        });
      }
    } catch (e) {
      setState(() {
        _verificationAttempts++;
        _errorMessage = 'Error verifying OTP: ${e.toString()}';
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _errorMessage = null;
      _otpController.clear();
    });

    try {
      // Reconfigure EmailOTP with the same email
      widget.emailOTP.setConfig(
        appEmail: "your-app-email@example.com", // Replace with your app's email
        appName: "Your App Name",
        userEmail: widget.email,
        otpLength: 6,
        otpType: "Numeric",
      );

      // Example in otp_verification.dart
      bool otpSent = await widget.emailOTP.sendOTP();
      if (otpSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New OTP sent to your email'),
            backgroundColor: const Color(0xFFF97316),
          ),
        );
        setState(() {
          _verificationAttempts = 0; // Reset attempts on resend
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to resend OTP';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error resending OTP: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(mediaQuery.size.width * 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verify OTP',
                  style: GoogleFonts.inter(
                    fontSize: mediaQuery.size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF221E22),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            Text(
              'Enter the 6-digit OTP sent to ${widget.email}',
              style: GoogleFonts.inter(
                fontSize: mediaQuery.size.width * 0.035,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'OTP',
                labelStyle: GoogleFonts.inter(
                  fontSize: mediaQuery.size.width * 0.035,
                  color: const Color(0xFF6B7280),
                ),
                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6B7280)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                errorText: _errorMessage,
                errorStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFEF4444),
                ),
              ),
              style: GoogleFonts.inter(fontSize: MediaQuery.of(context).size.width * 0.035),
            ),
            if (_verificationAttempts >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Please verify your email address is correct.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Verify',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: mediaQuery.size.height * 0.01),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _resendOTP,
                child: Text(
                  'Resend OTP',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}