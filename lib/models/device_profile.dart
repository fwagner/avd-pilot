class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.name,
    required this.oem,
  });

  final String id;
  final String name;
  final String oem;

  String get displayName => '$oem · $name';
}
