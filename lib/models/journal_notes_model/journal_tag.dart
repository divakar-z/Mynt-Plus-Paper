/// A personal, client-scoped behaviour label ("revenge-trade", "planned-setup").
///
/// Tags are per client — two clients can both have "revenge-trade" and they are
/// different tags. Names are unique per client, case- and whitespace-insensitive.
class JournalTag {
  final int tagId;
  final String name;

  /// 6-digit hex with a leading `#`, e.g. `#CC3344`. Null when the tag was
  /// created without one — render a neutral chip rather than assuming a default.
  final String? color;

  /// Live notes carrying this tag. Only returned by `/tags/list`; null elsewhere.
  final int? noteCount;

  const JournalTag({
    required this.tagId,
    required this.name,
    this.color,
    this.noteCount,
  });

  factory JournalTag.fromJson(Map<String, dynamic> json) {
    return JournalTag(
      tagId: (json['tag_id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
      noteCount: (json['note_count'] as num?)?.toInt(),
    );
  }

  static List<JournalTag> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => JournalTag.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  bool operator ==(Object other) => other is JournalTag && other.tagId == tagId;

  @override
  int get hashCode => tagId.hashCode;

  @override
  String toString() => 'JournalTag($tagId, $name)';
}

/// Outcome of `/tags/create`.
///
/// A name collision is not an error path. The backend returns the existing tag
/// on `409 TAG_EXISTS`, so a type-ahead "create or attach" flow attaches
/// [tag] either way and only uses [alreadyExisted] to adjust its wording.
class TagCreateResult {
  final JournalTag tag;
  final bool alreadyExisted;

  const TagCreateResult({required this.tag, required this.alreadyExisted});
}

/// Outcome of `/tags/delete`.
///
/// When the tag is attached to live notes the backend refuses and reports how
/// many. Show the count, confirm, then resend with `force: true`. Deletion is
/// permanent and detaches from every note — there is no undo.
class TagDeleteResult {
  /// Notes the tag was attached to. Populated on both outcomes: the blocking
  /// count when [refusedInUse], the detached count on success.
  final int noteCount;

  /// True when nothing was deleted because the tag is still in use.
  final bool refusedInUse;

  const TagDeleteResult({required this.noteCount, required this.refusedInUse});
}
