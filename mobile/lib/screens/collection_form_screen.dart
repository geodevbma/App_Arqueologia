import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/providers.dart';
import '../widgets/app_widgets.dart';

class CollectionFormScreen extends ConsumerStatefulWidget {
  const CollectionFormScreen({
    super.key,
    required this.project,
    required this.form,
  });

  final Map<String, dynamic> project;
  final Map<String, dynamic> form;

  @override
  ConsumerState<CollectionFormScreen> createState() =>
      _CollectionFormScreenState();
}

class _CollectionFormScreenState extends ConsumerState<CollectionFormScreen> {
  final description = TextEditingController();
  final otherPoint = TextEditingController();
  final vestigeDetail = TextEditingController();
  final issueDetail = TextEditingController();
  DateTime collectionDate = DateTime.now();
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> points = [];
  String? sectionId;
  String? pointId;
  bool pointOther = false;
  bool vestige = false;
  bool issue = false;
  double? latitude;
  double? longitude;
  double? accuracy;
  double? originalLatitude;
  double? originalLongitude;
  bool coordinateEdited = false;
  String? activityPhoto;
  String? landscapePhoto;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    description.dispose();
    otherPoint.dispose();
    vestigeDetail.dispose();
    issueDetail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loadedSections = await ref
        .read(storeProvider)
        .sectionsForProject(widget.project['id'] as String);
    final loadedPoints = loadedSections.isEmpty
        ? <Map<String, dynamic>>[]
        : await ref
              .read(storeProvider)
              .pointsForSection(loadedSections.first['id'] as String);
    setState(() {
      sections = loadedSections;
      sectionId = loadedSections.isEmpty
          ? null
          : loadedSections.first['id'] as String;
      points = loadedPoints;
      loading = false;
    });
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

  Future<void> _captureGps() async {
    setState(() => error = null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => error = 'Permissao de localizacao negada.');
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
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
    final lng = TextEditingController(
      text: longitude?.toStringAsFixed(7) ?? '',
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Editar coordenada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lat,
              decoration: const InputDecoration(labelText: 'Latitude'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lng,
              decoration: const InputDecoration(labelText: 'Longitude'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar coordenada'),
            ),
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

  Future<void> _photo(String type) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 74,
      maxWidth: 1600,
    );
    if (image == null) return;
    setState(() {
      if (type == 'activity_photo') {
        activityPhoto = image.path;
      } else {
        landscapePhoto = image.path;
      }
    });
  }

  String? _validate() {
    if (sectionId == null) return 'Selecione um trecho.';
    if (!pointOther && pointId == null) return 'Selecione obra/ponto.';
    if (pointOther && otherPoint.text.trim().isEmpty) {
      return 'Informe qual ponto em Outro.';
    }
    if (latitude == null || longitude == null) {
      return 'Capture ou edite a coordenada.';
    }
    if (activityPhoto == null) return 'Foto da atividade e obrigatoria.';
    if (landscapePhoto == null) return 'Foto da paisagem e obrigatoria.';
    if (description.text.trim().isEmpty) {
      return 'Descricao da atividade e obrigatoria.';
    }
    if (vestige && vestigeDetail.text.trim().isEmpty) {
      return 'Informe qual vestigio foi identificado.';
    }
    if (issue && issueDetail.text.trim().isEmpty) {
      return 'Informe qual intercorrencia ocorreu.';
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    final user = await ref.read(storeProvider).user();
    final now = DateTime.now().toIso8601String();
    final localUuid = const Uuid().v4();
    final payload = {
      'local_uuid': localUuid,
      'project_id': widget.project['id'],
      'form_id': widget.form['id'],
      'form_version': widget.form['current_version'] ?? 1,
      'section_id': sectionId,
      'work_point_id': pointOther ? null : pointId,
      'work_point_other': pointOther ? otherPoint.text.trim() : null,
      'collection_date': DateFormat('yyyy-MM-dd').format(collectionDate),
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': accuracy,
      'original_latitude': originalLatitude,
      'original_longitude': originalLongitude,
      'coordinate_was_edited': coordinateEdited,
      'status': 'pending_sync',
      'sync_status': 'pending_sync',
      'created_locally_at': now,
      'updated_locally_at': now,
      'answers': [
        {
          'field_key': 'archaeologist_name',
          'answer_value': user?['name'] ?? '',
        },
        {
          'field_key': 'activity_description',
          'answer_value': description.text.trim(),
        },
        {'field_key': 'vestigio_identificado', 'answer_value': vestige},
        {
          'field_key': 'qual_vestigio',
          'answer_value': vestige ? vestigeDetail.text.trim() : '',
        },
        {'field_key': 'intercorrencia_identificada', 'answer_value': issue},
        {
          'field_key': 'qual_intercorrencia',
          'answer_value': issue ? issueDetail.text.trim() : '',
        },
      ],
      'photos': [
        {
          'photo_type': 'activity_photo',
          'file_path': activityPhoto,
          'original_filename': p.basename(activityPhoto!),
          'latitude': latitude,
          'longitude': longitude,
          'taken_at': now,
          'metadata': {
            'project': widget.project['name'],
            'form': widget.form['name'],
          },
        },
        {
          'photo_type': 'landscape_photo',
          'file_path': landscapePhoto,
          'original_filename': p.basename(landscapePhoto!),
          'latitude': latitude,
          'longitude': longitude,
          'taken_at': now,
          'metadata': {
            'project': widget.project['name'],
            'form': widget.form['name'],
          },
        },
      ],
    };
    await ref.read(storeProvider).saveCollection(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coleta salva na caixa de saida.')),
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Nova coleta')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar rascunho'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Finalizar coleta'),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumHeader(
            icon: Icons.assignment_turned_in_rounded,
            title: widget.form['name'] as String,
            subtitle: widget.project['name'] as String,
          ),
          const SizedBox(height: 18),
          if (error != null) ...[
            StatusBanner(
              icon: Icons.error_outline_rounded,
              text: error!,
              tone: BannerTone.error,
            ),
            const SizedBox(height: 12),
          ],
          PremiumCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: sectionId,
                  decoration: const InputDecoration(labelText: 'Trecho'),
                  items: sections
                      .map(
                        (section) => DropdownMenuItem(
                          value: section['id'] as String,
                          child: Text(section['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      value == null ? null : _changeSection(value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: pointOther ? 'other' : pointId,
                  decoration: const InputDecoration(labelText: 'Obra/Ponto'),
                  items: [
                    ...points.map(
                      (point) => DropdownMenuItem(
                        value: point['id'] as String,
                        child: Text(point['name'] as String),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'other',
                      child: Text('Outro'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    pointOther = value == 'other';
                    pointId = pointOther ? null : value;
                  }),
                ),
                AnimatedSwitcher(
                  duration: 220.ms,
                  child: pointOther
                      ? Padding(
                          key: const ValueKey('other-point'),
                          padding: const EdgeInsets.only(top: 12),
                          child: TextField(
                            controller: otherPoint,
                            decoration: const InputDecoration(
                              labelText: 'Qual?',
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data da coleta'),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy').format(collectionDate),
                  ),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: collectionDate,
                    );
                    if (selected != null) {
                      setState(() => collectionDate = selected);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(
                  icon: Icons.gps_fixed_rounded,
                  title: 'Ponto georreferenciado',
                ),
                const SizedBox(height: 12),
                StatusBanner(
                  icon: latitude == null
                      ? Icons.location_searching_rounded
                      : Icons.my_location_rounded,
                  text: latitude == null
                      ? 'Coordenada ainda nao capturada'
                      : '${latitude!.toStringAsFixed(7)}, ${longitude!.toStringAsFixed(7)} - precisao ${accuracy?.toStringAsFixed(1) ?? '-'} m',
                  tone: latitude == null
                      ? BannerTone.warning
                      : BannerTone.success,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _captureGps,
                        icon: const Icon(Icons.gps_fixed_rounded),
                        label: const Text('Capturar GPS'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _manualCoordinate,
                      icon: const Icon(Icons.edit_location_alt_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(
                  icon: Icons.camera_alt_rounded,
                  title: 'Fotos obrigatorias',
                ),
                const SizedBox(height: 12),
                PhotoButton(
                  label: 'Foto da atividade',
                  path: activityPhoto,
                  onPressed: () => _photo('activity_photo'),
                ),
                const SizedBox(height: 10),
                PhotoButton(
                  label: 'Foto da paisagem',
                  path: landscapePhoto,
                  onPressed: () => _photo('landscape_photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(
              children: [
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Descricao da atividade',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: vestige,
                  onChanged: (value) => setState(() => vestige = value),
                  title: const Text(
                    'Foi identificado algum vestigio arqueologico?',
                  ),
                ),
                AnimatedSwitcher(
                  duration: 220.ms,
                  child: vestige
                      ? TextField(
                          key: const ValueKey('vestige'),
                          controller: vestigeDetail,
                          decoration: const InputDecoration(
                            labelText: 'Qual vestigio?',
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: issue,
                  onChanged: (value) => setState(() => issue = value),
                  title: const Text('Houve alguma intercorrencia?'),
                ),
                AnimatedSwitcher(
                  duration: 220.ms,
                  child: issue
                      ? TextField(
                          key: const ValueKey('issue'),
                          controller: issueDetail,
                          decoration: const InputDecoration(
                            labelText: 'Qual intercorrencia?',
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
