import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/form_choice.dart';

/// A multiple-choice field rendered as a wrap of FilterChips, bound to a list
/// of stable [FormChoice.value]s. [onToggle] receives the value the user tapped
/// so callers can apply custom selection rules (e.g. the "Ausente" exclusivity).
class BrandtMultiSelectField extends StatelessWidget {
  const BrandtMultiSelectField({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onToggle,
    this.errorText,
  });

  final String label;
  final List<FormChoice> choices;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: choices.map((choice) {
            final isSelected = selected.contains(choice.value);
            return FilterChip(
              label: Text(choice.label),
              selected: isSelected,
              onSelected: (_) => onToggle(choice.value),
              showCheckmark: true,
              selectedColor: brandtGreen.withValues(alpha: 0.16),
              checkmarkColor: brandtGreen,
            );
          }).toList(),
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
