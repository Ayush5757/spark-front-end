import 'dart:async'; // StreamSubscription ke liye zaroori hai
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:spark/features/home/widgets/create_spark_modal.dart';
import '../../../../core/network/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController(); // Added for pagination
  List<dynamic> sparks = [];
  bool isLoading = false;

  // --- New Pagination States ---
  bool isMoreLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  // -----------------------------

  int? interestLoadingId;
  String selectedFilter = "EVERYONE"; // Default filter
  final List<String> filterOptions = ["MALE", "FEMALE", "EVERYONE"];


  // Stream subscription taaki location status track ho sake
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  // Design Colors
  final Color bgBlack = const Color(0xFF0A0C10);
  final Color cardBg = const Color(0xFF1C2128);
  final Color borderColor = const Color(0xFF30363D);
  final Color accentGreen = const Color(0xFF2DD4BF); // Tera Favourite Green
  final List<Color> gradientColors = [
    const Color(0xFF3B82F6),
    const Color(0xFF2DD4BF),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedFilter();
    _setupFCM();

    // Pagination Listener: Jaise hi end pe pahunche, next page fetch karo
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.85) {
        if (!isLoading && !isMoreLoading && hasMore) {
          _fetchMoreFeed();
        }
      }
    });
  }

  Future<void> _loadSavedFilter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedFilter = prefs.getString('feed_filter') ?? "EVERYONE";
    });
    _initHomeData(); // Filter milne ke baad data load karo
  }

  Future<void> _updateFilter(String newFilter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feed_filter', newFilter);
    setState(() {
      selectedFilter = newFilter;
    });
    _fetchFeed(); // Nayi filter ke sath data fetch karo
  }

  @override
  void dispose() {
    // Subscription aur Controller ko dispose karna mat bhulna
    _scrollController.dispose();
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  // --- Initialization Logic ---
  Future<void> _initHomeData() async {
    bool hasLocation = await _updateLocation();
    if (hasLocation) {
      await _fetchFeed();
    }
  }

  // --- Location Logic with Auto-Dismiss Popup ---
  Future<bool> _updateLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showLocationServiceDialog();
      // Jab popup band hoga (chahe automatic ya manual), tab wapas check karega
      return _updateLocation();
    }

    // 2. Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar(
          "Permission Denied",
          "Nearby sparks dekhne ke liye permission chahiye.",
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar("Settings", "App settings se location enable karein.");
      return false;
    }

    // 3. Get Position & Update Backend
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _apiService.dio.post(
        "/api/profile/update-location?lat=${position.latitude}&lon=${position.longitude}",
      );
      debugPrint(
        "Location Updated: ${position.latitude}, ${position.longitude}",
      );
      return true;
    } catch (e) {
      debugPrint("Location Error: $e");
      return false;
    }
  }

  // --- Automatic Location Service Dialog ---
  Future<void> _showLocationServiceDialog() async {
    bool isDialogVisible = true;

    // Stream listen karo: Jaise hi service status change ho
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((
        status,
        ) {
      if (status == ServiceStatus.enabled && isDialogVisible) {
        if (Navigator.canPop(context)) {
          isDialogVisible = false;
          Navigator.of(context).pop(); // Auto-dismiss logic 🔥
        }
      }
    });

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            title: const Row(
              children: [
                Icon(Icons.location_off, color: Colors.redAccent),
                SizedBox(width: 10),
                Text(
                  "Location Off Hai",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              "Bhai, settings me jaake GPS on karo. On karte hi ye popup khud hat jayega.",
              style: TextStyle(color: Color(0xFF8B949E)),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                child: const Text(
                  "Settings Kholo",
                  style: TextStyle(color: Color(0xFF3B82F6)),
                ),
              ),
              // Optional: Manual button agar stream delay kare toh
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  bool enabled = await Geolocator.isLocationServiceEnabled();
                  if (enabled) {
                    isDialogVisible = false;
                    Navigator.of(context).pop();
                  } else {
                    _showSnackBar("Abhi bhi off hai", "Pehle GPS on karo!");
                  }
                },
                child: const Text("OK", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Dialog band hone par stream cancel kardo taaki memory leak na ho
      _serviceStatusSubscription?.cancel();
    });
  }

  // --- FCM & Notifications ---
  Future<void> _setupFCM() async {
    setState(() {
      isLoading = true;
    });
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      String? token = await messaging.getToken();
      if (token != null) {
        await _apiService.dio.post(
          "/api/sparks/update-fcm-token",
          data: token,
          options: Options(contentType: "text/plain"),
        );
      }
    } catch (e) {
      debugPrint("FCM Error: $e");
    }
  }

  // --- API CALL: Initial Fetch with Pagination Support ---
  Future<void> _fetchFeed() async {
    setState(() {
      isLoading = true;
      currentPage = 0;
      hasMore = true;
      // sparks.clear(); // Clear optionally, loader will handle visibility
    });
    try {
      final response = await _apiService.dio.get(
        "/api/sparks/feed/filter",
        queryParameters: {
          'gender': selectedFilter,
          'page': 0,
          'size': 15
        },
      );

      if (response.data['success'] == true) {
        setState(() {
          sparks = response.data['data'];
          if (sparks.isEmpty) hasMore = false;
        });
      }
    } catch (e) {
      debugPrint("Feed Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- API CALL: Load More logic ---
  Future<void> _fetchMoreFeed() async {
    if (isMoreLoading || !hasMore) return;

    setState(() => isMoreLoading = true);

    // Safety Timer (5 Seconds)
    Timer(const Duration(seconds: 5), () {
      if (mounted && isMoreLoading) setState(() => isMoreLoading = false);
    });

    int nextPage = currentPage + 1;

    try {
      final response = await _apiService.dio.get(
        "/api/sparks/feed/filter",
        queryParameters: {
          'gender': selectedFilter,
          'page': nextPage,
          'size': 15
        },
      );

      if (response.data['success'] == true) {
        final List newItems = response.data['data'];
        setState(() {
          if (newItems.isEmpty) {
            hasMore = false;
          } else {
            sparks.addAll(newItems);
            currentPage = nextPage;
          }
        });
      }
    } catch (e) {
      debugPrint("Pagination Error: $e");
    } finally {
      if (mounted) setState(() => isMoreLoading = false);
    }
  }

  // --- 4. UI: Filter Header Widget ---
  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: filterOptions.map((filter) {
          bool isSelected = selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ChoiceChip(
              label: Text(
                filter == "EVERYONE" ? "EVERYONE" : filter,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF2DD4BF),
              backgroundColor: cardBg,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : borderColor,
                ),
              ),
              onSelected: (selected) {
                if (selected) _updateFilter(filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Handle Interest (Optimistic Approach applied 🔥) ---
  Future<void> _handleInterest(int eventId) async {
    // Current list ka backup for rollback
    final originalSparks = List.from(sparks);

    // 1. UI ko turant update karo
    setState(() {
      final index = sparks.indexWhere((s) => s['id'] == eventId);
      if (index != -1) sparks[index]['interested'] = true;
    });

    try {
      final response = await _apiService.dio.post(
        "/api/matches/interest/$eventId",
      );

      String successMsg = response.data.toString().contains("success")
          ? "Interest bhej diya gaya hai!"
          : response.data.toString();

      _showSnackBar("Sent! 🔥", successMsg);

    } on DioException catch (e) {
      // 2. Error aane par rollback
      setState(() => sparks = originalSparks);

      String errorMessage = "Request fail ho gayi.";
      if (e.response != null) {
        errorMessage = e.response?.data.toString() ?? errorMessage;
      }
      _showSnackBar("Ruk Jao!", errorMessage);
    } catch (e) {
      setState(() => sparks = originalSparks);
      _showSnackBar("Oops!", "Kuch galat hua.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlack,
      body: Stack( // Added Stack for Full Screen Loader
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchFeed,
                    color: accentGreen,
                    backgroundColor: cardBg,
                    child: sparks.isEmpty && !isLoading
                        ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text(
                            "No live vibes near you",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    )
                        : ListView.builder(
                      controller: _scrollController, // Controller attached
                      padding: const EdgeInsets.all(16),
                      // Current list + loader if hasMore
                      itemCount: sparks.length + (isMoreLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == sparks.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: accentGreen,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        }
                        return _buildSparkCard(sparks[index]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- FULL SCREEN LOADER OVERLAY ---
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: accentGreen,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Finding vibes...",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Spark",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2DD4BF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Live vibes near you",
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          // Mini Loader in Header (Optional since we have full screen now)
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentGreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSparkCard(dynamic item) {
    final cat = _getCategoryData(item['category'] ?? "DEFAULT");
    bool alreadySent = item['interested'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF30363D),
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['creatorName'] ?? "User",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "is looking for a vibe",
                          style: TextStyle(
                            color: Color(0xFF8B949E),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cat['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(cat['icon'], color: cat['color'], size: 24),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              item['title'] ?? "",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            const Divider(color: Color(0xFF30363D)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group, size: 14, color: Color(0xFF8B949E)),
                    const SizedBox(width: 6),
                    Text(
                      "Interested in ${item['genderPreference'] ?? "Everyone"}",
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                _buildJoinButton(alreadySent, item['id']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton(bool alreadySent, int id) {
    return GestureDetector(
      onTap: alreadySent ? null : () => _handleInterest(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: alreadySent ? null : LinearGradient(colors: gradientColors),
          color: alreadySent ? const Color(0xFF30363D) : null,
          border: alreadySent
              ? Border.all(color: const Color(0xFF484F58))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              alreadySent ? Icons.check_circle_outline : Icons.favorite,
              size: 16,
              color: alreadySent
                  ? const Color(0xFF2DD4BF)
                  : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              alreadySent ? "Sent" : "Join",
              style: TextStyle(
                color: alreadySent
                    ? const Color(0xFF8B949E)
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () async {
        bool? refresh = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const CreateSparkModal(),
        );
        if (refresh == true) {
          _initHomeData();
        }
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: gradientColors),
        ),
        child: const Icon(Icons.bolt, color: Colors.white, size: 30),
      ),
    );
  }

  Map<String, dynamic> _getCategoryData(String cat) {
    switch (cat) {
      case 'DRIVE':
        return {'icon': Icons.directions_car, 'color': Colors.blue};
      case 'COFFEE':
        return {'icon': Icons.coffee, 'color': Colors.orange};
      case 'MOVIE':
        return {'icon': Icons.movie, 'color': Colors.orangeAccent};
      case 'CHAT':
        return {
          'icon': Icons.chat_bubble_outline,
          'color': Colors.purpleAccent,
        };
      case 'SHOP':
        return {'icon': Icons.shopping_bag, 'color': Colors.greenAccent};
      default:
        return {'icon': Icons.bolt, 'color': Colors.blueAccent};
    }
  }

  void _showSnackBar(String title, String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$title: $msg",
          style: const TextStyle(color: Colors.white), // Added white color here 🔥
        ),
        backgroundColor: cardBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}