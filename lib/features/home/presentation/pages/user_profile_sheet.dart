import 'package:flutter/material.dart';
import '../../../../core/network/api_service.dart';

class UserProfileModal extends StatefulWidget {
  final dynamic userId;
  const UserProfileModal({super.key, required this.userId});

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFullProfile();
  }

  Future<void> _fetchFullProfile() async {
    try {
      final response = await _apiService.dio.get("/api/profile/${widget.userId}");
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          userData = response.data;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Image Popup Viewer Logic (FIXED OVERFLOW) ---
  void _showImagePopup(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center mein rakhega
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Flexible taaki image screen size ke hisab se adjust ho jaye overflow na kare
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgBlack = Color(0xFF0A0C10);
    const Color cardBg = Color(0xFF1C2128);
    const Color accentColor = Color(0xFF2DD4BF);
    const Color borderColor = Color(0xFF30363D);

    if (isLoading) {
      return Container(
        height: 400,
        decoration: const BoxDecoration(color: bgBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: const Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    if (userData == null) {
      return Container(
        height: 250,
        decoration: const BoxDecoration(color: bgBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: const Center(child: Text("User not found!", style: TextStyle(color: Colors.white))),
      );
    }

    List<dynamic> photos = userData!['profileImages'] ?? [];
    String avatarUrl = photos.isNotEmpty ? photos[0] : 'https://via.placeholder.com/150';
    String? instaHandle = userData!['instaHandle'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: bgBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: CircleAvatar(radius: 100, backgroundColor: accentColor.withOpacity(0.05)),
          ),
          Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Header Section ---
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showImagePopup(avatarUrl),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: cardBg,
                              backgroundImage: NetworkImage(avatarUrl),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData!['fullName'] ?? "Stranger",
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    (userData!['gender'] ?? "Spark User").toString().toUpperCase(),
                                    style: const TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // --- Bio ---
                      const Text("BIO", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          userData!['bio'] ?? "No bio added yet. ✨",
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // --- Instagram Card ---
                      if (instaHandle != null && instaHandle.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF833AB4).withOpacity(0.1), const Color(0xFFFD1D1D).withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Instagram_icon.png/600px-Instagram_icon.png', height: 24),
                              const SizedBox(width: 12),
                              Text("@$instaHandle", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
                            ],
                          ),
                        ),

                      const SizedBox(height: 35),

                      // --- Photos Grid (REDUCED SPACING) ---
                      const Text("MOMENTS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: photos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 6, // Space kam kar diya
                          mainAxisSpacing: 6,  // Space kam kar diya
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _showImagePopup(photos[index]),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12), // Thoda kam round takki spacing ke saath sahi lage
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  photos[index],
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}