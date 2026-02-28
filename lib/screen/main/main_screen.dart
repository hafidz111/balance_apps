import 'package:balance/screen/barcode/barcode_screen.dart';
import 'package:balance/screen/history/history_screen.dart';
import 'package:balance/screen/point_coffee/point_coffee_screen.dart';
import 'package:balance/screen/settings/settings_screen.dart';
import 'package:balance/screen/store/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../service/shared_preferences_service.dart';
import '../grid_photo/grid_photo_screen.dart';
import '../say_bread/say_bread_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;

  static const List<Widget> _widgetOptions = <Widget>[
    StoreScreen(),
    PointCoffeeScreen(),
    SayBreadScreen(),
    HistoryScreen(),
    BarcodeScreen(),
    GridPhotoScreen(),
    SettingsScreen(),
  ];

  static const List<String> _titles = [
    "Store",
    "Point Coffee",
    "Say Bread",
    "History",
    "Barcode",
    "Space",
    'Settings',
  ];

  static const List<IconData> _icons = [
    Icons.store,
    Icons.coffee,
    Icons.bakery_dining,
    Icons.history,
    Icons.qr_code,
    Icons.space_dashboard,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();
    _checkStoreData();
  }

  Future<void> _checkStoreData() async {
    final service = SharedPreferencesService();

    final pc = await service.getPointCoffeeStore();
    final sb = await service.getSayBreadStore();

    if (pc == null ||
        pc.title.isEmpty ||
        pc.nama.isEmpty ||
        pc.kode.isEmpty ||
        pc.tgl.isEmpty ||
        pc.area.isEmpty ||
        sb == null ||
        sb.title.isEmpty ||
        sb.nama.isEmpty ||
        sb.kode.isEmpty ||
        sb.tgl.isEmpty ||
        sb.area.isEmpty) {
      setState(() {
        _selectedIndex = 0;
      });
    } else {
      setState(() {
        _selectedIndex = 1;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<FirebaseAuthProvider>();
    final isLogin = context.watch<SharedPreferenceProvider>().isLogin;
    final user = authProvider.profile;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF009688),
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(color: Colors.white),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            color: Colors.white,
          ),
        ),
      ),
      body: _widgetOptions[_selectedIndex],
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF009688)),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Balance App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // InkWell(
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //
                  //     if (isLogin) {
                  //       _onItemTapped(5);
                  //     } else {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (_) => const LoginScreen(),
                  //         ),
                  //       );
                  //     }
                  //   },
                  //   child: Row(
                  //     children: [
                  //       CircleAvatar(
                  //         radius: 30,
                  //         backgroundImage: user?.photoUrl != null
                  //             ? NetworkImage(user!.photoUrl!)
                  //             : null,
                  //         child: user?.photoUrl == null
                  //             ? const Icon(Icons.person, size: 40)
                  //             : null,
                  //       ),
                  //       const SizedBox(width: 16),
                  //       Expanded(
                  //         child: Column(
                  //           mainAxisAlignment: MainAxisAlignment.center,
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Text(
                  //               isLogin
                  //                   ? (authProvider.profile?.name ?? "User")
                  //                   : "Masuk / Login",
                  //               style: TextStyle(
                  //                 color: Colors.white,
                  //                 fontSize: 18,
                  //                 fontWeight: FontWeight.bold,
                  //               ),
                  //             ),
                  //             Text(
                  //               isLogin ? "Admin" : "Klik untuk akses akun",
                  //               style: TextStyle(
                  //                 color: Colors.white.withValues(alpha: 0.8),
                  //                 fontSize: 13,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < _titles.length; i++)
                    ListTile(
                      leading: Icon(
                        _icons[i],
                        color: _selectedIndex == i
                            ? const Color(0xFF009688)
                            : Colors.grey,
                      ),
                      title: Text(
                        _titles[i],
                        style: TextStyle(
                          color: _selectedIndex == i
                              ? const Color(0xFF009688)
                              : Colors.black87,
                          fontWeight: _selectedIndex == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedIndex == i,
                      onTap: () {
                        _onItemTapped(i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
