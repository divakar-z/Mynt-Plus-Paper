/// Prepares client-typed text for a ticket body.
///
/// This install stores and renders bodies as HTML, so a plain line break is
/// whitespace to it and collapses — a four-line diagnostic footer arrives at
/// the desk as one run-on line. `<br>` is the only break that survives.
///
/// Escaping comes first and is not optional. Without it a description
/// containing `<` or `&` is interpreted rather than shown, and client text
/// reaching an agent's console as live markup is a script-injection route into
/// the helpdesk. `&` is replaced before the angle brackets, or the `&` in the
/// entities this produces would be escaped a second time.
///
/// The reverse trip is [supportHtmlToText], which turns `<br>` back into a
/// newline and decodes these same entities.
String supportTextToHtml(String text) {
  if (text.isEmpty) return '';
  final escaped = text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return escaped.replaceAll(RegExp(r'\r\n|\r|\n'), '<br>');
}

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
