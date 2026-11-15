/// Parses shareable dream links into in-app routes.
///
/// Accepted forms:
///   `https://trydream.fun/d/{id}` (web share link, Android App Link)
///   `dreamapp://dream/{id}`       (custom scheme)
abstract final class DreamShareLink {
  static const hosts = {'trydream.fun', 'www.trydream.fun'};

  // Dream ids are 8–16 base58 characters (server-generated).
  static final _id = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{8,16}$');

  /// The `/dreams/{id}` route for [uri], or null if it isn't a dream link.
  static String? routeFor(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? id;
    if (uri.scheme == 'dreamapp' &&
        uri.host == 'dream' &&
        segments.length == 1) {
      id = segments.first;
    } else if (uri.scheme == 'https' &&
        hosts.contains(uri.host) &&
        segments.length == 2 &&
        segments.first == 'd') {
      id = segments[1];
    }
    if (id == null || !_id.hasMatch(id)) return null;
    return '/dreams/$id';
  }
}
