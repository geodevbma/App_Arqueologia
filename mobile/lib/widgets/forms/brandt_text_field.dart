import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A labeled text field that owns its [TextEditingController], initialized once
/// from [initialValue] and reporting edits through [onChanged]. Designed for
/// field use: large touch target, optional error text and hint.
class BrandtTextField extends StatefulWidget {
  const BrandtTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.readOnly = false,
    this.decimal = false,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? errorText;
  final int maxLines;
  final bool readOnly;
  final bool decimal;

  @override
  State<BrandtTextField> createState() => _BrandtTextFieldState();
}

class _BrandtTextFieldState extends State<BrandtTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      keyboardType: widget.decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: widget.decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.hint,
        errorText: widget.errorText,
        suffixIcon: widget.readOnly
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
    );
  }
}
