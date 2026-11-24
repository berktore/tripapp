/// Kullanıcıya gösterilebilir, sınıflandırılmış uygulama hataları.
///
/// [message] kullanıcıya gösterilir; [details] teknik ayrıntıdır ve
/// hata ayıklama/raporlama için korunur (gizlenmez).
enum AppErrorKind {
  locationNotFound,
  providerUnavailable,
  noPlaces,
  timeout,
  storage,
  invalidInput,
  unknown,
}

class AppException implements Exception {
  const AppException(
    this.message, {
    this.kind = AppErrorKind.unknown,
    this.details,
  });

  final String message;
  final AppErrorKind kind;
  final String? details;

  @override
  String toString() => details == null ? message : '$message ($details)';
}
