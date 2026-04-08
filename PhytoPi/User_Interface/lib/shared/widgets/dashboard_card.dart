import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final BorderRadiusGeometry borderRadius;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? theme.colorScheme.primary;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [theme.cardColor, theme.cardColor.withOpacity(0.85)]
              : [Colors.white, theme.colorScheme.surfaceContainerLow],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.16 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.08 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: accent.withOpacity(isDark ? 0.18 : 0.14),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

