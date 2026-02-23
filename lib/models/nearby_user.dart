class NearbyUser {
  final int id;
  final String fullName;
  final String bio;
  final String? imageUrl;
  final String? instaHandle;
  final double distance;

  NearbyUser({
    required this.id,
    required this.fullName,
    required this.bio,
    this.imageUrl,
    this.instaHandle,
    required this.distance,
  });

  factory NearbyUser.fromJson(Map<String, dynamic> json) {
    var images = json['profileImages'];
    String? firstImage = (images is List && images.isNotEmpty) ? images[0].toString() : null;

    return NearbyUser(
      id: json['id'],
      fullName: json['fullName'] ?? "Stranger",
      bio: json['bio'] ?? "Vibe check no bio",
      imageUrl: firstImage,
      instaHandle: json['instaHandle'],
      distance: (json['distance'] ?? 0.0).toDouble(),
    );
  }
}