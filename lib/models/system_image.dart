class SystemImage {
  const SystemImage({
    required this.packageId,
    required this.apiLevel,
    required this.variant,
    required this.abi,
    required this.installed,
  });

  final String packageId;
  final int apiLevel;
  final String variant;
  final String abi;
  final bool installed;

  String get displayName => 'API $apiLevel · $variant · $abi';
}
