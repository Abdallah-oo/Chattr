import 'package:chattr/core/cubits/pick_image/pick_image_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';



class ImageViewContainer extends StatelessWidget {
  const ImageViewContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PickImageCubit, PickImageState>(
      builder: (context, state) {
        final imageFile = context.read<PickImageCubit>().imageFile;

        return imageFile != null
            ? Container(
                height: 100,
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 50,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(imageFile, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          top: -3,
                          child: GestureDetector(
                            onTap: () =>
                                context.read<PickImageCubit>().deleteImage(),
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                size: 13.5,
                                Icons.close_rounded,
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : SizedBox.fromSize();
      },
    );
  }
}
