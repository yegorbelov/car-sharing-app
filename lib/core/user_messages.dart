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
    'dispute_open' => 'This deal has an open dispute — wait for arbitration.',
    'dispute_already_open' => 'A dispute is already open for this deal.',
    'cannot_dispute_status' =>
        'Disputes can only be opened on active or completed trips.',
    'description_too_short' => 'Please describe the issue (at least 10 characters).',
    'owner_insufficient_balance' =>
        'Owner balance is too low to adjust funds after payout.',
    _ => code.replaceAll('_', ' '),
  };
}
