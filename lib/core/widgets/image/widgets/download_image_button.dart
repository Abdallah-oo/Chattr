import 'package:chattr/core/cubits/download_image/download_image_cubit.dart';
import 'package:chattr/core/utils/extensions/responsive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DownloadImageButton extends StatelessWidget {
  final String imageUrl;
  const DownloadImageButton({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadImageCubit, DownloadImageState>(
      buildWhen: (prev, curr) =>
          prev is DownloadImageLoading || curr is DownloadImageLoading,
      builder: (context, state) {
        final isLoading = state is DownloadImageLoading;

        return isLoading
            ? imageUrl.startsWith('/')
                  ? CupertinoActivityIndicator(
                      radius: 9,
                      color: Colors.green,
                    )
                  : SizedBox(
                      width: context.screenWidth * 0.2,
                      child: LinearProgressIndicator(
                        value: state.progress,
                        color: Colors.green,
                      ),
                    )
            : InkWell(
                onTap: () {
                  context.read<DownloadImageCubit>().downloadImage(imageUrl);
                },
                child: Icon(Icons.download),
              );
      },
    );
  }
}
