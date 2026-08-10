import 'package:base_project/app/theme/app_spacing.dart';
import 'package:base_project/core/constants/image_sizes.dart';
import 'package:base_project/core/ui/glass/glass_card.dart';
import 'package:flutter/material.dart';

/// Reusable category tile shell for catalog grids.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.name,
    super.key,
    this.imageUrl,
    this.onTap,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      variant: GlassCardVariant.interactive,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: ImageSizes.categoryIcon,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
