import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:messenger_clone0/core/themes/app_colors.dart';
import 'package:messenger_clone0/core/themes/app_text_styles.dart';
import 'package:messenger_clone0/core/widgets/custom_text.dart';
import 'package:messenger_clone0/features/auth/data/models/user_model.dart';

class ContactItem extends StatelessWidget {
  const ContactItem({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      color: AppColors.surface,
      elevation: 0.3,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            _Avatar(imageUrl: user.image),
            const Gap(10),
            _UserInfo(name: user.name, email: user.email),
            const Spacer(),
            _MessageButton(
              onTap: () {
                // TODO: navigate to chat
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.imageUrl});
  final String? imageUrl;

  static const _fallback =
      'https://static.thenounproject.com/png/1856610-200.png';

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      child: ClipOval(
        child: CachedNetworkImage(
          fit: BoxFit.cover,
          imageUrl: imageUrl ?? _fallback,
          placeholder: (_, _) => const CupertinoActivityIndicator(
            color: Colors.white54,
            radius: 9,
          ),
          errorWidget: (_, _, _) => const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.red,
            size: 40,
          ),
        ),
      ),
    );
  }
}

class _UserInfo extends StatelessWidget {
  const _UserInfo({this.name, this.email});
  final String? name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(text: name ?? '', style: AppTextStyles.bodyMedium),
        CustomText(text: email ?? '', style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const Icon(Icons.message, color: AppColors.primary),
    );
  }
}
