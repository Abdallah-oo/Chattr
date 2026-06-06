import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chattr/core/cubits/download_image/download_image_cubit.dart';
import 'package:chattr/core/helpers/snack_bar.dart';
import 'package:chattr/core/routing/router_models.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/themes/app_text_styles.dart';
import 'package:chattr/core/widgets/custom_text.dart';
import 'package:chattr/core/widgets/image/widgets/download_image_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ViewImage extends StatefulWidget {
  const ViewImage({super.key, required this.imageInfo});
  final ViewImageParams imageInfo;

  @override
  State<ViewImage> createState() => _ViewImageState();
}

class _ViewImageState extends State<ViewImage> {
  final ValueNotifier<bool> showInfo = ValueNotifier(true);
  @override
  void dispose() {
    showInfo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<DownloadImageCubit, DownloadImageState>(
        listener: (context, state) {
          if (state is DownloadImagefailure) {
            CustomSnackBar.error(context, state.errorMessage);
          }
          if (state is DownloadImageSucess) {
            CustomSnackBar.success(context, "Image Saved in Gallary");
          }
        },
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                showInfo.value = !showInfo.value;
              },
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: (widget.imageInfo.imageUrl.startsWith('/') &&
                      File(widget.imageInfo.imageUrl).existsSync())
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(widget.imageInfo.imageUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        gaplessPlayback: true,
                        cacheWidth:
                            800, // يحط الصورة في الـ image cache بـ resolution معقولة
                        frameBuilder: (_, child, frame, _) =>
                            frame == null ? _Placeholder() : child,
                      ),
                    )
                  : CachedNetworkImage(
                      fit: BoxFit.contain,
                      imageUrl: widget.imageInfo.imageUrl,
                      placeholder: (context, url) => Center(
                        child: CupertinoActivityIndicator(
                          color: Colors.white54,
                          radius: 9,
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ),
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: showInfo,
              builder: (context, value, _) {
                return Visibility(
                  visible: value,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(0, 50, 0, 10),
                    color: AppColors.surface.withOpacity(0.5),
                    height: 100,
                    child: Row(
                      children: [
                        Gap(5),
                        InkWell(
                          onTap: () => context.pop(),
                          child: Icon(CupertinoIcons.back),
                        ),
                        Gap(10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              text: widget.imageInfo.senderName,
                              style: AppTextStyles.bodySmall,
                            ),

                            CustomText(
                              text: widget.imageInfo.messageData.createdAt
                                  .toString(),
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        Spacer(),
                        DownloadImageButton(
                          imageUrl: widget.imageInfo.imageUrl,
                        ),
                        Gap(20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 200,
    width: double.infinity,
    child: Center(
      child: CupertinoActivityIndicator(color: Colors.white54, radius: 9),
    ),
  );
}
