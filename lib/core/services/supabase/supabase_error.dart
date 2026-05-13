class SupabaseError implements Exception {
  final String message;

  const SupabaseError({required this.message});

  @override
  String toString() => message;
}
