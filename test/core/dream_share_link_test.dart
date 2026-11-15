import 'package:dream/core/navigation/dream_share_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses web and app-scheme dream links', () {
    expect(
      DreamShareLink.routeFor(Uri.parse('https://trydream.fun/d/3xQm9WkPz7Ab')),
      '/dreams/3xQm9WkPz7Ab',
    );
    expect(
      DreamShareLink.routeFor(Uri.parse('dreamapp://dream/3xQm9WkPz7Ab')),
      '/dreams/3xQm9WkPz7Ab',
    );
  });

  test('rejects other hosts, paths and malformed ids', () {
    for (final raw in [
      'https://evil.com/d/3xQm9WkPz7Ab',
      'https://trydream.fun/x/3xQm9WkPz7Ab',
      'https://trydream.fun/d/../../settings',
      'https://trydream.fun/d/0OIl0OIl0OIl',
      'http://trydream.fun/d/3xQm9WkPz7Ab',
    ]) {
      expect(DreamShareLink.routeFor(Uri.parse(raw)), isNull, reason: raw);
    }
  });
}
