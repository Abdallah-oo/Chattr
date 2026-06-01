import 'dart:ui';

import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/features/contacts/presentation/views/contacts_view.dart';
import 'package:chattr/features/group_chats/presentation/views/groups_view/views/groups_view.dart';
import 'package:chattr/features/private_chats/presentation/views/private_chats_view/private_chats_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    PrivateChatsView(),
    GroupsView(),

    ContactsView(),
  ];

  final List<_NavItem> items = const [
    _NavItem(Icons.chat, Icons.chat_outlined, "Chats"),

    _NavItem(CupertinoIcons.group_solid, CupertinoIcons.group, "Groups"),
    _NavItem(
      Icons.contact_page_rounded,
      Icons.contact_page_outlined,
      'contacts',
    ),
  ];

  void onTap(int index) {
    if (index == currentIndex) return;
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 65,
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
                  child: Icon(
                    isSelected ? items[index].activeIcon : items[index].icon,
                    color: isSelected ? AppColors.primary : Colors.grey,
                    size: 28,
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
