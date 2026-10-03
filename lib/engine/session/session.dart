/// The tokens of one login, plus two switches. Lives only in memory (one per
/// environment, see the UI's session provider); it is never serialized.
class Session {
  const Session({
    this.accessToken = '',
    this.refreshToken = '',
    this.attachAuth = true,
    this.captureTokens = true,
  });

  final String accessToken;
  final String refreshToken;

  /// Send the access token as `Authorization: Bearer` on requests that don't
  /// set their own authorization.
  final bool attachAuth;

  /// Pick tokens out of 2xx JSON responses and store them here.
  final bool captureTokens;

  /// Whether there is an access token to send (blank counts as none).
  bool get hasToken => accessToken.trim().isNotEmpty;

  Session copyWith({
    String? accessToken,
    String? refreshToken,
    bool? attachAuth,
    bool? captureTokens,
  }) =>
      Session(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        attachAuth: attachAuth ?? this.attachAuth,
        captureTokens: captureTokens ?? this.captureTokens,
      );

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.attachAuth == attachAuth &&
      other.captureTokens == captureTokens;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, attachAuth, captureTokens);

  /// Deliberately omits the token values so a session can't leak through a
  /// log line or an error message.
  @override
  String toString() => 'Session(hasToken: $hasToken, attachAuth: $attachAuth, captureTokens: $captureTokens)';
}

/// The variables a session contributes to `{{...}}` interpolation:
/// `session_access_token` and `session_refresh_token`, only when non-empty.
Map<String, String> sessionVariables(Session session) => {
      if (session.accessToken.isNotEmpty) 'session_access_token': session.accessToken,
      if (session.refreshToken.isNotEmpty) 'session_refresh_token': session.refreshToken,
    };
