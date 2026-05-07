import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedAvdNameProvider = StateProvider<String?>((ref) => null);
final editingLockProvider = StateProvider<bool>((ref) => false);
