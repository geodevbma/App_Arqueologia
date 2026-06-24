import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../models/poco_teste_photo.dart';

/// A multi-photo field: shows captured photos as thumbnails (with delete) and
/// offers capture from the camera or the gallery. Capture is delegated to
/// [onAdd] so the screen can attach GPS + watermark in one place.
class BrandtPhotoField extends StatelessWidget {
  const BrandtPhotoField({
    super.key,
    required this.label,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.required = true,
    this.errorText,
  });

  final String label;
  final List<PocoTestePhoto> photos;
  final Future<void> Function(ImageSource source) onAdd;
  final void Function(int index) onRemove;
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
                photos.isEmpty
                    ? Icons.photo_camera_outlined
                    : Icons.check_circle_rounded,
                color: photos.isEmpty ? textMuted : brandtGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  required ? '$label *' : label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (photos.isNotEmpty)
                Text(
                  '${photos.length} foto(s)',
                  style: const TextStyle(color: textMuted, fontSize: 12),
                ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    _thumb(context, photos[index], index),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAdd(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Câmera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAdd(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeria'),
                ),
              ),
            ],
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

  Widget _thumb(BuildContext context, PocoTestePhoto photo, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(photo.localPath),
            height: 96,
            width: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => Container(
              height: 96,
              width: 96,
              color: softBackground,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: () => onRemove(index),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
