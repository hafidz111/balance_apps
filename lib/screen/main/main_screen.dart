import 'package:balance/screen/barcode/barcode_screen.dart';
import 'package:balance/screen/history/history_screen.dart';
import 'package:balance/screen/point_coffee/point_coffee_screen.dart';
import 'package:balance/screen/store/store_screen.dart';
import 'package:flutter/material.dart';

import '../../service/shared_preferences_service.dart';
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
  ];

  static const List<String> _titles = [
    "Store",
    "Point Coffee",
    "Say Bread",
    "History",
    "Barcode",
  ];

  static const List<IconData> _icons = [
    Icons.store,
    Icons.coffee,
    Icons.bakery_dining,
    Icons.history,
    Icons.qr_code,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              icon: const Icon(Icons.menu),
            );
          },
        ),
      ),
      body: Center(child: _widgetOptions[_selectedIndex]),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Balance'),
            ),
            for (int i = 0; i < _titles.length; i++)
              ListTile(
                leading: Icon(
                  _icons[i],
                  color: _selectedIndex == i ? const Color(0xFF009688) : null,
                ),
                title: Text(_titles[i]),
                selected: _selectedIndex == i,
                onTap: () {
                  _onItemTapped(i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
