import 'package:flutter/material.dart';
import 'explore.dart';
import 'post.dart';
import 'message.dart';

class MainScreen extends StatefulWidget {
  final String username;
  final String privateKey;
  final String address;
  const MainScreen({Key? key, required this.username, required this.privateKey, required this.address}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ExplorePage(),
      PostPage(
        username: widget.username,
        privateKey: widget.privateKey,
        address: widget.address,
      ),
      MessagesPage(
        currentUsername: widget.username,
        currentAddress: widget.address,
        currentPrivateKey: widget.privateKey,
      ),
    ];
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900.withOpacity(0.8),
              Colors.purple.shade900.withOpacity(0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade400.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.explore, size: 28),
                label: 'Explore',
                activeIcon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade400.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.explore, color: Colors.white, size: 28),
                ),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_box, size: 28),
                label: 'Post',
                activeIcon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade400.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.add_box, color: Colors.white, size: 28),
                ),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.message, size: 28),
                label: 'Messages',
                activeIcon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade400.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.message, color: Colors.white, size: 28),
                ),
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.6),
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}