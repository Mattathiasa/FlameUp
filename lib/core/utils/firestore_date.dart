/// Reading dates out of Firestore documents.
///
/// The client writes ISO-8601 strings (so the same payload works offline in
/// Hive and online in Firestore), while server writes -- `serverTimestamp()`
/// in triggers and the outbox drain -- land as Firestore `Timestamp` objects.
/// A `Timestamp` thrown at `as String?` is a `TypeError`, which every
/// `fromJson` here treats as "drop the document": one server-written date
/// could blank a whole list. This is the one parser every model uses, so both
/// shapes read and neither shape crashes.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? firestoreDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}
