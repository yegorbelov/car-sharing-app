/// Maps API / exception values to short user-facing strings.
String userFacingError(Object error) {
  if (error is Exception) {
    final s = error.toString();
    if (s.startsWith('Exception: ')) return s.substring(11);
    return s;
  }
  return error.toString();
}

String mapDealActionError(String code) {
  return switch (code) {
    'insufficient_funds' => 'Not enough balance for this action.',
    'invalid_status' => 'This action is no longer available for this deal.',
    'forbidden' => 'You cannot perform this action on this deal.',
    'not_found' => 'Deal not found.',
    'session_expired' => 'Your session expired. Please sign in again.',
    _ => code.replaceAll('_', ' '),
  };
}
