import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/api_service.dart';

class CreateSparkModal extends StatefulWidget {
  const CreateSparkModal({super.key});

  @override
  State<CreateSparkModal> createState() => _CreateSparkModalState();
}

class _CreateSparkModalState extends State<CreateSparkModal> {
  final ApiService _apiService = ApiService();
  final TextEditingController _contentController = TextEditingController();

  String selectedType = "OTHER";
  int selectedRadius = 100;
  int selectedDuration = 1;
  String selectedGender = "EVERYONE"; // Default preference
  bool isLoading = false;

  // Theme Colors
  final Color themeBlue = const Color(0xFF3B82F6);
  final Color bgBlack = const Color(0xFF000000);
  final Color cardBg = const Color(0xFF0D1117);
  final Color borderColor = const Color(0xFF1E293B);

  final List<Map<String, dynamic>> sparkTypes = [
    {
      'id': "OTHER",
      'label': "Other",
      'icon': Icons.bolt,
      'color': Colors.blueGrey,
    },
    {
      'id': "DRIVE",
      'label': "Drive",
      'icon': Icons.directions_car,
      'color': Colors.indigoAccent,
    },
    {
      'id': "MEETUP",
      'label': "Meet",
      'icon': Icons.groups,
      'color': Colors.amber,
    },
    {
      'id': "CHAT",
      'label': "Chat",
      'icon': Icons.chat_bubble_outline,
      'color': Colors.blue,
    },
    {
      'id': "COFFEE",
      'label': "Coffee",
      'icon': Icons.coffee,
      'color': Colors.orange,
    },
    {
      'id': "MOVIE",
      'label': "Movie",
      'icon': Icons.movie_outlined,
      'color': Colors.red,
    },
    {
      'id': "CLUB",
      'label': "Clubbing",
      'icon': Icons.nightlife,
      'color': Colors.purple,
    },
    {
      'id': "FOOD",
      'label': "Foodie",
      'icon': Icons.restaurant,
      'color': Colors.pink,
    },
    {
      'id': "GYM",
      'label': "Workout",
      'icon': Icons.fitness_center,
      'color': Colors.cyan,
    },
    {
      'id': "SHOP",
      'label': "Shopping",
      'icon': Icons.shopping_bag_outlined,
      'color': Colors.pinkAccent,
    },
  ];

  final List<int> ranges = [2, 5, 10, 20];
  final List<int> durations = [1, 2, 3, 4, 6];

  // Custom Gender Data for "Logo" feel
  final List<Map<String, dynamic>> genderData = [
    {
      "id": "MALE",
      "icon": Icons.face_6,
      "color": Colors.blueAccent,
    },
    {
      "id": "FEMALE",
      "icon": Icons.face_retouching_natural,
      "color": Colors.pinkAccent,
    },
    {
      "id": "EVERYONE",
      "icon": Icons.auto_awesome,
      "color": Colors.purpleAccent,
    },
  ];

  Future<void> _handlePost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      _showAlert("Wait!", "Set the stage! What's the plan for today? ⚡");
      return;
    }

    setState(() => isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showAlert("GPS Off", "GPS Offline. Let the world find your Spark! 📡");
        setState(() => isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showAlert(
            "Permission Denied",
            "Permission Denied, No Location no Spark. Stay on the map! 📍",
          );
          setState(() => isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showAlert("Settings", "Ignition Failed. Grant location access in Settings.");
        setState(() => isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      await _apiService.dio.post(
        "/api/sparks/create",
        data: {
          "title": text,
          "category": selectedType,
          "latitude": position.latitude,
          "longitude": position.longitude,
          "radiusKm": selectedRadius,
          "durationHours": selectedDuration,
          "genderPreference": selectedGender,
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("⚡ Spark ignited!"),
            backgroundColor: themeBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Create Spark Error: $e");
      _showAlert("Oops!", "Spark already active! ⚡ You can’t ignite another until the current one expires, or check your connection.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "OK",
              style: TextStyle(color: themeBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: bgBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Choose a vibe"),
                  _buildCategoryList(),
                  const SizedBox(height: 30),

                  _buildSectionHeader(
                    "Spark Reach",
                    "Within ${selectedRadius}km",
                  ),
                  _buildSelectionRow(
                    ranges,
                    selectedRadius,
                        (v) => setState(() => selectedRadius = v as int),
                    "km",
                  ),
                  const SizedBox(height: 30),

                  _buildSectionHeader(
                    "Spark Duration",
                    "Live for ${selectedDuration}h",
                  ),
                  _buildSelectionRow(
                    durations,
                    selectedDuration,
                        (v) => setState(() => selectedDuration = v as int),
                    "h",
                  ),
                  const SizedBox(height: 30),

                  // Updated Gender Section with Logo/Images
                  _buildSectionHeader(
                    "Vibe with",
                    selectedGender,
                  ),
                  _buildGenderSelectionRow(),
                  const SizedBox(height: 30),

                  _buildLabel("Your Plan"),
                  _buildTextInput(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
          const Text(
            "Ignite Spark",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          isLoading
              ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: themeBlue,
            ),
          )
              : TextButton(
            onPressed: _handlePost,
            style: TextButton.styleFrom(
              backgroundColor: themeBlue.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Post",
              style: TextStyle(
                color: themeBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              color: themeBlue,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: sparkTypes.length,
        itemBuilder: (context, index) {
          final type = sparkTypes[index];
          final isActive = selectedType == type['id'];
          return GestureDetector(
            onTap: () => setState(() => selectedType = type['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isActive ? type['color'].withOpacity(0.15) : cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive ? type['color'] : borderColor,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type['icon'],
                    color: isActive ? type['color'] : const Color(0xFF64748B),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type['label'],
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectionRow(
      List<dynamic> items,
      dynamic current,
      Function(dynamic) onSelect,
      String unit,
      ) {
    return Row(
      children: items.map((val) {
        final isActive = current == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isActive ? themeBlue.withOpacity(0.1) : cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? themeBlue : borderColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  "$val$unit",
                  style: TextStyle(
                    color: isActive ? themeBlue : const Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenderSelectionRow() {
    return Row(
      children: genderData.map((data) {
        final String id = data['id'];
        final IconData icon = data['icon'];
        final Color color = data['color'];
        final bool isActive = selectedGender == id;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedGender = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.1) : cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? color : borderColor,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  // Logo/Icon part with gradient feel
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive ? color.withOpacity(0.2) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isActive ? color : const Color(0xFF64748B),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    id,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextInput() {
    return TextField(
      controller: _contentController,
      maxLines: 4,
      maxLength: 150,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: "What's the plan? (e.g. Let's grab coffee ☕)",
        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 16),
        filled: true,
        fillColor: cardBg,
        counterStyle: const TextStyle(color: Color(0xFF64748B)),
        contentPadding: const EdgeInsets.all(20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: borderColor, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: themeBlue, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}