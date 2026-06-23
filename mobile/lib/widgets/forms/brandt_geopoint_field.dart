import 'package:flutter/material.dart';

import '../../models/poco_teste_geo.dart';
import '../status_banner.dart';

/// Displays the captured [GeoPoint] and exposes capture / manual-edit actions.
class BrandtGeopointField extends StatelessWidget {
  const BrandtGeopointField({
    super.key,
    required this.geo,
    required this.onCapture,
    required this.onManualEdit,
    this.errorText,
  });

  final GeoPoint geo;
  final Future<void> Function() onCapture;
  final Future<void> Function() onManualEdit;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = geo.hasValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusBanner(
          icon: hasValue
              ? Icons.my_location_rounded
              : Icons.location_searching_rounded,
          text: hasValue
              ? '${geo.latitude!.toStringAsFixed(7)}, ${geo.longitude!.toStringAsFixed(7)}'
                    '${geo.accuracy != null ? ' · precisão ${geo.accuracy!.toStringAsFixed(1)} m' : ''}'
                    '${geo.coordinateWasEdited ? ' · editada manualmente' : ''}'
              : 'Coordenada ainda não capturada',
          tone: hasValue
              ? BannerTone.success
              : (errorText != null ? BannerTone.error : BannerTone.warning),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.gps_fixed_rounded),
                label: const Text('Capturar GPS'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onManualEdit,
              icon: const Icon(Icons.edit_location_alt_rounded),
            ),
          ],
        ),
        if (errorText != null) ...[
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
    );
  }
}
