/// The release identity of this build, as the business names it.
///
/// **Hand-updated on each release.** Nothing stamps these automatically, so
/// they are the one place to edit — the login footer and every support ticket
/// read from here, and a release that updates only one of them puts the desk
/// and the client on different numbers.
///
/// Deliberately *not* the pubspec `version:`. That number tracks a different
/// sequence (`1.0.101+1` while the release is `3.0.3`), and a support agent
/// quoting it back to a client names a build nobody recognises. Read through
/// `PackageInfo` only if you specifically want the pubspec value.
class AppRelease {
  const AppRelease._();

  /// e.g. `3.0.3`.
  static const String version = '3.0.3';

  /// e.g. `1.0.554`.
  static const String build = '1.0.565';

  /// e.g. `3 Sep 2026`.
  static const String releasedOn = '10 Sep 2026';

  /// Short form for the login footer.
  static const String short = 'Version $version';

  /// Full build and release details, for the login hover tooltip.
  static const String label =
      'Version $version Build $build Released on $releasedOn';

  /// What a support ticket reports, so an agent reads the same build the
  /// client sees on the login screen.
  static const String forSupport = '$version Build $build';
}
