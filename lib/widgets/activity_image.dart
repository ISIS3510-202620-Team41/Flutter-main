import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../cache/activity_image_cache.dart';
import '../theme/app_theme.dart';

class ActivityImage extends StatelessWidget {
  const ActivityImage({super.key, required this.url, required this.height});

  final String url;
  final double height;

  //El archivo almacenado en el disco conserva su tamaño original.
  static const _memCacheWidth = 800;

  Widget _placeholder() => Container(
    height: height,
    width: double.infinity,
    color: AppColors.blue.withValues(alpha: 0.30),
    child: const Center(child: Icon(Icons.image_outlined, size: 34)),
  );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: ActivityImageCacheManager.instance, // disk cache
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      memCacheWidth: _memCacheWidth, // memory cache (decoded size)
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }
}