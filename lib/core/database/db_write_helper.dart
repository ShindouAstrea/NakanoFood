/// Merges sync metadata into a toMap() result before a DB write.
///
/// Usage:
///   await db.insert('products', withSync(product.toMap(), userId));
Map<String, dynamic> withSync(
  Map<String, dynamic> data,
  String? userId, {
  bool setUpdatedAt = true,
}) {
  final now = DateTime.now().toIso8601String();
  return {
    ...data,
    if (userId != null) 'user_id': userId,
    if (setUpdatedAt) 'updated_at': now,
    'synced_at': null, // null = pending upload
  };
}
