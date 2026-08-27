/// Turns a thread body into plain text.
///
/// Thread bodies come back as **raw stored HTML** — there is no `format` field
/// and no sanitized alternative, unlike the staff API which offers both. On web
/// that matters more than on mobile: injecting an agent's HTML into the page
/// unsanitized is a script-injection route straight into the trading app.
///
/// So it is converted to text rather than rendered. That loses links and
/// formatting, which is a real cost — an agent who pastes a link gets its text
/// shown but not made clickable. Rendering it properly needs a sanitizing HTML
/// widget; until then, safe and readable beats rich and risky.
String supportHtmlToText(String html) {
  if (html.isEmpty) return '';

  var text = html;

  // Structure first, while the tags are still there — otherwise every
  // paragraph runs into the next once the markup is gone.
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
  text = text.replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');

  // Whole elements whose *content* must go too, not just their tags. A
  // `<style>` block would otherwise dump CSS into the middle of the message.
  text = text.replaceAll(
    RegExp(r'<(script|style)[^>]*>.*?</\1\s*>',
        caseSensitive: false, dotAll: true),
    '',
  );

  text = text.replaceAll(RegExp(r'<[^>]+>'), '');

  // Entities, after tag removal so an escaped `&lt;b&gt;` cannot become a tag
  // that the line above would then have stripped.
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&hellip;': '…',
    '&mdash;': '—',
    '&ndash;': '–',
    '&rsquo;': '’',
    '&lsquo;': '‘',
    '&rdquo;': '”',
    '&ldquo;': '“',
  };
  entities.forEach((entity, char) => text = text.replaceAll(entity, char));

  // Numeric entities the map does not name.
  text = text.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) {
      final code = int.tryParse(m.group(1)!);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    },
  );

  // Collapse the runs of blank lines the block replacements above leave behind.
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}
