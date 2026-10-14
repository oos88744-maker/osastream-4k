 import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const OsaStreamApp());
}

class OsaStreamApp extends StatelessWidget {
  const OsaStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSASTREAM 4K PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060606),
        primaryColor: const Color(0xFFD4AF37),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: MainDashboard(),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  String hostUrl = "https://fast-wolf.site";
  String username = "";
  String password = "";
  String expiryText = "Expiry: 26 days left";
  String currentView = "home"; 

  List categories = [];
  List channels = [];
  VideoPlayerController? _videoController;
  String activeChannelTitle = "OSASTREAM 4K PRO CONTENTS";

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hostUrl = prefs.getString('osa_host') ?? "https://fast-wolf.site";
      username = prefs.getString('osa_user') ?? "";
      password = prefs.getString('osa_pass') ?? "";
    });
  }

  Future<void> _saveCredentials(String h, String u, String p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('osa_host', h);
    await prefs.setString('osa_user', u);
    await prefs.setString('osa_pass', p);
    setState(() {
      hostUrl = h;
      username = u;
      password = p;
    });
    _fetchLiveCategories();
  }

  Future<void> _fetchLiveCategories() async {
    if (username.isEmpty || password.isEmpty) return;
    try {
      final res = await http.get(Uri.parse(
          "$hostUrl/player_api.php?username=$username&password=$password&action=get_live_categories"));
      if (res.statusCode == 200) {
        setState(() => categories = jsonDecode(res.body));
      }
      final chRes = await http.get(Uri.parse(
          "$hostUrl/player_api.php?username=$username&password=$password&action=get_live_streams"));
      if (chRes.statusCode == 200) {
        setState(() => channels = jsonDecode(chRes.body));
      }
    } catch (_) {}
  }

  void _playChannel(String url, String name) {
    setState(() => activeChannelTitle = name);
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        setState(() {});
        _videoController?.play();
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, 0.95),
            radius: 1.2,
            colors: [Color(0xFF382807), Color(0xFF0E0B05), Color(0xFF040404)],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildActiveScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.black54,
        border: Border(bottom: BorderSide(color: Color(0x33D4AF37))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("05:33 ص", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("2026/10/14", style: TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
          Row(
            children: [
              _statusPill("الرياض: 34°C ☀️"),
              const SizedBox(width: 8),
              _statusPill(expiryText),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => currentView = "playlist"),
                child: _statusPill("🛡️ VPN"),
              ),
              if (currentView != "home") ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => currentView = "home"),
                  child: _statusPill("🏠 الرئيسية"),
                ),
              ]
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => currentView = "home"),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1706),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              ),
              child: const Row(
                children: [
                  Text("👑 ", style: TextStyle(fontSize: 14)),
                  Text("OSASTREAM 4K", style: TextStyle(color: Color(0xFFFFE57F), fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x55D4AF37)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildActiveScreen() {
    switch (currentView) {
      case "live":
        return _buildLiveScreen();
      case "playlist":
        return _buildPlaylistScreen();
      default:
        return _buildHomeGrid();
    }
  }

  Widget _buildHomeGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _goldCard(
              icon: Icons.live_tv_rounded,
              title: "مباشر",
              sub: "Watch live channels",
              onTap: () {
                _fetchLiveCategories();
                setState(() => currentView = "live");
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 9,
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: Row(
                    children: [
                      Expanded(
                        child: _goldCard(
                          icon: Icons.movie_creation_outlined,
                          title: "أفلام",
                          sub: "Browse all movies",
                          onTap: () => setState(() => currentView = "live"),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _goldCard(
                          icon: Icons.video_library_outlined,
                          title: "المسلسلات",
                          sub: "Browse all series",
                          onTap: () => setState(() => currentView = "live"),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(child: _miniCard(Icons.settings, "الإعدادات", () => setState(() => currentView = "playlist"))),
                      const SizedBox(width: 10),
                      Expanded(child: _miniCard(Icons.playlist_play, "قائمة التشغيل", () => setState(() => currentView = "playlist"))),
                      const SizedBox(width: 10),
                      Expanded(child: _miniCard(Icons.sync, "تحديث القائمة", _fetchLiveCategories)),
                      const SizedBox(width: 10),
                      Expanded(child: _miniCard(Icons.sports_soccer, "Sports", () => setState(() => currentView = "live"))),
                      const SizedBox(width: 10),
                      Expanded(child: _miniCard(Icons.exit_to_app, "خروج", () => SystemNavigator.pop())),
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

  Widget _goldCard({required IconData icon, required String title, required String sub, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xCC2C2412), Color(0xE60F0D08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x66D4AF37)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: const Color(0xFFD4AF37)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniCard(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xCC1E190E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x55D4AF37)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFD4AF37), size: 26),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveScreen() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33D4AF37))),
              child: ListView(
                children: [
                  const ListTile(title: Text("الكل (All)", style: TextStyle(color: Color(0xFFFFE57F), fontWeight: FontWeight.bold))),
                  ...categories.map((c) => ListTile(
                        title: Text(c['category_name'] ?? '', style: const TextStyle(fontSize: 13)),
                        onTap: () {},
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33D4AF37))),
              child: channels.isEmpty
                  ? const Center(child: Text("اضغط على قائمة التشغيل لإدخال اليوزر والباسورد"))
                  : ListView.builder(
                      itemCount: channels.length > 200 ? 200 : channels.length,
                      itemBuilder: (context, idx) {
                        final ch = channels[idx];
                        final streamUrl = "$hostUrl/live/$username/$password/${ch['stream_id']}.m3u8";
                        return ListTile(
                          title: Text("${idx + 1} - ${ch['name']}", style: const TextStyle(fontSize: 13)),
                          trailing: const Icon(Icons.play_circle_fill, color: Color(0xFFD4AF37)),
                          onTap: () => _playChannel(streamUrl, ch['name'] ?? ''),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black, border: Border.all(color: const Color(0xFFD4AF37))),
                    child: _videoController != null && _videoController!.value.isInitialized
                        ? VideoPlayer(_videoController!)
                        : const Center(child: Text("👑 OSASTREAM 4K PLAYER", style: TextStyle(color: Color(0xFFFFE57F)))),
                  ),
                ),
                const SizedBox(height: 10),
                Text(activeChannelTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFE57F))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistScreen() {
    final userCtrl = TextEditingController(text: username);
    final passCtrl = TextEditingController(text: password);
    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141009),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("إضافة قائمة تشغيل - OSASTREAM 4K", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFE57F))),
            const SizedBox(height: 6),
            const Text("Host: https://fast-wolf.site | MAC: A4:F3:04:2F:A0:88", style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(controller: userCtrl, decoration: const InputDecoration(labelText: "اسم المستخدم (Username)")),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "كلمة المرور (Password)")),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
              onPressed: () {
                _saveCredentials(hostUrl, userCtrl.text.trim(), passCtrl.text.trim());
                setState(() => currentView = "home");
              },
              child: const Text("حفظ والاتصال بالسيرفر", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
