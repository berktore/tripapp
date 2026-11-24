import 'package:flutter/foundation.dart';

/// Yalnızca debug derlemelerinde log üretir.
///
/// Release derlemesinde ağ yanıtları ve OSM istatistikleri yazdırılmaz;
/// böylece hem gürültü hem de gereksiz I/O önlenir.
void logDebug(Object? message, {Object? error, StackTrace? stackTrace}) {
  if (!kDebugMode) return;

  if (error == null) {
    debugPrint('[TripApp] $message');
    return;
  }

  debugPrint('[TripApp] $message: $error');
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace);
  }
}
