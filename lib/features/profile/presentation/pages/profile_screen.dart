import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' as dio_file;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String fullName = "Loading...";
  String bio = "";
  String instaHandle = "";
  String gender = "";
  List<String> profileImages = [];
  bool isLoading = true;
  bool isUploading = false;
  bool isVisibilityLoading = false;
  bool showProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await _apiService.dio.get('/api/profile/me');
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          fullName = data['fullName'] ?? "User";
          bio = data['bio'] ?? "Capturing moments... ✨";
          instaHandle = data['instaHandle'] ?? "";
          gender = (data['gender'] ?? "").toString().toLowerCase();
          profileImages = List<String>.from(data['profileImages'] ?? []);
          showProfile = data['showProfile'] ?? true;

          if (gender == "female") {
            accentColor = const Color(0xFFF472B6);
          } else {
            accentColor = const Color(0xFF4ADE80);
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() => isLoading = false);
    }
  }

  // Cool Confirmation Dialog
  void _showVisibilityConfirmDialog(bool newValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: borderColor)),
        title: Text(
          newValue ? "Go Public? 🌎" : "Go Stealth? 🥷",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          newValue
              ? "When your profile is Public, people can find you in search and you'll show up in discovery lists. Ready to shine?"
              : "Going private means you'll vanish from search results and discovery lists. Nobody new will find you here.",
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Not now", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newValue ? accentColor : dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _toggleVisibility();
            },
            child: Text(
              newValue ? "Yes, make it public" : "Yes, hide me",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVisibility() async {
    setState(() => isVisibilityLoading = true);
    try {
      final response = await _apiService.dio.post('/api/profile/toggle-profile');
      if (response.statusCode == 200) {
        setState(() {
          showProfile = response.data['data'] ?? !showProfile;
        });
      }
    } catch (e) {
      debugPrint("Toggle Error: $e");
    } finally {
      setState(() => isVisibilityLoading = false);
    }
  }

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
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    children: [
                      _buildInstaHeader(),
                      const SizedBox(height: 25),
                      _buildActionButtons(),
                      const SizedBox(height: 35),
                      _buildGalleryGrid(),
                      const SizedBox(height: 50),
                      _buildLogoutButton(context),
                      const SizedBox(height: 30),
                    ],
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
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
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
          const Text("My Spark", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          if (isUploading)
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
        ],
      ),
    );
  }

  Widget _buildInstaHeader() {
    String avatarUrl = profileImages.isNotEmpty ? profileImages[0] : "https://api.dicebear.com/7.x/avataaars/svg?seed=$fullName";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 50, backgroundImage: NetworkImage(avatarUrl), backgroundColor: cardBg),
          const SizedBox(width: 25),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis))),
                    const SizedBox(width: 6),
                    Icon(gender == "female" ? Icons.female : Icons.male, color: accentColor, size: 20),
                  ],
                ),
                if (instaHandle.isNotEmpty)
                  Text("@$instaHandle", style: TextStyle(color: accentColor, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 10),
                Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                        showProfile ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: showProfile ? accentColor : Colors.white38,
                        size: 22
                    ),
                    const SizedBox(width: 12),
                    Text(
                        showProfile ? "Public Profile" : "Hidden Profile",
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
                isVisibilityLoading
                    ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                )
                    : Switch(
                  value: showProfile,
                  activeColor: accentColor,
                  onChanged: (val) {
                    _showVisibilityConfirmDialog(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _showEditProfileModal,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text("Edit Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text("MY MOMENTS.. ✨", style: TextStyle(color: accentColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 12, childAspectRatio: 0.85,
          ),
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
                child: !hasImage ? Icon(Icons.add_a_photo_outlined, color: accentColor.withOpacity(0.3), size: 30) : null,
              ),
            );
          },
        ),
      ],
    );
  }

  void _showImageOptions(int index, bool hasImage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),
          if (hasImage)
            ListTile(
              leading: Icon(Icons.fullscreen, color: accentColor),
              title: const Text("View Fullscreen", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openImagePreview(profileImages[index]);
              },
            ),
          ListTile(
            leading: Icon(hasImage ? Icons.refresh : Icons.upload, color: accentColor),
            title: Text(hasImage ? "Replace Photo" : "Upload Photo", style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _pickAndUploadImage(index: index);
            },
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

  Future<void> _pickAndUploadImage({required int index}) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;
    setState(() => isUploading = true);
    try {
      dio_file.FormData formData = dio_file.FormData.fromMap({
        "file": await dio_file.MultipartFile.fromFile(image.path, contentType: MediaType("image", "jpeg")),
        "index": index,
      });
      await _apiService.dio.post("/api/profile/upload-photo", data: formData);
      _fetchProfileData();
    } catch (e) { debugPrint("Upload Error: $e"); }
    finally { setState(() => isUploading = false); }
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: fullName);
    final bioCtrl = TextEditingController(text: bio);
    final instaCtrl = TextEditingController(text: instaHandle);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(top: 25, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(color: cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(35))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEditField("Name", nameCtrl),
            const SizedBox(height: 15),
            _buildEditField("Bio", bioCtrl, lines: 3),
            const SizedBox(height: 15),
            _buildEditField("Instagram", instaCtrl, pref: "@"),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () { _updateProfile(nameCtrl.text, bioCtrl.text, instaCtrl.text); Navigator.pop(context); },
                child: const Text("Save Changes", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, {int lines = 1, String? pref}) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentColor.withOpacity(0.6)),
        prefixText: pref,
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor), borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: bgBlack,
      ),
    );
  }

  Future<void> _updateProfile(String name, String newBio, String insta) async {
    try {
      await _apiService.dio.put('/api/profile/update', data: {"fullName": name, "bio": newBio, "instaHandle": insta});
      _fetchProfileData();
    } catch (e) { debugPrint("Update Error: $e"); }
  }

  Future<void> _launchInstagram() async {
    if (instaHandle.isEmpty) return;
    final Uri url = Uri.parse("https://www.instagram.com/$instaHandle/");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) debugPrint("Launch fail");
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: Icon(Icons.logout_rounded, color: dangerRed, size: 18),
        label: Text("Logout from Spark", style: TextStyle(color: dangerRed, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text("Logout?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed),
            child: const Text("Logout"),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
            },
          ),
        ],
      ),
    );
  }
}