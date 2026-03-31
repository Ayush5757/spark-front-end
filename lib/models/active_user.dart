class ActiveUser {
  final int id;
  final String name;
  final String? profilePic;
  final bool online;

  ActiveUser({required this.id, required this.name, this.profilePic, required this.online});

  factory ActiveUser.fromJson(Map<String, dynamic> json) {
    return ActiveUser(
      id: json['id'],
      name: json['name'],
      profilePic: json['profilePic'],
      online: json['online'] ?? false,
    );
  }
}