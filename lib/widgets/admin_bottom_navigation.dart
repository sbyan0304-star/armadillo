import 'package:armadillo/screens/admin_profile_screen.dart';
import 'package:armadillo/screens/admin_search_screen.dart';
import 'package:flutter/material.dart';
import '../screens/admin_home_screen.dart';
import '../screens/admin_create_recipe_screen.dart';

class AdminBottomNavigation extends StatelessWidget {
  final int currentIndex;

  const AdminBottomNavigation({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) {
      return;
    }

    Widget screen;

    switch (index) {
      case 0:
        screen = const AdminHomeScreen();
        break;

      case 1:
        screen = const AdminCreateRecipeScreen();
        break;

      case 2:
        screen = const AdminSearchScreen();
        break;

      case 3:
        screen = const AdminProfileScreen();
        break;

      default:
        screen = const AdminHomeScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 300,
          height: 52,
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF16D928),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIcon(context, icon: Icons.home_outlined, index: 0),
              _buildIcon(context, icon: Icons.add_box_outlined, index: 1),
              _buildIcon(context, icon: Icons.search, index: 2),
              _buildIcon(context, icon: Icons.person_outline, index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context, {
    required IconData icon,
    required int index,
  }) {
    final bool selected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        _navigate(context, index);
      },
      child: SizedBox(
        width: 45,
        height: 52,
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: Colors.white,
            weight: selected ? 700 : null,
          ),
        ),
      ),
    );
  }
}
