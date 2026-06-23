import 'package:flutter/material.dart';

import '../../models/form_choice.dart';

/// A single-choice dropdown bound to a stable [FormChoice.value].
class BrandtSelectField extends StatelessWidget {
  const BrandtSelectField({
    super.key,
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final List<FormChoice> choices;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      items: choices
          .map(
            (choice) => DropdownMenuItem(
              value: choice.value,
              child: Text(choice.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
