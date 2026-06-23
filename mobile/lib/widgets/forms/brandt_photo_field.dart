import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/poco_teste_photo.dart';

/// A required/optional photo field showing a thumbnail when captured and a
/// large capture button otherwise. Capture itself is delegated to [onCapture]
/// so the screen can attach GPS metadata in one place.
class BrandtPhotoField extends StatelessWidget {
  const BrandtPhotoField({
    super.key,
    required this.label,
    required this.photo,
    required this.onCapture,
    this.required = true,
    this.errorText,
  });

  final String label;
  final PocoTestePhoto? photo;
  final Future<void> Function() onCapture;
  final bool required;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final borderColor = hasError
        ? Theme.of(context).colorScheme.error
        : borderSoft;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                photo == null
                    ? Icons.photo_camera_outlined
                    : Icons.check_circle_rounded,
                color: photo == null ? textMuted : brandtGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  required ? '$label *' : label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (photo != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photo!.localPath),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => Container(
                  height: 150,
                  color: softBackground,
                  alignment: Alignment.center,
                  child: const Text('Arquivo de imagem não encontrado'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(photo == null ? 'Capturar foto' : 'Refazer foto'),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            Text(
              errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
