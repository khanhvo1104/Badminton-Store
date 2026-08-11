import 'package:base_project/core/ui/glass/glass_background.dart';
import 'package:flutter/material.dart';

/// Shared light storefront chrome for authenticated routes outside the shell.
///
/// Wraps content in the mint glass ambient background so child screens match
/// Home instead of falling through to a black route surface.
class ShopPageScaffold extends StatelessWidget {
  const ShopPageScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.enableAmbientMotion = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;
  final bool enableAmbientMotion;

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      enableAmbientMotion: enableAmbientMotion,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      ),
    );
  }
}
