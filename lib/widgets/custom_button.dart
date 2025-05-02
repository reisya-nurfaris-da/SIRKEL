import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  static const _gradient = LinearGradient(
    colors: [
      Color(0xFF2FA7ED),
      Color(0xFF1A73E8),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Overlay: 10% black on hover, 20% on press
  WidgetStateProperty<Color?> get _overlayColor {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.black.withValues(alpha: 0.2);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return Colors.black.withValues(alpha: 0.1);
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Outlined variant
    if (isOutlined) {
      return SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ).copyWith(
            overlayColor: _overlayColor,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(text,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      );
    }

    // Filled-gradient variant
    return SizedBox(
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.circular(100),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ).copyWith(
            overlayColor: _overlayColor,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
