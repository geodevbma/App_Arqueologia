import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/access.dart';
import '../core/providers.dart';
import '../core/sync_service.dart';
import '../core/watermark_service.dart';
import '../widgets/app_widgets.dart';

class CollectionFormScreen extends ConsumerStatefulWidget {
  const CollectionFormScreen({super.key, required this.project, required this.form, this.collection});
  final Map<String, dynamic> project;
  final Map<String, dynamic> form;
  final Map<String, dynamic>? collection;

  @override
  ConsumerState<CollectionFormScreen> createState() => _CollectionFormScreenState();
}

class _CollectionFormScreenState extends ConsumerState<CollectionFormScreen> {
  late final List<Map<String, dynamic>> fields;
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _values = {};
  final otherPoint = TextEditingController();

  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> points = [];
  String? sectionId;
  String? pointId;
  bool pointOther = false;
  String? _sectionFieldKey;
  String? _pointFieldKey;

  // Coordenada unica (field_type 'coordinate' -> colunas latitude/longitude).
  double? latitude;
  double? longitude;
  double? accuracy;
  double? originalLatitude;
  double? originalLongitude;
  bool coordinateEdited = false;

  Map<String, dynamic>? _user;
  bool loading = true;
  String? error;
  bool get editing => widget.collection != null;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    otherPoint.dispose();
    super.dispose();
  }

  String? _sourceOf(Map<String, dynamic> field) {
    final options = field['options'];
    if (options is Map && options['source'] != null) return options['source'] as String;
    return null;
  }

  bool _multiplePhotos(Map<String, dynamic> field) {
    final options = field['options'];
    return options is Map && options['multiple'] == true;
  }

  List<Map<String, dynamic>> _choices(Map<String, dynamic> field) {
    final options = field['options'];
    if (options is Map && options['choices'] is List) {
      return (options['choices'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  bool _isWorkPointOther(Map<String, dynamic> field) {
    final cond = field['conditional_logic'];
    return cond is Map && _pointFieldKey != null && cond['field'] == _pointFieldKey && cond['value']?.toString() == 'other';
  }

  Future<void> _load() async {
    fields = (widget.form['fields'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList()
      ..sort((a, b) => ((a['order_index'] as int?) ?? 0).compareTo((b['order_index'] as int?) ?? 0));

    for (final field in fields) {
      final source = _sourceOf(field);
      if (source == 'sections') _sectionFieldKey = field['field_key'] as String;
      if (source == 'work_points') _pointFieldKey = field['field_key'] as String;
    }

    _user = await ref.read(storeProvider).user();
    final loadedSections = await ref.read(storeProvider).sectionsForProject(widget.project['id'] as String);
    final savedSectionId = widget.collection?['section_id'] as String?;
    final initialSectionId = savedSectionId ?? (loadedSections.isEmpty ? null : loadedSections.first['id'] as String);
    final loadedPoints =
        initialSectionId == null ? <Map<String, dynamic>>[] : await ref.read(storeProvider).pointsForSection(initialSectionId);

    for (final field in fields) {
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      if (_sourceOf(field) != null || _isWorkPointOther(field) || type == 'coordinate' || type == 'note') continue;
      switch (type) {
        case 'text':
        case 'textarea':
        case 'number':
          _text[key] = TextEditingController();
          break;
        case 'auto_user':
          _text[key] = TextEditingController(text: (_user?['name'] as String?) ?? '');
          break;
        case 'multiselect':
          _values[key] = <String>[];
          break;
        case 'boolean':
          _values[key] = false;
          break;
        case 'date':
        case 'datetime':
          _values[key] = DateTime.now();
          break;
        case 'photo':
          _values[key] = _multiplePhotos(field) ? <String>[] : null;
          break;
        case 'coordinate_list':
          _values[key] = <Map<String, dynamic>>[];
          break;
        case 'select':
        default:
          _values[key] = null;
      }
    }

    setState(() {
      sections = loadedSections;
      sectionId = initialSectionId;
      points = loadedPoints;
      if (widget.collection != null) _applyExistingCollection(widget.collection!);
      loading = false;
    });
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  dynamic _answerValue(Map<String, dynamic> collection, String key) {
    final answers = (collection['answers'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    return answers.firstWhere((item) => item['field_key'] == key, orElse: () => {'answer_value': null})['answer_value'];
  }

  List<String> _photoPaths(Map<String, dynamic> collection, String type) {
    final photos = (collection['photos'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    return photos.where((item) => item['photo_type'] == type).map((item) => item['file_path'] as String).toList();
  }

  dynamic _readValue(String key) {
    if (key == _sectionFieldKey) return sectionId;
    if (key == _pointFieldKey) return pointOther ? 'other' : pointId;
    if (_text.containsKey(key)) return _text[key]!.text;
    return _values[key];
  }

  bool _visible(Map<String, dynamic> field) {
    final cond = field['conditional_logic'];
    if (cond is! Map) return true;
    final target = _readValue(cond['field'] as String);
    final op = (cond['operator'] as String?) ?? 'equals';
    final val = cond['value'];
    if (op == 'contains') return target is List && target.contains(val);
    if (val is bool) return _asBool(target) == val;
    if (target is bool) return target.toString() == val.toString();
    return (target?.toString() ?? '') == (val?.toString() ?? '');
  }

  void _applyExistingCollection(Map<String, dynamic> collection) {
    sectionId = collection['section_id'] as String?;
    final workPointOther = collection['work_point_other'] as String?;
    pointOther = workPointOther != null && workPointOther.isNotEmpty;
    pointId = pointOther ? null : collection['work_point_id'] as String?;
    otherPoint.text = workPointOther ?? '';
    latitude = _asDouble(collection['latitude']);
    longitude = _asDouble(collection['longitude']);
    accuracy = _asDouble(collection['gps_accuracy']);
    originalLatitude = _asDouble(collection['original_latitude']);
    originalLongitude = _asDouble(collection['original_longitude']);
    coordinateEdited = _asBool(collection['coordinate_was_edited']);

    for (final field in fields) {
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      if (_sourceOf(field) != null || _isWorkPointOther(field)) continue;
      final saved = _answerValue(collection, key);
      switch (type) {
        case 'text':
        case 'textarea':
        case 'auto_user':
          if (saved != null) _text[key]?.text = saved.toString();
          break;
        case 'number':
          if (saved != null) _text[key]?.text = saved.toString();
          break;
        case 'multiselect':
          _values[key] = saved is List ? saved.map((item) => item.toString()).toList() : <String>[];
          break;
        case 'boolean':
          _values[key] = _asBool(saved);
          break;
        case 'select':
          _values[key] = saved?.toString();
          break;
        case 'date':
        case 'datetime':
          final fromColumn = collection['collection_date'] as String?;
          final raw = saved?.toString() ?? fromColumn;
          _values[key] = raw == null ? _values[key] : DateTime.tryParse(raw);
          break;
        case 'photo':
          final paths = _photoPaths(collection, key);
          _values[key] = _multiplePhotos(field) ? paths : (paths.isEmpty ? null : paths.first);
          break;
        case 'coordinate_list':
          _values[key] = saved is List ? saved.map((item) => Map<String, dynamic>.from(item as Map)).toList() : <Map<String, dynamic>>[];
          break;
      }
    }
  }

  Future<void> _changeSection(String value) async {
    final loadedPoints = await ref.read(storeProvider).pointsForSection(value);
    setState(() {
      sectionId = value;
      points = loadedPoints;
      pointId = null;
      pointOther = false;
    });
  }

  Future<Position?> _capturePosition() async {
    setState(() => error = null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => error = 'Permissao de localizacao negada.');
      return null;
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<void> _captureGps() async {
    final position = await _capturePosition();
    if (position == null) return;
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
      originalLatitude ??= position.latitude;
      originalLongitude ??= position.longitude;
      accuracy = position.accuracy;
    });
  }

  Future<void> _manualCoordinate() async {
    final lat = TextEditingController(text: latitude?.toStringAsFixed(7) ?? '');
    final lng = TextEditingController(text: longitude?.toStringAsFixed(7) ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Editar coordenada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar coordenada')),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        originalLatitude ??= latitude;
        originalLongitude ??= longitude;
        latitude = double.tryParse(lat.text.replaceAll(',', '.'));
        longitude = double.tryParse(lng.text.replaceAll(',', '.'));
        coordinateEdited = true;
      });
    }
  }

  int _utmZone(double longitude) => ((longitude + 180) / 6).floor() + 1;

  Future<void> _addCoordinatePoint(String key, Map<String, dynamic> field) async {
    final position = await _capturePosition();
    if (position == null) return;
    final options = field['options'] is Map ? field['options'] as Map : const {};
    final point = <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      if (options['capture_altitude'] == true) 'altitude': double.parse(position.altitude.toStringAsFixed(2)),
      if (options['compute_utm_zone'] == true) 'zona_utm': _utmZone(position.longitude),
      'ponto': '${(_values[key] as List).length + 1}',
    };
    setState(() => (_values[key] as List).add(point));
  }

  Future<String?> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final image = await ImagePicker().pickImage(source: source, imageQuality: 74, maxWidth: 1600);
    if (image == null) return null;
    await const WatermarkService().apply(
      image.path,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      capturedAt: DateTime.now(),
    );
    return image.path;
  }

  String? _validate() {
    for (final field in fields) {
      if (!(field['is_required'] as bool? ?? false)) continue;
      if (!_visible(field)) continue;
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      final label = field['label'] as String;
      final source = _sourceOf(field);
      if (source == 'projects' || type == 'note' || type == 'auto_user') continue;
      if (source == 'sections') {
        if (sectionId == null) return 'Selecione: $label.';
        continue;
      }
      if (source == 'work_points') {
        if (!pointOther && pointId == null) return 'Selecione: $label.';
        continue;
      }
      if (_isWorkPointOther(field)) {
        if (pointOther && otherPoint.text.trim().isEmpty) return 'Informe: $label.';
        continue;
      }
      switch (type) {
        case 'coordinate':
          if (latitude == null || longitude == null) return 'Capture a coordenada: $label.';
          break;
        case 'coordinate_list':
          if ((_values[key] as List).isEmpty) return 'Adicione ao menos um ponto: $label.';
          break;
        case 'photo':
          final value = _values[key];
          if (value == null || (value is List && value.isEmpty)) return 'Foto obrigatoria: $label.';
          break;
        case 'multiselect':
          if ((_values[key] as List).isEmpty) return 'Selecione ao menos uma opcao: $label.';
          break;
        case 'select':
          if (_values[key] == null) return 'Selecione: $label.';
          break;
        case 'date':
        case 'datetime':
          if (_values[key] == null) return 'Informe a data: $label.';
          break;
        case 'boolean':
          // Sempre preenchido: tanto "Sim" (true) quanto "Nao" (false) sao
          // respostas validas para um campo booleano.
          break;
        default:
          if ((_text[key]?.text.trim() ?? '').isEmpty) return 'Preencha: $label.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    final user = _user ?? await ref.read(storeProvider).user();
    if (!canCollectWithUser(user)) {
      setState(() => error = 'Perfil sem permissao para enviar coletas.');
      return;
    }
    final now = DateTime.now().toIso8601String();
    final existing = widget.collection;
    final localUuid = existing?['local_uuid'] as String? ?? const Uuid().v4();

    final answers = <Map<String, dynamic>>[];
    final photos = <Map<String, dynamic>>[];
    DateTime? primaryDate;
    double? lat = latitude;
    double? lng = longitude;

    for (final field in fields) {
      final key = field['field_key'] as String;
      final type = field['field_type'] as String;
      final source = _sourceOf(field);
      if (source != null || _isWorkPointOther(field) || type == 'note') continue;
      final visible = _visible(field);
      switch (type) {
        case 'text':
        case 'textarea':
        case 'auto_user':
          answers.add({'field_key': key, 'answer_value': visible ? _text[key]!.text.trim() : ''});
          break;
        case 'number':
          answers.add({'field_key': key, 'answer_value': visible ? _asDouble(_text[key]!.text) : null});
          break;
        case 'select':
          answers.add({'field_key': key, 'answer_value': visible ? _values[key] : null});
          break;
        case 'multiselect':
          answers.add({'field_key': key, 'answer_value': visible ? _values[key] : <String>[]});
          break;
        case 'boolean':
          answers.add({'field_key': key, 'answer_value': visible ? _values[key] : false});
          break;
        case 'date':
        case 'datetime':
          final value = _values[key] as DateTime?;
          primaryDate ??= value;
          if (type == 'datetime') answers.add({'field_key': key, 'answer_value': value?.toIso8601String()});
          break;
        case 'coordinate':
          // Mapeado para as colunas latitude/longitude da coleta.
          break;
        case 'coordinate_list':
          final list = (_values[key] as List).cast<Map<String, dynamic>>();
          answers.add({'field_key': key, 'answer_value': list});
          if (list.isNotEmpty) {
            lat ??= _asDouble(list.first['latitude']);
            lng ??= _asDouble(list.first['longitude']);
          }
          break;
        case 'photo':
          final value = _values[key];
          final paths = value is List ? value.cast<String>() : (value == null ? <String>[] : [value as String]);
          for (final path in paths) {
            photos.add({
              'photo_type': key,
              'file_path': path,
              'original_filename': p.basename(path),
              'latitude': lat,
              'longitude': lng,
              'taken_at': now,
              'metadata': {'project': widget.project['name'], 'form': widget.form['name'], 'field': key},
            });
          }
          break;
      }
    }

    final payload = {
      'local_uuid': localUuid,
      'project_id': widget.project['id'],
      'form_id': widget.form['id'],
      'form_version': existing?['form_version'] ?? widget.form['current_version'] ?? 1,
      'user_id': existing?['user_id'] ?? user?['id'],
      'section_id': _sectionFieldKey == null ? null : sectionId,
      'work_point_id': _pointFieldKey == null ? null : (pointOther ? null : pointId),
      'work_point_other': _pointFieldKey == null ? null : (pointOther ? otherPoint.text.trim() : null),
      'collection_date': DateFormat('yyyy-MM-dd').format(primaryDate ?? DateTime.now()),
      'latitude': lat,
      'longitude': lng,
      'gps_accuracy': accuracy,
      'original_latitude': originalLatitude,
      'original_longitude': originalLongitude,
      'coordinate_was_edited': coordinateEdited,
      'status': 'pending_sync',
      'sync_status': 'pending_sync',
      'created_locally_at': existing?['created_locally_at'] ?? existing?['created_at_device'] ?? now,
      'updated_locally_at': now,
      'answers': answers,
      'photos': photos,
    };
    await ref.read(storeProvider).saveCollection(payload);
    // Tenta sincronizar imediatamente (best-effort) se houver internet.
    unawaited(ref.read(syncServiceProvider).trigger());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(editing ? 'Coleta atualizada na caixa de saida.' : 'Coleta salva na caixa de saida.')));
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visibleFields = fields.where(_visible).where((field) => _sourceOf(field) != 'projects').toList();
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar coleta' : 'Nova coleta')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Salvar rascunho')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_circle_rounded), label: const Text('Finalizar coleta')),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumHeader(icon: Icons.assignment_turned_in_rounded, title: widget.form['name'] as String, subtitle: widget.project['name'] as String),
          const SizedBox(height: 18),
          if (error != null) ...[
            StatusBanner(icon: Icons.error_outline_rounded, text: error!, tone: BannerTone.error),
            const SizedBox(height: 12),
          ],
          for (final field in visibleFields) ...[
            _buildField(field),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['field_key'] as String;
    final type = field['field_type'] as String;
    final label = field['label'] as String;
    final required = field['is_required'] as bool? ?? false;
    final source = _sourceOf(field);
    final title = required ? '$label *' : label;

    if (source == 'sections') {
      return PremiumCard(
        child: DropdownButtonFormField<String>(
          initialValue: sectionId,
          decoration: InputDecoration(labelText: title),
          items: sections.map((section) => DropdownMenuItem(value: section['id'] as String, child: Text(section['name'] as String))).toList(),
          onChanged: (value) => value == null ? null : _changeSection(value),
        ),
      );
    }

    if (source == 'work_points') {
      final includeOther = field['options'] is Map && field['options']['include_other'] == true;
      return PremiumCard(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: pointOther ? 'other' : pointId,
              decoration: InputDecoration(labelText: title),
              items: [
                ...points.map((point) => DropdownMenuItem(value: point['id'] as String, child: Text(point['name'] as String))),
                if (includeOther) const DropdownMenuItem(value: 'other', child: Text('Outro')),
              ],
              onChanged: (value) => setState(() {
                pointOther = value == 'other';
                pointId = pointOther ? null : value;
              }),
            ),
          ],
        ),
      );
    }

    if (_isWorkPointOther(field)) {
      return PremiumCard(
        child: TextField(controller: otherPoint, decoration: InputDecoration(labelText: title)),
      );
    }

    switch (type) {
      case 'note':
        return PremiumCard(
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF0A7354)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        );
      case 'text':
        return PremiumCard(child: TextField(controller: _text[key], decoration: InputDecoration(labelText: title)));
      case 'textarea':
        return PremiumCard(child: TextField(controller: _text[key], decoration: InputDecoration(labelText: title), maxLines: 4));
      case 'number':
        return PremiumCard(
          child: TextField(
            controller: _text[key],
            decoration: InputDecoration(labelText: title),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        );
      case 'auto_user':
        return PremiumCard(child: TextField(controller: _text[key], readOnly: true, decoration: InputDecoration(labelText: title)));
      case 'boolean':
        return PremiumCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _values[key] as bool? ?? false,
            onChanged: (value) => setState(() => _values[key] = value),
            title: Text(label),
          ),
        );
      case 'select':
        return PremiumCard(
          child: DropdownButtonFormField<String>(
            initialValue: _values[key] as String?,
            decoration: InputDecoration(labelText: title),
            items: _choices(field)
                .map((choice) => DropdownMenuItem(value: choice['value'] as String, child: Text(choice['label'] as String)))
                .toList(),
            onChanged: (value) => setState(() => _values[key] = value),
          ),
        );
      case 'multiselect':
        final selected = (_values[key] as List).cast<String>();
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(icon: Icons.checklist_rounded, title: title),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _choices(field).map((choice) {
                  final value = choice['value'] as String;
                  final isOn = selected.contains(value);
                  return FilterChip(
                    label: Text(choice['label'] as String),
                    selected: isOn,
                    onSelected: (on) => setState(() {
                      if (on) {
                        selected.add(value);
                      } else {
                        selected.remove(value);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      case 'date':
      case 'datetime':
        final value = _values[key] as DateTime?;
        final formatted = value == null
            ? 'Selecionar'
            : (type == 'datetime' ? DateFormat('dd/MM/yyyy HH:mm').format(value) : DateFormat('dd/MM/yyyy').format(value));
        return PremiumCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(formatted),
            trailing: const Icon(Icons.calendar_month_rounded),
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: value ?? DateTime.now(),
              );
              if (selectedDate == null) return;
              var result = selectedDate;
              if (type == 'datetime') {
                if (!mounted) return;
                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()));
                if (time != null) {
                  result = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, time.hour, time.minute);
                }
              }
              setState(() => _values[key] = result);
            },
          ),
        );
      case 'coordinate':
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: Icons.gps_fixed_rounded, title: title),
              const SizedBox(height: 12),
              StatusBanner(
                icon: latitude == null ? Icons.location_searching_rounded : Icons.my_location_rounded,
                text: latitude == null
                    ? 'Coordenada ainda nao capturada'
                    : '${latitude!.toStringAsFixed(7)}, ${longitude!.toStringAsFixed(7)} - precisao ${accuracy?.toStringAsFixed(1) ?? '-'} m',
                tone: latitude == null ? BannerTone.warning : BannerTone.success,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: FilledButton.icon(onPressed: _captureGps, icon: const Icon(Icons.gps_fixed_rounded), label: const Text('Capturar GPS'))),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(onPressed: _manualCoordinate, icon: const Icon(Icons.edit_location_alt_rounded)),
                ],
              ),
            ],
          ),
        );
      case 'coordinate_list':
        final list = (_values[key] as List).cast<Map<String, dynamic>>();
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: Icons.share_location_rounded, title: title),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Nenhum ponto adicionado.'))
              else
                ...list.asMap().entries.map((entry) {
                  final point = entry.value;
                  final zona = point['zona_utm'];
                  final alt = point['altitude'];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(radius: 14, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 12))),
                    title: Text('${_asDouble(point['latitude'])?.toStringAsFixed(6)}, ${_asDouble(point['longitude'])?.toStringAsFixed(6)}'),
                    subtitle: Text([if (zona != null) 'Zona $zona', if (alt != null) 'Alt ${alt}m'].join(' - ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => setState(() => list.removeAt(entry.key)),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _addCoordinatePoint(key, field),
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Adicionar ponto (GPS)'),
              ),
            ],
          ),
        );
      case 'photo':
        if (_multiplePhotos(field)) {
          final paths = (_values[key] as List).cast<String>();
          return PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(icon: Icons.collections_rounded, title: title),
                const SizedBox(height: 8),
                ...paths.asMap().entries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.photo_rounded, color: Color(0xFF0A7354)),
                        title: Text(p.basename(entry.value), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => setState(() => paths.removeAt(entry.key)),
                        ),
                      ),
                    ),
                FilledButton.icon(
                  onPressed: () async {
                    final path = await _pickPhoto();
                    if (path != null) setState(() => paths.add(path));
                  },
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: const Text('Adicionar foto'),
                ),
              ],
            ),
          );
        }
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(icon: Icons.camera_alt_rounded, title: title),
              const SizedBox(height: 12),
              PhotoButton(
                label: label,
                path: _values[key] as String?,
                onPressed: () async {
                  final path = await _pickPhoto();
                  if (path != null) setState(() => _values[key] = path);
                },
              ),
            ],
          ),
        );
      default:
        return PremiumCard(child: TextField(controller: _text[key], decoration: InputDecoration(labelText: title)));
    }
  }
}

