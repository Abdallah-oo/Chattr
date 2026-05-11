import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';


class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.titleItems,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final List<Widget>? titleItems;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.groundColor,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: leading,
      actions:
          actions ??
          [
            Icon(Icons.more_horiz_rounded, color: AppColors.titleColor),
            Gap(15),
          ],
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(text: title, size: 17),
          ...(titleItems ?? []),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    titleItems == null ? kToolbarHeight : kToolbarHeight + 20,
  );
}
