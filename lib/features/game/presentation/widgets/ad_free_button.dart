import 'package:flutter/material.dart';
import '../../../../core/theme/game_theme.dart';
import '../game_controller.dart';
import '../shop_screen.dart';

class AdFreeIcon extends StatelessWidget {
  const AdFreeIcon({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 30,
      height: 28,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 25,
              height: 21,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: GameTheme.teal, width: 1.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AD',
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: GameTheme.cream,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block_rounded,
                size: 18,
                color: GameTheme.coral,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AdFreeButton extends StatelessWidget {
  const AdFreeButton({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    key: const ValueKey('ad-free'),
    tooltip: 'Sem anúncios · ver plano na Loja',
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xFFD9EBE6),
      foregroundColor: GameTheme.teal,
    ),
    onPressed: controller.interactive && !controller.dragging
        ? () => openShop(context, controller)
        : null,
    icon: const AdFreeIcon(),
  );
}
