import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';


class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int currentIndex = 0;

  final List<Widget> pages = const [
  
  ];

  final List<_NavItem> items = const [
    _NavItem(Icons.home, Icons.contact_page_rounded, 'contacts'),

  ];

  void onTap(int index) {
    if (index == currentIndex) return;
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: currentIndex, children: pages),
            Positioned(
              bottom: 20,
              left: 14,
              right: 14,
              child: _ModernNavBar(
                currentIndex: currentIndex,
                items: items,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final Function(int) onTap;

  const _ModernNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            boxShadow: AppColors.shadowMd,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = index == currentIndex;

              return GestureDetector(
                      onTap: () => onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 4,
                              width: isSelected ? 30 : 0,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF20B812),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? items[index].activeIcon
                                  : items[index].icon,
                              color: isSelected
                                  ? const Color(0xFF20B812)
                                  : AppColors.titleColor,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;

  const _NavItem(this.activeIcon, this.icon, this.label);
}
