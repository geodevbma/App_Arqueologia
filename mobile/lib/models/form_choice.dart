import 'dart:core';

/// A single selectable option in a form field.
///
/// [value] is the stable, normalized identifier used internally and in the
/// saved payload. [label] is the human friendly text shown to the user.
class FormChoice {
  const FormChoice(this.value, this.label);

  final String value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FormChoice && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Normalizes a raw value coming from the XLSForm (or user input) into a stable
/// internal value: trimmed, lower cased, accents removed and spaces/hyphens
/// collapsed into underscores.
///
/// Examples:
/// - `"Saturação_Hídrica"` -> `"saturacao_hidrica"`
/// - `"Intransponível rocha"` -> `"intransponivel_rocha"`
/// - `"Outro "` / `"Outro"` -> `"outro"`
/// - `"Não"` / `"não"` / `"nao "` -> `"nao"`
String normalizeChoiceValue(String raw) {
  var value = raw.trim().toLowerCase();
  const accents = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final char in value.split('')) {
    buffer.write(accents[char] ?? char);
  }
  value = buffer.toString();
  // Collapse any run of non alphanumeric characters into a single underscore.
  value = value.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  value = value.replaceAll(RegExp(r'^_+|_+$'), '');
  return value;
}

/// Helper to look up the display label for a stable value within a list of
/// choices. Falls back to the value itself when not found.
String labelForValue(List<FormChoice> choices, String? value) {
  if (value == null || value.isEmpty) return '';
  for (final choice in choices) {
    if (choice.value == value) return choice.label;
  }
  return value;
}

/// Joins the labels of every selected [values] within [choices], for display.
String labelsForValues(List<FormChoice> choices, List<String> values) {
  if (values.isEmpty) return '';
  return values.map((value) => labelForValue(choices, value)).join(', ');
}
