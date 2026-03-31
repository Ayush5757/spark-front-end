import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' as dio_file;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart'; // Font style ke liye add kiya hai
import 'dart:ui';
import '../../../../core/network/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  // --- Theme Colors ---
  Color accentColor = const Color(0xFF4ADE80);
  final Color bgBlack = const Color(0xFF000000);
  final Color cardBg = const Color(0xFF0D0D0D);
  final Color borderColor = const Color(0xFF1F2937);
  final Color dangerRed = const Color(0xFFF87171);

  // Data Variables
  String fullName = "User";
  String bio = "";
  String instaHandle = "";
  String gender = "";
  List<String> profileImages = [];

  // States
  bool isLoading = true;
  bool isUploading = false;
  bool isVisibilityLoading = false;
  bool isSaving = false;
  bool showProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  // --- API LOGIC (RETAINED AS IS) ---

  Future<void> _fetchProfileData() async {
    try {
      final response = await _apiService.dio.get('/api/profile/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final rawData = response.data['data'];
        if (mounted) {
          setState(() {
            fullName = rawData['fullName'] ?? "Spark User";
            bio = rawData['bio'] ?? "Capturing moments... ✨";
            instaHandle = rawData['instaHandle'] ?? "";
            gender = (rawData['gender'] ?? "").toString().toLowerCase();
            profileImages = List<String>.from(rawData['profileImages'] ?? []);
            showProfile = rawData['showProfile'] ?? true;
            accentColor = (gender == "female") ? const Color(0xFFF472B6) : const Color(0xFF4ADE80);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      _showSnackBar("Failed to load profile", isError: true);
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateProfile(String name, String newBio, String insta) async {
    setState(() => isSaving = true);
    try {
      final response = await _apiService.dio.put('/api/profile/update', data: {
        "fullName": name.trim(),
        "bio": newBio.trim(),
        "instaHandle": insta.trim()
      });
      if (response.statusCode == 200) {
        await _fetchProfileData();
        _showSnackBar("Profile Updated Successfully");
      }
    } catch (e) {
      _showSnackBar("Update failed", isError: true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage({required int index}) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 1000);
    if (image == null) return;
    setState(() => isUploading = true);
    try {
      dio_file.FormData formData = dio_file.FormData.fromMap({
        "file": await dio_file.MultipartFile.fromFile(image.path, contentType: MediaType("image", "jpeg")),
        "index": index,
      });
      final response = await _apiService.dio.post("/api/profile/upload-photo", data: formData);
      if (response.statusCode == 200) {
        _fetchProfileData();
        _showSnackBar("Moment Updated! 🔥");
      }
    } catch (e) {
      _showSnackBar("Upload failed", isError: true);
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _deleteImage(int index) async {
    setState(() => isUploading = true);
    try {
      final response = await _apiService.dio.post(
        "/api/profile/delete-photo",
        queryParameters: {"index": index},
      );

      if (response.statusCode == 200) {
        _fetchProfileData(); // Refresh data
        _showSnackBar("Moment Deleted! ");
      }
    } catch (e) {
      _showSnackBar("Failed to delete", isError: true);
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _toggleVisibility() async {
    setState(() => isVisibilityLoading = true);
    try {
      final response = await _apiService.dio.post('/api/profile/toggle-profile');
      if (response.statusCode == 200) {
        setState(() => showProfile = response.data['data']);
        _showSnackBar(showProfile ? "Profile Public" : "Profile Hidden");
      }
    } catch (e) {
      _showSnackBar("Failed to toggle", isError: true);
    } finally {
      if (mounted) setState(() => isVisibilityLoading = false);
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,
      body: Stack(
        children: [
          _buildAestheticBackground(),
          isLoading
              ? Center(child: CircularProgressIndicator(color: accentColor))
              : SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchProfileData,
                    color: accentColor,
                    backgroundColor: cardBg,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      children: [
                        _buildInstaStyleHeader(), // Improved UI
                        const SizedBox(height: 20),
                        _buildActionButtons(),
                        const SizedBox(height: 30),
                        _buildGalleryGrid(), // "CAPTURES" UI
                        const SizedBox(height: 50),
                        _buildLogoutButton(context),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAestheticBackground() {
    return Stack(
      children: [
        Positioned(top: -50, right: -50, child: _glowOrb(250, accentColor.withOpacity(0.08))),
        Positioned(bottom: 100, left: -80, child: _glowOrb(300, accentColor.withOpacity(0.06))),
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
      ],
    );
  }

  Widget _glowOrb(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("My Spark", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          if (isUploading) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: accentColor)),
        ],
      ),
    );
  }

  // --- NEW INSTAGRAM STYLE HEADER ---
  Widget _buildInstaStyleHeader() {
    String avatarUrl = profileImages.isNotEmpty ? profileImages[0] : "https://api.dicebear.com/7.x/avataaars/svg?seed=$fullName";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Pic (Border Removed as requested)
          CircleAvatar(
            radius: 45,
            backgroundImage: NetworkImage(avatarUrl),
            backgroundColor: cardBg,
          ),
          const SizedBox(width: 25),
          // Info Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name (Size 18, better font)
                Text(
                  fullName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                // Gender
                Row(
                  children: [
                    Icon(gender == "female" ? Icons.female : Icons.male, color: accentColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      gender.toUpperCase(),
                      style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Instagram Logo + Handle
                if (instaHandle.isNotEmpty)
                  GestureDetector(
                    onTap: _launchInstagram,
                    child: Row(
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Instagram_icon.png/600px-Instagram_icon.png',
                          height: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          instaHandle,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                // Bio
                Text(
                  bio,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Visibility Toggle Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(showProfile ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: showProfile ? accentColor : Colors.white38, size: 20),
                    const SizedBox(width: 12),
                    Text(showProfile ? "Public Profile" : "Hidden Profile", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
                isVisibilityLoading
                    ? Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)))
                    : Transform.scale(
                  scale: 0.8,
                  child: Switch(value: showProfile, activeColor: accentColor, onChanged: (val) => _showVisibilityConfirmDialog(val)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Edit Profile Button (Now prominent below header)
          ElevatedButton(
            onPressed: _showEditProfileModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              const Icon(Icons.grid_on_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text("CAPTURES", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ],
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: 6,
          itemBuilder: (context, index) {
            bool hasImage = profileImages.length > index;
            return GestureDetector(
              onTap: () => _showImageOptions(index, hasImage),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hasImage ? Colors.transparent : borderColor),
                  image: hasImage ? DecorationImage(image: NetworkImage(profileImages[index]), fit: BoxFit.cover) : null,
                ),
                child: !hasImage ? Icon(Icons.add_a_photo_outlined, color: accentColor.withOpacity(0.2), size: 28) : null,
              ),
            );
          },
        ),
      ],
    );
  }

  // --- MODALS (KEEPING YOUR LOGIC) ---

  void _showImageOptions(int index, bool hasImage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),
          if (hasImage) ...[
            ListTile(
              leading: Icon(Icons.fullscreen, color: accentColor),
              title: const Text("View Moment", style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _openImagePreview(profileImages[index]); },
            ),
            // ✅ DELETE OPTION ADDED HERE
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: dangerRed),
              title: Text("Delete Moment", style: TextStyle(color: dangerRed)),
              onTap: () {
                Navigator.pop(context);
                _deleteImage(index); // Delete function call
              },
            ),
          ],
          ListTile(
            leading: Icon(hasImage ? Icons.refresh : Icons.upload, color: accentColor),
            title: Text(hasImage ? "Change Photo" : "Upload Photo", style: const TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickAndUploadImage(index: index); },
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  void _openImagePreview(String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
    )));
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: fullName);
    final bioCtrl = TextEditingController(text: bio);
    final instaCtrl = TextEditingController(text: instaHandle);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(top: 25, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: BoxDecoration(color: cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEditField("Full Name", nameCtrl),
                  const SizedBox(height: 15),
                  _buildEditField("Bio", bioCtrl, lines: 7, charLimit: 150),
                  const SizedBox(height: 15),
                  _buildEditField("Instagram Handle", instaCtrl, pref: ""),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: isSaving ? null : () async {
                        setModalState(() => isSaving = true);
                        await _updateProfile(nameCtrl.text, bioCtrl.text, instaCtrl.text);
                        if (mounted) {
                          setModalState(() => isSaving = false);
                          Navigator.pop(context);
                        }
                      },
                      child: isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text("Update Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, {int lines = 1, String? pref, int? charLimit}) {
    return TextField(
      controller: ctrl, maxLines: lines, style: const TextStyle(color: Colors.white),
      maxLength: charLimit, // Ye raha tumhara character limit
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: accentColor.withOpacity(0.6)), prefixText: pref,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor), borderRadius: BorderRadius.circular(15)),
        filled: true, fillColor: bgBlack,
      ),
    );
  }

  void _showVisibilityConfirmDialog(bool newValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(newValue ? "Go Public? 🌎" : "Go Private? 🥷", style: const TextStyle(color: Colors.white)),
        content: Text(newValue ? "Others can see your profile now." : "Your profile will be hidden from others.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              onPressed: () { Navigator.pop(context); _toggleVisibility(); },
              child: const Text("Confirm", style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  Future<void> _launchInstagram() async {
    final Uri url = Uri.parse("https://www.instagram.com/$instaHandle/");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) _showSnackBar("Error opening Instagram", isError: true);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg,  style: const TextStyle(color: Colors.white)), backgroundColor: isError ? dangerRed : accentColor, behavior: SnackBarBehavior.floating));
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: Icon(Icons.logout_rounded, color: dangerRed, size: 20),
        label: Text("Logout Account", style: TextStyle(color: dangerRed, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            // 1. SharedPreferences clear karna (Logic unchanged)
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            // 2. Navigation Fix: pushNamedAndRemoveUntil ka use kiya hai
            // Ye pichle saare screen history (stack) ko khatam kar dega
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
            }
          }, child: const Text("Logout"))
        ]));
  }
}