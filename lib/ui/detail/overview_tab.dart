import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/services/config_ini.dart';
import 'package:flutter/material.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({
    super.key,
    required this.avd,
    required this.onSave,
    required this.onStopAndSave,
  });
  final Avd avd;
  final Future<void> Function(Map<String, String>) onSave;
  final Future<void> Function(Map<String, String>) onStopAndSave;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  late final TextEditingController ramCtrl;
  late final TextEditingController heapCtrl;
  late final TextEditingController dataSizeCtrl;
  late final TextEditingController sdSizeCtrl;
  late final TextEditingController lcdWidthCtrl;
  late final TextEditingController lcdHeightCtrl;
  late final TextEditingController lcdDensityCtrl;

  SizeUnit dataUnit = SizeUnit.m;
  SizeUnit sdUnit = SizeUnit.m;

  bool gpuEnabled = true;
  String gpuMode = 'auto';
  bool keyboardEnabled = true;
  bool showDeviceFrame = false;
  String cameraFront = 'none';
  String cameraBack = 'none';
  String networkSpeed = 'full';
  String networkLatency = 'none';
  bool dirty = false;

  static const List<String> _gpuModes = <String>[
    'auto',
    'host',
    'swiftshader_indirect',
    'off',
  ];
  static const List<String> _cameraModes = <String>[
    'none',
    'emulated',
    'webcam0',
  ];
  static const List<String> _networkSpeeds = <String>[
    'full',
    'gsm',
    'hscsd',
    'gprs',
    'edge',
    'umts',
    'hsdpa',
    'lte',
    'evdo',
  ];
  static const List<String> _networkLatencies = <String>[
    'none',
    'gprs',
    'edge',
    'umts',
  ];

  @override
  void initState() {
    super.initState();
    ramCtrl = TextEditingController(
      text: widget.avd.config['hw.ramSize'] ?? '',
    );
    heapCtrl = TextEditingController(
      text: widget.avd.config['vm.heapSize'] ?? '',
    );
    lcdWidthCtrl = TextEditingController(
      text: widget.avd.config['hw.lcd.width'] ?? '',
    );
    lcdHeightCtrl = TextEditingController(
      text: widget.avd.config['hw.lcd.height'] ?? '',
    );
    lcdDensityCtrl = TextEditingController(
      text: widget.avd.config['hw.lcd.density'] ?? '',
    );
    final ConfigIni cfg = ConfigIni.parse(
      widget.avd.config.entries.map((e) => '${e.key}=${e.value}').join('\n'),
    );
    final SizeValue? data = cfg.getSize('disk.dataPartition.size');
    final SizeValue? sd = cfg.getSize('sdcard.size');
    dataSizeCtrl = TextEditingController(text: data?.value.toString() ?? '');
    sdSizeCtrl = TextEditingController(text: sd?.value.toString() ?? '');
    dataUnit = data?.unit ?? SizeUnit.m;
    sdUnit = sd?.unit ?? SizeUnit.m;

    gpuEnabled = (widget.avd.config['hw.gpu.enabled'] ?? 'yes') == 'yes';
    gpuMode = _validOrDefault(
      _gpuModes,
      widget.avd.config['hw.gpu.mode'],
      'auto',
    );
    keyboardEnabled = (widget.avd.config['hw.keyboard'] ?? 'yes') == 'yes';
    showDeviceFrame = (widget.avd.config['showDeviceFrame'] ?? 'no') == 'yes';
    cameraFront = _validOrDefault(
      _cameraModes,
      widget.avd.config['hw.camera.front'],
      'none',
    );
    cameraBack = _validOrDefault(
      _cameraModes,
      widget.avd.config['hw.camera.back'],
      'none',
    );
    networkSpeed = _validOrDefault(
      _networkSpeeds,
      widget.avd.config['runtime.network.speed'],
      'full',
    );
    networkLatency = _validOrDefault(
      _networkLatencies,
      widget.avd.config['runtime.network.latency'],
      'none',
    );

    for (final ctrl in <TextEditingController>[
      ramCtrl,
      heapCtrl,
      dataSizeCtrl,
      sdSizeCtrl,
      lcdWidthCtrl,
      lcdHeightCtrl,
      lcdDensityCtrl,
    ]) {
      ctrl.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!dirty) {
      setState(() => dirty = true);
    }
  }

  @override
  void dispose() {
    ramCtrl.dispose();
    heapCtrl.dispose();
    dataSizeCtrl.dispose();
    sdSizeCtrl.dispose();
    lcdWidthCtrl.dispose();
    lcdHeightCtrl.dispose();
    lcdDensityCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _changes() {
    final map = <String, String>{...widget.avd.config};
    map['hw.ramSize'] = ramCtrl.text.trim();
    map['vm.heapSize'] = heapCtrl.text.trim();
    map['disk.dataPartition.size'] =
        '${dataSizeCtrl.text.trim()}${dataUnit.name.toUpperCase()}';
    map['sdcard.size'] =
        '${sdSizeCtrl.text.trim()}${sdUnit.name.toUpperCase()}';

    map['hw.lcd.width'] = lcdWidthCtrl.text.trim();
    map['hw.lcd.height'] = lcdHeightCtrl.text.trim();
    map['hw.lcd.density'] = lcdDensityCtrl.text.trim();

    map['hw.gpu.enabled'] = gpuEnabled ? 'yes' : 'no';
    map['hw.gpu.mode'] = gpuMode;
    map['hw.keyboard'] = keyboardEnabled ? 'yes' : 'no';
    map['showDeviceFrame'] = showDeviceFrame ? 'yes' : 'no';
    map['hw.camera.front'] = cameraFront;
    map['hw.camera.back'] = cameraBack;
    map['runtime.network.speed'] = networkSpeed;
    map['runtime.network.latency'] = networkLatency;
    return map;
  }

  void _discard() {
    setState(() {
      ramCtrl.text = widget.avd.config['hw.ramSize'] ?? '';
      heapCtrl.text = widget.avd.config['vm.heapSize'] ?? '';
      lcdWidthCtrl.text = widget.avd.config['hw.lcd.width'] ?? '';
      lcdHeightCtrl.text = widget.avd.config['hw.lcd.height'] ?? '';
      lcdDensityCtrl.text = widget.avd.config['hw.lcd.density'] ?? '';

      final cfg = ConfigIni.parse(
        widget.avd.config.entries.map((e) => '${e.key}=${e.value}').join('\n'),
      );
      final data = cfg.getSize('disk.dataPartition.size');
      final sd = cfg.getSize('sdcard.size');
      dataSizeCtrl.text = data?.value.toString() ?? '';
      sdSizeCtrl.text = sd?.value.toString() ?? '';
      dataUnit = data?.unit ?? SizeUnit.m;
      sdUnit = sd?.unit ?? SizeUnit.m;

      gpuEnabled = (widget.avd.config['hw.gpu.enabled'] ?? 'yes') == 'yes';
      gpuMode = _validOrDefault(
        _gpuModes,
        widget.avd.config['hw.gpu.mode'],
        'auto',
      );
      keyboardEnabled = (widget.avd.config['hw.keyboard'] ?? 'yes') == 'yes';
      showDeviceFrame = (widget.avd.config['showDeviceFrame'] ?? 'no') == 'yes';
      cameraFront = _validOrDefault(
        _cameraModes,
        widget.avd.config['hw.camera.front'],
        'none',
      );
      cameraBack = _validOrDefault(
        _cameraModes,
        widget.avd.config['hw.camera.back'],
        'none',
      );
      networkSpeed = _validOrDefault(
        _networkSpeeds,
        widget.avd.config['runtime.network.speed'],
        'full',
      );
      networkLatency = _validOrDefault(
        _networkLatencies,
        widget.avd.config['runtime.network.latency'],
        'none',
      );
      dirty = false;
    });
  }

  String _validOrDefault(List<String> options, String? value, String fallback) {
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return options.contains(value) ? value : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final bool editable = widget.avd.state.editable;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: <Widget>[
              _SectionCard(
                title: 'General',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        enabled: editable,
                        controller: ramCtrl,
                        decoration: const InputDecoration(
                          labelText: 'RAM (MB)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        enabled: editable,
                        controller: heapCtrl,
                        decoration: const InputDecoration(
                          labelText: 'VM heap (MB)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Display',
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            enabled: editable,
                            controller: lcdWidthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Width',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            enabled: editable,
                            controller: lcdHeightCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Height',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            enabled: editable,
                            controller: lcdDensityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Density',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: showDeviceFrame,
                      onChanged: editable
                          ? (v) => setState(() {
                              showDeviceFrame = v;
                              dirty = true;
                            })
                          : null,
                      title: const Text('Show device frame'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Storage',
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            enabled: editable,
                            controller: dataSizeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Data partition',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<SizeUnit>(
                          value: dataUnit,
                          onChanged: editable
                              ? (v) => setState(() {
                                  dataUnit = v!;
                                  dirty = true;
                                })
                              : null,
                          items: SizeUnit.values
                              .map(
                                (e) => DropdownMenuItem<SizeUnit>(
                                  value: e,
                                  child: Text(e.name.toUpperCase()),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            enabled: editable,
                            controller: sdSizeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'SD card',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<SizeUnit>(
                          value: sdUnit,
                          onChanged: editable
                              ? (v) => setState(() {
                                  sdUnit = v!;
                                  dirty = true;
                                })
                              : null,
                          items: SizeUnit.values
                              .map(
                                (e) => DropdownMenuItem<SizeUnit>(
                                  value: e,
                                  child: Text(e.name.toUpperCase()),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Input and GPU',
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: gpuMode,
                            decoration: const InputDecoration(
                              labelText: 'GPU mode',
                            ),
                            onChanged: editable
                                ? (v) => setState(() {
                                    gpuMode = v ?? 'auto';
                                    dirty = true;
                                  })
                                : null,
                            items: _gpuModes
                                .map(
                                  (v) => DropdownMenuItem<String>(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SwitchListTile(
                            value: gpuEnabled,
                            onChanged: editable
                                ? (v) => setState(() {
                                    gpuEnabled = v;
                                    dirty = true;
                                  })
                                : null,
                            title: const Text('GPU enabled'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SwitchListTile(
                            value: keyboardEnabled,
                            onChanged: editable
                                ? (v) => setState(() {
                                    keyboardEnabled = v;
                                    dirty = true;
                                  })
                                : null,
                            title: const Text('Hardware keyboard'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: cameraFront,
                            decoration: const InputDecoration(
                              labelText: 'Front camera',
                            ),
                            onChanged: editable
                                ? (v) => setState(() {
                                    cameraFront = v ?? 'none';
                                    dirty = true;
                                  })
                                : null,
                            items: _cameraModes
                                .map(
                                  (v) => DropdownMenuItem<String>(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: cameraBack,
                            decoration: const InputDecoration(
                              labelText: 'Back camera',
                            ),
                            onChanged: editable
                                ? (v) => setState(() {
                                    cameraBack = v ?? 'none';
                                    dirty = true;
                                  })
                                : null,
                            items: _cameraModes
                                .map(
                                  (v) => DropdownMenuItem<String>(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'Network',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: networkSpeed,
                        decoration: const InputDecoration(labelText: 'Speed'),
                        onChanged: editable
                            ? (v) => setState(() {
                                networkSpeed = v ?? 'full';
                                dirty = true;
                              })
                            : null,
                        items: _networkSpeeds
                            .map(
                              (v) => DropdownMenuItem<String>(
                                value: v,
                                child: Text(v),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: networkLatency,
                        decoration: const InputDecoration(labelText: 'Latency'),
                        onChanged: editable
                            ? (v) => setState(() {
                                networkLatency = v ?? 'none';
                                dirty = true;
                              })
                            : null,
                        items: _networkLatencies
                            .map(
                              (v) => DropdownMenuItem<String>(
                                value: v,
                                child: Text(v),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Text(
                dirty ? 'Unsaved changes' : 'All changes saved',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: editable ? _discard : null,
                child: const Text('Discard'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: editable
                    ? () async {
                        if (widget.avd.state != AvdState.stopped) {
                          await widget.onStopAndSave(_changes());
                        } else {
                          await widget.onSave(_changes());
                        }
                        if (!mounted) return;
                        setState(() => dirty = false);
                      }
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
