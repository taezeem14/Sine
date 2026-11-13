class AppConstants {
  static const String appName = 'Sine';
  static const String appTagline = 'High-Fidelity YouTube Music Client';
  static const String version = '1.2.10';
  static const int buildNumber = 28;
  static const String fullVersion = '$version+$buildNumber';
  static const String releaseTag = 'v$version';
  static const String releaseName = 'v$version (Release Build)';
  static const String githubRepo = 'https://github.com/taezeem14/Sine';

  /// Open Source GPL-3.0 Attribution Registry
  static const List<Map<String, String>> openSourceAttributions = [
    {
      'name': 'Audile',
      'organization': 'AudileTeam',
      'license': 'GPL-3.0',
      'repo': 'https://github.com/AudileTeam/Audile',
      'role': 'Music player & recognition client; foreground audio playback service and media notification architecture.',
    },
    {
      'name': 'zemer-cipher',
      'organization': 'ZemerTeam',
      'license': 'GPL-3.0',
      'repo': 'https://github.com/ZemerTeam/zemer-cipher',
      'role': 'YouTube signature cipher decryption and n-parameter stream deciphering algorithms.',
    },
    {
      'name': 'BetterLyrics',
      'organization': 'better-lyrics / boidushya',
      'license': 'GPL-3.0',
      'repo': 'https://github.com/boidushya/better-lyrics',
      'role': 'Real-time synchronized karaoke lyrics parsing, word-by-word timing, and offset calibration.',
    },
    {
      'name': 'Metrolist',
      'organization': 'MetrolistGroup',
      'license': 'GPL-3.0',
      'repo': 'https://github.com/MetrolistGroup/Metrolist',
      'role': 'Material YouTube Music client architecture, local caching, and playlist queue pipelines.',
    },
  ];
}
