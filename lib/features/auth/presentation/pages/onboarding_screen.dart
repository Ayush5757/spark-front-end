import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark/features/auth/presentation/pages/profile_setup_screen.dart';
import 'package:spark/features/home/presentation/pages/home_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool isOtpSent = false;
  String savedPhone = "";

  @override
  void initState() {
    super.initState();
    // Listener lagaya hai taaki typing ke waqt button enable/disable ho sake
    _inputController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // --- Validation Logic ---
  bool _isInputValid() {
    final input = _inputController.text.trim();
    if (isOtpSent) {
      // OTP validation: Exactly 6 digits hona chahiye
      return input.length == 6 && RegExp(r'^[0-9]+$').hasMatch(input);
    } else {
      // Indian Phone Validation: Starts with 6-9 and exactly 10 digits
      // Agar user +91 likhta hai toh usko handle karne ke liye trim/replace logic
      String cleanPhone = input.replaceAll(RegExp(r'\D'), ''); // Sirf numbers rakho
      if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
        cleanPhone = cleanPhone.substring(2);
      } else if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
        cleanPhone = cleanPhone.substring(1);
      }
      return cleanPhone.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(cleanPhone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final bool isValid = _isInputValid(); // Button state ke liye check

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withOpacity(0.15),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.flash_on,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Spark",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Connect. Meet. Spark.",
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textGrey,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOtpSent
                              ? "Enter the 6-digit OTP"
                              : "Enter your mobile number",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isValid
                                  ? AppColors.primaryBlue.withOpacity(0.5)
                                  : AppColors.primaryBlue.withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _inputController,
                            keyboardType: TextInputType.number,
                            maxLength: isOtpSent ? 6 : 10, // Max limit set kar di
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            decoration: InputDecoration(
                              counterText: "", // Hide character counter
                              border: InputBorder.none,
                              icon: Icon(
                                isOtpSent
                                    ? Icons.shield_outlined
                                    : Icons.phone_android,
                                color: AppColors.primaryBlue,
                              ),
                              hintText: isOtpSent
                                  ? "123456"
                                  : "98765 43210",
                              hintStyle: const TextStyle(color: Colors.white24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      // Agar valid nahi hai ya loading hai toh onPressed null (Disable)
                      onPressed: (isLoading || !isValid) ? null : () => _handleContinue(),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent, // Important for gradient
                      ),
                      child: Opacity(
                        opacity: isValid ? 1.0 : 0.4, // Disable state mein halka dikhega
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: isLoading
                                ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleContinue() async {
    final input = _inputController.text.trim();
    final authRepo = ref.read(authRepositoryProvider);
    final loadingNotifier = ref.read(authLoadingProvider.notifier);

    loadingNotifier.state = true;

    if (!isOtpSent) {
      final success = await authRepo.sendOtp(input);
      loadingNotifier.state = false;

      if (success) {
        setState(() {
          savedPhone = input;
          isOtpSent = true;
          _inputController.clear();
        });
      } else {
        _showError("Failed to send OTP. Check number or internet.");
      }
    } else {
      final response = await authRepo.verifyOtp(savedPhone, input);
      loadingNotifier.state = false;

      if (response != null && response['success'] == true) {
        final responseData = response['data'];
        final String token = responseData['token'];
        final bool isNewUser = responseData['newUser'] ?? false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_phone', savedPhone);

        if (isNewUser) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        _showError("Invalid OTP. Please try again.");
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}