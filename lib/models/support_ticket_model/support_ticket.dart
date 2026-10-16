/// The form field that carries the **sub-issue** — the one and only thing a
/// client chooses about how a ticket is filed.
///
/// The server picks the help topic (General) and the product (General); the
/// client picks one of General's sub-issues, and this field's `choices` are
/// already narrowed to them. The misspelling is deliberate: `categorys` is the
/// field's configured variable name in the admin panel, and renaming it there
/// would break the desk's existing reports.
///
/// Only the field *name* is pinned here — its options are read from
/// `GET /tickets/form`, because support edits that list with no app release.
const String subIssueFieldName = 'categorys';

/// What that field is called on screen.
///
/// The helpdesk labels it "Sub Issue Categories", which is how it reads to an
/// agent looking at General's sub-issues. To a client there is no parent to be
/// a sub-issue *of* — the topic is chosen for them and never shown — so the one
/// choice they make is simply the **Category**.
const String subIssueDisplayLabel = 'Category';

/// The field that carries the product. Never rendered and never sent: the
/// server sets it to General on every ticket. Named only so the create form can
/// recognise and hide it if an older install still returns it.
const String productFieldName = 'products';

/// A help topic a client may raise a ticket under (`GET /topics`).
///
/// osTicket's own public + enabled set — admins change it from the admin panel
/// with no release, so never hard-code these.
class SupportTopic {
  const SupportTopic({required this.id, required this.name});

  final int id;

  /// Sub-topics arrive with their parent path joined by ` / `.
  final String name;

  factory SupportTopic.fromJson(Map<String, dynamic> json) => SupportTopic(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        name: '${json['name'] ?? ''}',
      );
}

/// A help topic with its sub-topics, as the picker offers them.
///
/// `GET /topics` returns a flat list where a sub-topic carries its full path
/// joined by ` / ` — "Trading / Orders". This groups them back into the two
/// levels an admin sees.
class SupportTopicGroup {
  const SupportTopicGroup({
    required this.name,
    required this.children,
    this.self,
  });

  final String name;

  /// The topic in its own right, when one exists at this level. Null for a
  /// parent that only appears as a prefix on its children.
  final SupportTopic? self;

  final List<SupportTopic> children;

  /// True when picking the parent is not enough and a child must be chosen.
  bool get requiresChild => self == null && children.isNotEmpty;

  bool get hasChildren => children.isNotEmpty;

  /// The topic id to send when this group is picked with no child.
  SupportTopic? get defaultTopic => self;

  /// Groups a flat topic list into parents and their children.
  ///
  /// Splits on **space-slash-space**, never a bare `/`. This install has a
  /// top-level topic literally named `Partner/AP`, and splitting on `/` would
  /// turn it into a "Partner" group with an "AP" child that does not exist.
  static List<SupportTopicGroup> from(List<SupportTopic> topics) {
    final order = <String>[];
    final selves = <String, SupportTopic>{};
    final children = <String, List<SupportTopic>>{};

    for (final topic in topics) {
      final parts = topic.name.split(' / ');
      final parent = parts.first.trim();
      if (parent.isEmpty) continue;
      if (!order.contains(parent)) order.add(parent);

      if (parts.length == 1) {
        selves[parent] = topic;
      } else {
        // Keep the leaf's own label, not the full path — the parent is already
        // named by the group it sits under.
        children.putIfAbsent(parent, () => []).add(
              SupportTopic(
                id: topic.id,
                name: parts.sublist(1).join(' / ').trim(),
              ),
            );
      }
    }

    return [
      for (final parent in order)
        SupportTopicGroup(
          name: parent,
          self: selves[parent],
          children: children[parent] ?? const [],
        ),
    ];
  }
}

/// One field on a topic's create form (`GET /tickets/form?topic_id=`).
class SupportTicketField {
  const SupportTicketField({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    required this.editable,
    this.choices,
  });

  /// The key to send back in `custom_fields`.
  final String name;
  final String label;

  /// osTicket's own dynamic-field type string — `text`, `memo`, `phone`,
  /// `datetime`, `priority`, `list-<id>` for a custom list, and others.
  ///
  /// **Not a small fixed enum.** Render defensively and fall back to a text
  /// input for anything unrecognised; new field types appear when an admin adds
  /// one, with no release on our side.
  final String type;

  final bool required;

  /// `false` means show it read-only but never submit it — sending a locked
  /// field in `custom_fields` is a `422`.
  final bool editable;

  /// `{key: label}` for choice-backed fields, null otherwise.
  ///
  /// **Submit the key, not the label.**
  final Map<String, String>? choices;

  /// True for the choice-backed types, where a picker is needed rather than a
  /// text input.
  bool get isChoice => choices != null && choices!.isNotEmpty;

  factory SupportTicketField.fromJson(Map<String, dynamic> json) {
    final choices = json['choices'];
    return SupportTicketField(
      name: '${json['name'] ?? ''}',
      label: '${json['label'] ?? ''}',
      type: '${json['type'] ?? 'text'}',
      required: json['required'] == true,
      editable: json['editable'] == true,
      choices: choices is Map
          ? {for (final e in choices.entries) '${e.key}': '${e.value}'}
          : null,
    );
  }
}

/// One entry in a ticket's conversation.
class SupportThreadEntry {
  const SupportThreadEntry({
    required this.id,
    required this.type,
    required this.poster,
    required this.body,
    this.created,
  });

  final int id;

  /// Only ever `message` (from the client) or `response` (from an agent).
  ///
  /// Internal agent notes are filtered out at the database query, so they can
  /// never arrive here — but treat anything that is not one of these two as
  /// unrenderable rather than displaying it.
  final String type;

  /// The author. Note the key is `poster`, not `author`.
  final String poster;

  /// **Raw stored body, which on this install is almost always HTML.**
  ///
  /// There is no `format` field and no sanitized `body_html` — the staff API
  /// has both, this one deliberately does not. Render through an HTML view with
  /// a sanitizer, never as plain text. Inline `cid:` image references are not
  /// rewritten into fetchable URLs; strip or ignore them.
  final String body;

  final DateTime? created;

  bool get isFromClient => type == 'message';
  bool get isFromAgent => type == 'response';

  factory SupportThreadEntry.fromJson(Map<String, dynamic> json) =>
      SupportThreadEntry(
        id: _asInt(json['id']) ?? 0,
        type: '${json['type'] ?? ''}',
        poster: '${json['poster'] ?? ''}',
        body: '${json['body'] ?? ''}',
        created: _asDate(json['created']),
      );
}

/// A file on a ticket.
class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.name,
    this.size,
    this.type,
    this.threadEntryId,
    this.created,
  });

  final int id;
  final String name;

  /// Null when the underlying file row has gone — as are [type] and [created].
  final int? size;
  final String? type;
  final int? threadEntryId;
  final DateTime? created;

  factory SupportAttachment.fromJson(Map<String, dynamic> json) =>
      SupportAttachment(
        id: _asInt(json['id']) ?? 0,
        name: '${json['name'] ?? ''}',
        size: _asInt(json['size']),
        type: json['type'] as String?,
        threadEntryId: _asInt(json['thread_entry_id']),
        created: _asDate(json['created']),
      );
}

/// One of the client's tickets.
///
/// Deliberately narrower than what the agent console shows: a client is always
/// the requester, and the assigned agent and routing department are internal.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.number,
    required this.subject,
    this.status,
    this.priority,
    this.topic,
    this.topicId,
    this.subCategory = '',
    this.userId,
    this.created,
    this.updated,
    this.isAnswered = false,
    this.customFields = const {},
    this.thread = const [],
  });

  final int id;

  /// What the client quotes on a call, e.g. `009086`. A String, because these
  /// carry leading zeros that an int drops.
  final String number;

  final String subject;

  /// The configured **name**, not a code — `Open`, `Unassigned`, whatever the
  /// admin panel says.
  ///
  /// Admin-editable display text: **never branch on an exact value.** A
  /// brand-new ticket reads `Unassigned` on this install, not `Open`.
  final String? status;

  /// Also a configured name, same caveat as [status].
  final String? priority;

  /// Null if the ticket's help topic was deleted — and then [topicId] is null
  /// too, which is why it is nullable rather than defaulted.
  final String? topic;
  final int? topicId;

  /// The sub-issue the client picked when raising the ticket — what the form
  /// calls Category, and the only filing choice they make.
  ///
  /// Lifted out of [customFields] at parse time rather than read from there at
  /// every call site. The server files every app ticket under the one help
  /// topic (General), so [topic] alone cannot tell two tickets apart; this is
  /// the part that can.
  ///
  /// Empty for a ticket raised by mail or on the helpdesk's own web form, which
  /// carries a real [topic] and no sub-issue.
  final String subCategory;

  final int? userId;
  final DateTime? created;
  final DateTime? updated;

  /// True once an agent has replied.
  final bool isAnswered;

  /// The topic's custom answers.
  ///
  /// **Does not round-trip symmetrically.** Out, a choice carries its
  /// human-readable label (`"products": "GST"`); in, `POST /tickets` takes the
  /// choice key (`"products": "101"`). Empty answers are omitted entirely, so a
  /// field left blank simply is not here. Use the topic's form as the source of
  /// truth for what to send.
  final Map<String, String> customFields;

  /// The conversation. Populated by `GET /tickets/{id}` only — list rows carry
  /// no thread.
  final List<SupportThreadEntry> thread;

  /// "General · Brokerage", or just the one part when the other is missing.
  ///
  /// What the list's Category column shows. The help topic alone stopped
  /// telling tickets apart the day the server began filing every app ticket
  /// under General — every row read "General" — so the sub-issue is what
  /// carries the meaning and the topic is the context it sits in.
  String get categoryPath {
    final topicName = (topic ?? '').trim();
    if (topicName.isEmpty) return subCategory;
    if (subCategory.isEmpty) return topicName;
    return '$topicName · $subCategory';
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final custom = json['custom_fields'];
    final thread = json['thread'];
    return SupportTicket(
      id: _asInt(json['id']) ?? 0,
      number: '${json['number'] ?? ''}',
      subject: '${json['subject'] ?? ''}',
      status: json['status'] as String?,
      priority: json['priority'] as String?,
      topic: json['topic'] as String?,
      topicId: _asInt(json['topic_id']),
      subCategory: _subIssueLabel(custom),
      userId: _asInt(json['user_id']),
      created: _asDate(json['created']),
      updated: _asDate(json['updated']),
      isAnswered: json['isanswered'] == true,
      customFields: custom is Map
          ? {for (final e in custom.entries) '${e.key}': '${e.value}'}
          : const {},
      thread: thread is List
          ? thread
              .whereType<Map>()
              .map((e) =>
                  SupportThreadEntry.fromJson(Map<String, dynamic>.from(e)))
              // Fail closed: anything that is not a client message or an agent
              // response has no business being rendered to a client.
              .where((e) => e.isFromClient || e.isFromAgent)
              .toList()
          : const [],
    );
  }
}

/// One page of `GET /tickets`.
class SupportTicketPage {
  const SupportTicketPage({
    required this.tickets,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<SupportTicket> tickets;

  /// What the server actually applied, which is not necessarily what was asked
  /// for — `page` is clamped to 1 or more and `limit` into 1..50, and an
  /// unparseable or zero `limit` clamps to **1**, not back to the default 20.
  final int page;
  final int limit;
  final int total;

  bool get hasMore => page * limit < total;

  /// The envelope names this block `pagination`, not `meta`.
  factory SupportTicketPage.fromEnvelope(Map<String, dynamic> body) {
    final data = body['data'];
    final pagination = body['pagination'];
    return SupportTicketPage(
      tickets: data is List
          ? data
              .whereType<Map>()
              .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      page: _asInt(pagination is Map ? pagination['page'] : null) ?? 1,
      limit: _asInt(pagination is Map ? pagination['limit'] : null) ?? 20,
      total: _asInt(pagination is Map ? pagination['total'] : null) ?? 0,
    );
  }
}

/// The sub-issue's label out of a ticket's `custom_fields`, or `''`.
///
/// Matched case-insensitively because field names come from the admin panel,
/// where the same field is as likely to arrive as `Categorys`.
///
/// This reads the **label** — `custom_fields` does not round-trip: a choice
/// comes back as "Brokerage / Charges" where the create call posted its key.
String _subIssueLabel(dynamic raw) {
  if (raw is! Map) return '';
  for (final entry in raw.entries) {
    if ('${entry.key}'.trim().toLowerCase() != subIssueFieldName) continue;
    final value = entry.value == null ? '' : '${entry.value}'.trim();
    return value.toLowerCase() == 'null' ? '' : value;
  }
  return '';
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value == null) return null;
  return int.tryParse('$value');
}

/// Zone suffix on an ISO string — `+05:30`, `-0500`.
final RegExp _zoneSuffix = RegExp(r'[+-]\d{2}:?\d{2}$');

/// Parses the API's timestamps and returns them in **device-local** time.
///
/// The backend emits UTC as `"YYYY-MM-DD HH:MM:SS"` with no timezone marker,
/// and `DateTime.tryParse` treats a marker-less string as *local* — which
/// skewed every displayed time by the device's UTC offset. In IST that is
/// 5½ hours: a message the agent console showed at 12:22 PM read here as
/// 6:52 AM.
///
/// So a value carrying a time but no zone is parsed as UTC and converted to
/// local. One that already carries a zone is honoured as-is, and a bare date
/// has no time-of-day to skew.
DateTime? _asDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  final iso = value.contains('T') ? value : value.replaceFirst(' ', 'T');
  final hasTime = iso.contains(':');
  final hasZone = iso.endsWith('Z') || _zoneSuffix.hasMatch(iso);
  final normalized = (hasTime && !hasZone) ? '${iso}Z' : iso;
  return DateTime.tryParse(normalized)?.toLocal();
}

/// The four buckets the tickets table offers as tabs.
///
/// osTicket status names are admin-editable display text, so there is no fixed
/// set to switch on — this install alone answers `Unassigned`, `Escalated`,
/// `Overdue`, `Completed`, `Archived` and more. Rather than a tab per status,
/// which would vary per client and reorder itself, each status is folded into
/// one of these four. The same four the mobile app shows, so a client sees one
/// product across both.
///
/// Classifying server data on the client is a compromise, not the goal: the
/// right fix is the backend naming each status's bucket. Until it does, the
/// mapping below is deliberately generous — see [SupportStatusBucketX.fromStatus].
enum SupportStatusBucket { open, inProgress, resolved, closed }

extension SupportStatusBucketX on SupportStatusBucket {
  /// Chip label. Null is the "All" chip, which is not a bucket.
  String get label {
    switch (this) {
      case SupportStatusBucket.open:
        return 'Open';
      case SupportStatusBucket.inProgress:
        return 'In Progress';
      case SupportStatusBucket.resolved:
        return 'Resolved';
      case SupportStatusBucket.closed:
        return 'Closed';
    }
  }

  /// Folds a raw status string into a bucket.
  ///
  /// Order is load-bearing twice over: `reopen` is tested before `open`, since
  /// "reopened" contains "open" and would otherwise never reach its own case;
  /// and the terminal words are tested before the active ones so "closed" wins
  /// over any active-sounding substring.
  ///
  /// **Falls back to [open] rather than to a hidden bucket.** A status nobody
  /// anticipated is far more likely to be a new working state than a finished
  /// one, and a ticket that matches no tab is a ticket the client cannot reach
  /// from the chips at all — it would show under All and nowhere else.
  static SupportStatusBucket fromStatus(String? raw) {
    final v = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (v.isEmpty) return SupportStatusBucket.open;

    // Reopening puts a ticket back in play, so it belongs with the active ones.
    if (v.contains('reopen')) return SupportStatusBucket.open;

    if (v.contains('progress') || v == 'working' || v == 'processing') {
      return SupportStatusBucket.inProgress;
    }

    // `complete` covers both "Complete" and "Completed" — answered work that
    // has not been filed away yet.
    if (v.contains('resolve') ||
        v.contains('complete') ||
        v == 'answered' ||
        v == 'solved') {
      return SupportStatusBucket.resolved;
    }

    // Archived and deleted tickets are done with, whatever the desk calls them.
    if (v.contains('close') || v.contains('archiv') || v.contains('delet')) {
      return SupportStatusBucket.closed;
    }

    // Escalated and overdue are urgent, not finished — both still need an
    // answer, so they sit under Open where the client will look for them.
    return SupportStatusBucket.open;
  }
}
