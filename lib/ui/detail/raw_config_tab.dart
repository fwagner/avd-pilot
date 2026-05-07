import 'package:flutter/material.dart';

class RawConfigTab extends StatefulWidget {
  const RawConfigTab({
    super.key,
    required this.config,
    required this.editable,
    required this.onSave,
  });
  final Map<String, String> config;
  final bool editable;
  final Future<void> Function(Map<String, String>) onSave;

  @override
  State<RawConfigTab> createState() => _RawConfigTabState();
}

class _RawConfigTabState extends State<RawConfigTab> {
  late Map<String, String> config;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    config = <String, String>{...widget.config};
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(covariant RawConfigTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      config = <String, String>{...widget.config};
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, String>> all = config.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final List<MapEntry<String, String>> entries = _query.isEmpty
        ? all
        : all
              .where(
                (e) =>
                    e.key.toLowerCase().contains(_query) ||
                    e.value.toLowerCase().contains(_query),
              )
              .toList();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search key or value',
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear',
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${entries.length} / ${all.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('No matching settings found'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  itemCount: entries.length,
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        title: Text(entry.key),
                        subtitle: TextFormField(
                          enabled: widget.editable,
                          initialValue: entry.value,
                          onChanged: (value) => config[entry.key] = value,
                        ),
                        trailing: IconButton(
                          onPressed: widget.editable
                              ? () => setState(() => config.remove(entry.key))
                              : null,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              FilledButton(
                onPressed: widget.editable ? () => widget.onSave(config) : null,
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.editable
                    ? () => setState(() {
                        config['new.key.${config.length}'] = 'value';
                      })
                    : null,
                child: const Text('Add row'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
