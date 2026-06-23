import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../app/theme.dart';
import '../core/photo_capture_service.dart';
import '../core/providers.dart';
import '../models/poco_teste_choices.dart';
import '../models/poco_teste_form.dart';
import '../models/poco_teste_level.dart';
import '../models/poco_teste_payload_mapper.dart';
import '../models/poco_teste_photo.dart';
import '../models/poco_teste_validator.dart';
import '../widgets/app_widgets.dart';
import '../widgets/forms/brandt_geopoint_field.dart';
import '../widgets/forms/brandt_multi_select_field.dart';
import '../widgets/forms/brandt_photo_field.dart';
import '../widgets/forms/brandt_select_field.dart';
import '../widgets/forms/brandt_text_field.dart';
import '../widgets/forms/poco_teste_level_card.dart';

/// Native implementation of the "Poço teste" XLSForm, organized as pages:
/// Cabeçalho, Superfície, Níveis and Revisão.
class PocoTesteFormScreen extends ConsumerStatefulWidget {
  const PocoTesteFormScreen({
    super.key,
    required this.project,
    required this.form,
    this.existingPayload,
  });

  final Map<String, dynamic> project;
  final Map<String, dynamic> form;

  /// Existing collection payload when reopening a draft for editing.
  final Map<String, dynamic>? existingPayload;

  @override
  ConsumerState<PocoTesteFormScreen> createState() =>
      _PocoTesteFormScreenState();
}

class _PocoTesteFormScreenState extends ConsumerState<PocoTesteFormScreen> {
  static const _sections = ['Cabeçalho', 'Superfície', 'Níveis', 'Revisão'];

  final _pageController = PageController();
  final _capture = PhotoCaptureService();
  final _validator = const PocoTesteValidator();

  late PocoTesteFormState _state;
  final _expandedLevels = <String>{};
  int _page = 0;
  ValidationResult? _result;
  String? _banner;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPayload != null) {
      _state = PocoTestePayloadMapper.fromPayload(widget.existingPayload!);
    } else {
      _state = PocoTesteFormState(
        localUuid: const Uuid().v4(),
        createdAt: DateTime.now().toIso8601String(),
        header: PocoTesteHeader(data4: DateTime.now().toIso8601String()),
        surface: const PocoTesteSurface(),
        levels: [PocoTesteLevel()],
      );
    }
    if (_state.levels.isNotEmpty) {
      _expandedLevels.add(_state.levels.first.id);
    }
    unawaited(_prefillResponsavel());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _prefillResponsavel() async {
    if (_state.header.responsavel.trim().isNotEmpty) return;
    final user = await ref.read(storeProvider).user();
    final name = (user?['name'] ?? user?['full_name'] ?? '') as String;
    if (name.isEmpty || !mounted) return;
    setState(
      () => _state = _state.copyWith(
        header: _state.header.copyWith(responsavel: name),
      ),
    );
  }

  // ---- State helpers ----

  void _setHeader(PocoTesteHeader header) =>
      setState(() => _state = _state.copyWith(header: header));

  void _setSurface(PocoTesteSurface surface) =>
      setState(() => _state = _state.copyWith(surface: surface));

  void _updateLevel(int index, PocoTesteLevel level) {
    final levels = List<PocoTesteLevel>.from(_state.levels);
    levels[index] = level;
    setState(() => _state = _state.copyWith(levels: levels));
  }

  void _addLevel() {
    final level = PocoTesteLevel();
    final levels = List<PocoTesteLevel>.from(_state.levels)..add(level);
    setState(() {
      _state = _state.copyWith(levels: levels);
      _expandedLevels
        ..clear()
        ..add(level.id);
    });
  }

  Future<void> _removeLevel(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover nível'),
        content: Text('Deseja remover o Nível ${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final levels = List<PocoTesteLevel>.from(_state.levels)..removeAt(index);
    setState(() => _state = _state.copyWith(levels: levels));
  }

  // ---- GPS ----

  Future<void> _captureGps() async {
    setState(() => _banner = null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _banner = 'Permissão de localização negada.');
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final geo = _state.header.coordenada;
    _setHeader(
      _state.header.copyWith(
        coordenada: geo.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          originalLatitude: geo.originalLatitude ?? position.latitude,
          originalLongitude: geo.originalLongitude ?? position.longitude,
          capturedAt: DateTime.now().toIso8601String(),
        ),
      ),
    );
  }

  Future<void> _manualCoordinate() async {
    final geo = _state.header.coordenada;
    final lat = TextEditingController(
      text: geo.latitude?.toStringAsFixed(7) ?? '',
    );
    final lng = TextEditingController(
      text: geo.longitude?.toStringAsFixed(7) ?? '',
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lng,
              decoration: const InputDecoration(labelText: 'Longitude'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
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
      final newLat = double.tryParse(lat.text.replaceAll(',', '.'));
      final newLng = double.tryParse(lng.text.replaceAll(',', '.'));
      _setHeader(
        _state.header.copyWith(
          coordenada: geo.copyWith(
            latitude: newLat,
            longitude: newLng,
            coordinateWasEdited: true,
            originalLatitude: geo.originalLatitude ?? geo.latitude,
            originalLongitude: geo.originalLongitude ?? geo.longitude,
          ),
        ),
      );
    }
  }

  Future<PocoTestePhoto?> _capturePhoto(
    String type, {
    String? fieldName,
    int? levelIndex,
  }) {
    return _capture.capture(
      type: type,
      fieldName: fieldName ?? type,
      levelIndex: levelIndex,
      geo: _state.header.coordenada,
    );
  }

  // ---- Error lookups ----

  String? _headerErr(String field) => _errorFor('cabecalho', field);
  String? _surfaceErr(String field) => _errorFor('superficie', field);

  String? _errorFor(String section, String field) {
    final errors = _result?.errors ?? const [];
    for (final e in errors) {
      if (e.section == section && e.field == field) return e.message;
    }
    return null;
  }

  Map<String, String> _levelErrors(int position) {
    final prefix = 'nivel_${position}_';
    final map = <String, String>{};
    for (final e in _result?.errors ?? const []) {
      if (e.section == 'nivel' && e.field.startsWith(prefix)) {
        map[e.field.substring(prefix.length)] = e.message;
      }
    }
    return map;
  }

  // ---- Save ----

  Future<void> _saveDraft() async {
    await _persist('draft');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rascunho salvo no histórico.')),
    );
    context.go('/home');
  }

  Future<void> _finalize() async {
    final result = _validator.validateForFinalize(_state);
    if (!result.isValid) {
      setState(() {
        _result = result;
        _banner =
            'Existem ${result.errors.length} campo(s) obrigatório(s) pendente(s).';
      });
      _jumpToFirstError(result.first!);
      return;
    }
    await _persist('pending_sync');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coleta finalizada e enviada à caixa de saída.'),
      ),
    );
    context.go('/home');
  }

  Future<void> _persist(String status) async {
    setState(() => _saving = true);
    try {
      _state = _state.copyWith(status: status);
      final payload = PocoTestePayloadMapper.toPayload(
        state: _state,
        project: widget.project,
        form: widget.form,
      );
      await ref.read(storeProvider).saveCollection(payload);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _jumpToFirstError(ValidationError error) {
    final target = switch (error.section) {
      'cabecalho' => 0,
      'superficie' => 1,
      _ => 2,
    };
    _goToPage(target);
    if (error.section == 'nivel' && error.levelIndex != null) {
      final idx = error.levelIndex! - 1;
      if (idx >= 0 && idx < _state.levels.length) {
        setState(() {
          _expandedLevels
            ..clear()
            ..add(_state.levels[idx].id);
        });
      }
    }
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Poço teste')),
      body: Column(
        children: [
          _progress(),
          if (_banner != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: StatusBanner(
                icon: Icons.error_outline_rounded,
                text: _banner!,
                tone: BannerTone.error,
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _page = page),
              children: [
                _headerPage(),
                _surfacePage(),
                _levelsPage(),
                _reviewPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _progress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(_sections.length, (i) {
          final active = i <= _page;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? brandtGreen : borderSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sections[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == _page
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: active ? brandtGreen : textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _bottomBar() {
    final isLast = _page == _sections.length - 1;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (_page > 0)
            OutlinedButton(
              onPressed: _saving ? null : () => _goToPage(_page - 1),
              child: const Text('Voltar'),
            ),
          if (_page > 0) const SizedBox(width: 10),
          Expanded(
            child: isLast
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _saveDraft,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Rascunho'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _finalize,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Finalizar'),
                        ),
                      ),
                    ],
                  )
                : FilledButton.icon(
                    onPressed: _saving ? null : () => _goToPage(_page + 1),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Avançar'),
                  ),
          ),
        ],
      ),
    );
  }

  // ---- Pages ----

  Widget _headerPage() {
    final h = _state.header;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PremiumHeader(
          icon: Icons.assignment_rounded,
          title: 'Cabeçalho',
          subtitle: widget.project['name'] as String? ?? 'Poço teste',
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded, color: brandtGreen),
                title: const Text('Data'),
                subtitle: Text(_formatDateTime(h.data4)),
                trailing: const Icon(Icons.lock_outline_rounded, size: 18),
              ),
              const SizedBox(height: 8),
              _readonlyField(
                'Projeto',
                widget.project['name'] as String? ?? '-',
              ),
              const SizedBox(height: 14),
              BrandtTextField(
                label: 'Município',
                initialValue: h.municipio,
                errorText: _headerErr('municipio'),
                onChanged: (v) => _setHeader(h.copyWith(municipio: v)),
              ),
              const SizedBox(height: 14),
              BrandtTextField(
                label: 'Sítio',
                initialValue: h.sitio,
                errorText: _headerErr('sitio'),
                onChanged: (v) => _setHeader(h.copyWith(sitio: v)),
              ),
              const SizedBox(height: 14),
              BrandtTextField(
                label: 'Nome do ponto',
                initialValue: h.ponto,
                errorText: _headerErr('ponto'),
                onChanged: (v) => _setHeader(h.copyWith(ponto: v)),
              ),
              const SizedBox(height: 14),
              BrandtTextField(
                label: 'Coordenadas UTM',
                initialValue: h.coordenadasUtm,
                onChanged: (v) => _setHeader(h.copyWith(coordenadasUtm: v)),
              ),
              const SizedBox(height: 14),
              BrandtTextField(
                label: 'Arqueólogo(a)',
                initialValue: h.responsavel,
                errorText: _headerErr('responsavel'),
                onChanged: (v) => _setHeader(h.copyWith(responsavel: v)),
              ),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(
                icon: Icons.gps_fixed_rounded,
                title: 'Coordenadas (GPS)',
              ),
              const SizedBox(height: 12),
              BrandtGeopointField(
                geo: h.coordenada,
                errorText: _headerErr('coordenada'),
                onCapture: _captureGps,
                onManualEdit: _manualCoordinate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _surfacePage() {
    final s = _state.surface;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PremiumHeader(
          icon: Icons.landscape_rounded,
          title: 'Superfície',
          subtitle: 'Registro da superfície do ponto.',
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: BrandtPhotoField(
            label: 'Foto da Superfície',
            photo: s.fotoSuperficie,
            errorText: _surfaceErr('foto_superficie'),
            onCapture: () async {
              final photo = await _capturePhoto('foto_superficie');
              if (photo != null) _setSurface(s.copyWith(fotoSuperficie: photo));
            },
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandtMultiSelectField(
                label: 'Cobertura vegetal',
                choices: PocoTesteChoices.coberturaVegetacional,
                selected: s.coberturaVegetacional,
                onToggle: (value) => _setSurface(
                  s.copyWith(
                    coberturaVegetacional: _toggle(
                      s.coberturaVegetacional,
                      value,
                    ),
                  ),
                ),
              ),
              if (s.showOutroCobertura) ...[
                const SizedBox(height: 14),
                BrandtTextField(
                  label: 'Outro',
                  initialValue: s.outroCobertura,
                  errorText: _surfaceErr('outro_cobertura'),
                  onChanged: (v) => _setSurface(s.copyWith(outroCobertura: v)),
                ),
              ],
              const SizedBox(height: 14),
              BrandtSelectField(
                label: 'Solo (Ordem/Paisagem)',
                choices: PocoTesteChoices.solo,
                value: s.solo,
                onChanged: (v) => _setSurface(s.copyWith(solo: v)),
              ),
              if (s.showOutroSolo) ...[
                const SizedBox(height: 14),
                BrandtTextField(
                  label: 'Outro',
                  initialValue: s.outroSolo,
                  errorText: _surfaceErr('outro_solo'),
                  onChanged: (v) => _setSurface(s.copyWith(outroSolo: v)),
                ),
              ],
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandtSelectField(
                label: 'Presença/Ausência de material/estrutura arqueológico',
                choices: PocoTesteChoices.materialArqueologicoPresenca,
                value: s.materialPresenca,
                errorText: _surfaceErr('material_presenca'),
                onChanged: (v) => _setSurface(s.copyWith(materialPresenca: v)),
              ),
              if (s.hasMaterial) ...[
                const SizedBox(height: 14),
                BrandtMultiSelectField(
                  label: 'Histórico',
                  choices: PocoTesteChoices.historico,
                  selected: s.historico,
                  errorText: _surfaceErr('material'),
                  onToggle: (value) => _setSurface(
                    s.copyWith(historico: _toggle(s.historico, value)),
                  ),
                ),
                if (s.showOutroHistorico) ...[
                  const SizedBox(height: 14),
                  BrandtTextField(
                    label: 'Histórico - outros',
                    initialValue: s.outroHistorico,
                    errorText: _surfaceErr('outro_historico'),
                    onChanged: (v) =>
                        _setSurface(s.copyWith(outroHistorico: v)),
                  ),
                ],
                const SizedBox(height: 14),
                BrandtMultiSelectField(
                  label: 'Pré-colonial',
                  choices: PocoTesteChoices.preColonial,
                  selected: s.preColonial,
                  onToggle: (value) => _setSurface(
                    s.copyWith(preColonial: _toggle(s.preColonial, value)),
                  ),
                ),
                if (s.showOutroPreColonial) ...[
                  const SizedBox(height: 14),
                  BrandtTextField(
                    label: 'Pré-colonial - outros',
                    initialValue: s.outroPreColonial,
                    errorText: _surfaceErr('outro_pre_colonial'),
                    onChanged: (v) =>
                        _setSurface(s.copyWith(outroPreColonial: v)),
                  ),
                ],
                const SizedBox(height: 14),
                BrandtPhotoField(
                  label: 'Foto do material/estrutura arqueológico',
                  photo: s.fotoMaterial,
                  errorText: _surfaceErr('foto_material'),
                  onCapture: () async {
                    final photo = await _capturePhoto(
                      'foto_material_superficie',
                    );
                    if (photo != null) {
                      _setSurface(s.copyWith(fotoMaterial: photo));
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _levelsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PremiumHeader(
          icon: Icons.layers_rounded,
          title: 'Níveis / Características',
          subtitle:
              'Um nível é caracterizado por textura, compactação, coloração e '
              'umidade. Se algum mudar durante a perfuração, registre um novo nível.',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _state.levels.length; i++)
          PocoTesteLevelCard(
            key: ValueKey(_state.levels[i].id),
            level: _state.levels[i],
            position: i + 1,
            expanded: _expandedLevels.contains(_state.levels[i].id),
            errors: _levelErrors(i + 1),
            onChanged: (level) => _updateLevel(i, level),
            onToggleExpand: () => setState(() {
              final id = _state.levels[i].id;
              if (!_expandedLevels.remove(id)) _expandedLevels.add(id);
            }),
            onRemove: _state.levels.length > 1 ? () => _removeLevel(i) : null,
            capturePhoto: (type) =>
                _capturePhoto(type, fieldName: type, levelIndex: i + 1),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addLevel,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar nível'),
        ),
      ],
    );
  }

  Widget _reviewPage() {
    final h = _state.header;
    final positivePit = _state.levels.any((l) => l.positivo == 'sim');
    final suggestsAnother = _validator.lastLevelSuggestsAnother(_state);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PremiumHeader(
          icon: Icons.fact_check_rounded,
          title: 'Revisão',
          subtitle: 'Confira os dados antes de finalizar.',
        ),
        const SizedBox(height: 16),
        if (suggestsAnother) ...[
          const StatusBanner(
            icon: Icons.info_outline_rounded,
            text:
                'O último nível indica "alteração de camada". Considere adicionar outro nível.',
            tone: BannerTone.warning,
          ),
          const SizedBox(height: 12),
        ],
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow('Projeto', widget.project['name'] as String? ?? '-'),
              _reviewRow('Município', _orDash(h.municipio)),
              _reviewRow('Sítio', _orDash(h.sitio)),
              _reviewRow('Ponto', _orDash(h.ponto)),
              _reviewRow(
                'Coordenada',
                h.coordenada.hasValue
                    ? '${h.coordenada.latitude!.toStringAsFixed(6)}, ${h.coordenada.longitude!.toStringAsFixed(6)}'
                    : 'Não capturada',
              ),
              _reviewRow('Responsável', _orDash(h.responsavel)),
              _reviewRow('Níveis', '${_state.levels.length}'),
              _reviewRow('Poço positivo', positivePit ? 'Sim' : 'Não'),
            ],
          ),
        ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                icon: Icons.info_outline_rounded,
                title: 'Como salvar',
              ),
              const SizedBox(height: 8),
              const Text(
                'Salvar rascunho mantém a coleta incompleta no histórico para '
                'continuar depois. Finalizar valida todos os campos obrigatórios '
                'e envia a coleta para a caixa de saída.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Small UI helpers ----

  Widget _readonlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
      ),
      child: Text(value),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<String> _toggle(List<String> current, String value) {
    final next = List<String>.from(current);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }

  String _orDash(String value) => value.trim().isEmpty ? '-' : value.trim();

  String _formatDateTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }
}
