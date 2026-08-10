import 'package:flutter/material.dart';

/// Favorite toggle affordance for product cards and detail headers.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({required this.isFavorite, super.key, this.onPressed});

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isFavorite
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return IconButton(
      onPressed: onPressed,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: color,
      ),
    );
  }
}
