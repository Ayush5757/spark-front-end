import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' as dio_file;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  int _currentPage = 0;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _instaController = TextEditingController();

  String _selectedGender = "MALE";
  final List<String?> _localPhotos = List.generate(6, (index) => null);
  final List<String> _uploadedUrls = [];

  bool _isCurrentStepValid() {
    switch (_currentPage) {
      case 0:
        return _nameController.text.trim().isNotEmpty;
      case 1:
        return _selectedGender.isNotEmpty;
      case 2:
        return !_isUploadingImage;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    // Keypad band karne ke liye
    FocusScope.of(context).unfocus();

    if (_isCurrentStepValid()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.ease,
      );
    }
  }

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      setState(() {
        _localPhotos[index] = image.path;
        _isUploadingImage = true;
      });
      await _uploadPhoto(image.path, index);
    }
  }

  Future<void> _uploadPhoto(String filePath, int index) async {
    try {
      dio_file.FormData formData = dio_file.FormData.fromMap({
        "file": await dio_file.MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
          contentType: MediaType("image", "jpeg"),
        ),
        "index": index,
      });

      final response = await _apiService.dio.post(
        "/api/profile/upload-photo",
        data: formData,
      );
      if (response.statusCode == 200) {
        setState(() {
          _uploadedUrls.add(response.data.toString());
          _isUploadingImage = false;
        });
        debugPrint("Photo Uploaded: ${response.data}");
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      debugPrint("Upload failed: $e");
      _showError("Image upload failed. Please try again.");
    }
  }

  Future<void> _handleFinalSubmit() async {
    FocusScope.of(context).unfocus(); // Final submit par bhi keyboard band
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('user_phone') ?? "";

      if (phone.isEmpty) {
        _showError("Session expired, please login again");
        return;
      }

      final onboardingData = {
        "phoneNumber": phone,
        "name": _nameController.text.trim(),
        "gender": _selectedGender,
        "birthday": "2000-01-01",
        "photos": _uploadedUrls,
        "instaHandle": _instaController.text.trim(),
      };

      await _apiService.dio.post(
        "/api/profile/onboarding",
        data: onboardingData,
      );

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position pos = await Geolocator.getCurrentPosition();
          await _apiService.dio.post(
            "/api/profile/update-location?lat=${pos.latitude}&lon=${pos.longitude}",
          );
        }
      }

      await prefs.setBool('is_profile_complete', true);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint("Submit Error: $e");
      _showError("Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      // Keypad khulne par layout resize ho taaki input visible rahe
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            LinearProgressIndicator(
              value: (_currentPage + 1) / 5,
              backgroundColor: Colors.white10,
              color: AppColors.primaryBlue,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) =>
                    setState(() => _currentPage = idx),
                children: [
                  // STEP 1: Name
                  _buildStepLayout(
                    title: "What's your name?",
                    child: TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (val) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: const InputDecoration(
                        hintText: "Enter full name",
                        hintStyle: TextStyle(color: Colors.white24),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    onNext: _nextStep,
                    isBtnEnabled: _isCurrentStepValid(),
                  ),
                  // STEP 2: Gender
                  _buildStepLayout(
                    title: "You are...",
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ["MALE", "FEMALE", "OTHER"]
                          .map(
                            (g) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: ChoiceChip(
                            label: Text(g),
                            selected: _selectedGender == g,
                            onSelected: (val) {
                              setState(() => _selectedGender = g);
                            },
                          ),
                        ),
                      ).toList(),
                    ),
                    onNext: _nextStep,
                    isBtnEnabled: _isCurrentStepValid(),
                  ),
                  // STEP 3: Photos
                  _buildStepLayout(
                    title: "Add your photos",
                    child: Column(
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 6,
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () => _pickImage(i),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                                image: _localPhotos[i] != null
                                    ? DecorationImage(
                                  image: FileImage(File(_localPhotos[i]!)),
                                  fit: BoxFit.cover,
                                ) : null,
                              ),
                              child: _localPhotos[i] == null
                                  ? const Icon(Icons.add, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                        if (_isUploadingImage)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text("Uploading...", style: TextStyle(color: Colors.blue, fontSize: 12)),
                          ),
                        const SizedBox(height: 20),
                        const Text("(Optional: You can skip this step)",
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    onNext: _nextStep,
                    isBtnEnabled: _isCurrentStepValid(),
                  ),
                  // STEP 4: Instagram
                  _buildStepLayout(
                    title: "What's your Instagram?",
                    child: Column(
                      children: [
                        TextField(
                          controller: _instaController,
                          textAlign: TextAlign.center,
                          onChanged: (val) => setState(() {}),
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                          decoration: const InputDecoration(
                            hintText: "username (optional)",
                            hintStyle: TextStyle(color: Colors.white24),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text("You can add this later in settings",
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    onNext: _nextStep,
                    isBtnEnabled: _isCurrentStepValid(),
                  ),
                  // STEP 5: Final
                  _buildStepLayout(
                    title: "All set?",
                    child: const Text(
                      "By continuing, you agree to our terms.",
                      style: TextStyle(color: Colors.white70),
                    ),
                    onNext: _handleFinalSubmit,
                    buttonText: "Let's Spark!",
                    isBtnEnabled: _isCurrentStepValid(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLayout({
    required String title,
    required Widget child,
    required VoidCallback onNext,
    required bool isBtnEnabled,
    String buttonText = "Next",
  }) {
    // SingleChildScrollView add kiya taaki keypad aane par overflow na ho
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          child,
          const SizedBox(height: 60),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: isBtnEnabled ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isBtnEnabled ? AppColors.primaryBlue : Colors.grey.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                buttonText,
                style: TextStyle(color: isBtnEnabled ? Colors.white : Colors.white38, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}