import 'package:flutter/material.dart';

class PhotoButton extends StatelessWidget {
  const PhotoButton({
    super.key,
    required this.label,
    required this.path,
    required this.onPressed,
  });

  final String label;
  final String? path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        path == null ? Icons.camera_alt_rounded : Icons.check_circle_rounded,
      ),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(path == null ? label : '$label capturada'),
      ),
    );
  }
}
