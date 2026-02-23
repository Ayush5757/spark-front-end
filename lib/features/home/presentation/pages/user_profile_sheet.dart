import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart'; // Distance ke liye zaroori hai
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
  String distanceStr = "Checking location...";

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
        _calculateDistance();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Distance Logic ---
  Future<void> _calculateDistance() async {
    if (userData == null) return;
    try {
      // User ki current position lo
      Position myPos = await Geolocator.getCurrentPosition();

      // API se aaye hue user ke lat/lon
      double userLat = userData!['latitude'] ?? 0.0;
      double userLon = userData!['longitude'] ?? 0.0;

      if (userLat != 0.0) {
        double distanceInMeters = Geolocator.distanceBetween(
            myPos.latitude, myPos.longitude, userLat, userLon
        );

        double distanceInKm = distanceInMeters / 1000;
        setState(() {
          distanceStr = "${distanceInKm.toStringAsFixed(1)} km away from last updates";
        });
      } else {
        setState(() => distanceStr = "Location hidden");
      }
    } catch (e) {
      setState(() => distanceStr = "Nearby somewhere");
    }
  }

  void _launchInstagram(String handle) async {
    final Uri url = Uri.parse("https://www.instagram.com/$handle/");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  void _showImagePopup(String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close",
      barrierColor: Colors.black.withOpacity(0.9),
      pageBuilder: (context, anim1, anim2) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 40, right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      },
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

    if (userData == null || userData!['showProfile'] == false) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: const BoxDecoration(color: bgBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: accentColor.withOpacity(0.5), size: 50),
            const SizedBox(height: 15),
            const Text("Profile is Private", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    List<dynamic> photos = userData!['profileImages'] ?? [];
    String avatarUrl = photos.isNotEmpty ? photos[0] : 'https://via.placeholder.com/150';
    String? instaHandle = userData!['instaHandle'];
    String? bio = userData!['bio'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: bgBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header Section ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _showImagePopup(avatarUrl),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: cardBg,
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                      ),
                      const SizedBox(width: 25),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userData!['fullName'] ?? "Stranger",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900, // GenZ Bold Look
                                  letterSpacing: -0.5
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (userData!['gender'] ?? "Spark User").toString().toUpperCase(),
                              style: const TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                            ),

                            const SizedBox(height: 8),
                            // --- Distance Message ---
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white38, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  distanceStr,
                                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),

                            // const SizedBox(height: 12),
                            // // Message Button
                            // GestureDetector(
                            //   onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            //     const SnackBar(content: Text("Direct message feature is coming soon! ⚡", style: TextStyle(color: Colors.white)), backgroundColor: cardBg),
                            //   ),
                            //   child: Container(
                            //     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            //     decoration: BoxDecoration(
                            //         color: accentColor,
                            //         borderRadius: BorderRadius.circular(12),
                            //         boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 10)]
                            //     ),
                            //     child: const Row(
                            //       mainAxisSize: MainAxisSize.min,
                            //       children: [
                            //         Icon(Icons.chat_bubble_rounded, color: Colors.black, size: 16),
                            //         SizedBox(width: 8),
                            //         Text("Say Hi!", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                            //       ],
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // --- Bio Section ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("THE BIO", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Text(
                          bio != null && bio.isNotEmpty ? bio : "This user is too cool for a bio. Just catch the vibe! ✨",
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5, fontWeight: FontWeight.w400),
                        ),
                        if (instaHandle != null && instaHandle.isNotEmpty) ...[
                          const SizedBox(height: 15),
                          GestureDetector(
                            onTap: () => _launchInstagram(instaHandle),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Instagram_icon.png/600px-Instagram_icon.png', height: 18),
                                    const SizedBox(width: 8),
                                    Text(instaHandle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Tap to check their vibe on Instagram ↗",
                                  style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Divider(color: borderColor, thickness: 1),
                  const SizedBox(height: 20),

                  // --- Photos Grid ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "CAPTURES",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      Text(
                        "${photos.length} Moments",
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: photos.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 images per row as requested 🔥
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showImagePopup(photos[index]),
                        child: Container(
                          decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 0.5)
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              photos[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: accentColor));
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
    );
  }
}