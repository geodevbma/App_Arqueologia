/// Identifies the "Poço teste" form and decides whether a given bootstrap form
/// should open the native Poço teste screen instead of the generic collection
/// form.
class PocoTesteFormDescriptor {
  PocoTesteFormDescriptor._();

  static const formCode = 'poco_teste';
  static const formTitle = 'Poço teste';

  /// Returns true when [form] (a bootstrap form map) should be rendered by the
  /// native Poço teste screen. Matches on an explicit `code`/`slug` or on the
  /// form name containing "poço teste" (accent/case insensitive).
  static bool matches(Map<String, dynamic> form) {
    final code = (form['code'] ?? form['slug'] ?? '').toString().toLowerCase();
    if (code == formCode) return true;
    final name = (form['name'] ?? form['title'] ?? '').toString();
    final normalized = name
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ô', 'o')
        .replaceAll('ó', 'o');
    return normalized.contains('poco teste');
  }
}
