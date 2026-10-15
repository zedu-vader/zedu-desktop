import 'package:zedu/core/core.dart';

class ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppPalette colors;
  final bool isActive;

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colors,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? colors.primary
                : colors
                      .textPrimary, // VADER-227 contrast fix.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}
