import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../models/support_ticket_model/support_ticket.dart';
import '../models/support_ticket_model/support_ticket_context.dart';
import '../models/support_ticket_model/support_ticket_exception.dart';
import 'core/default_change_notifier.dart';

final supportTicketProvider =
    ChangeNotifierProvider((ref) => SupportTicketProvider());

/// Form state for the raise-a-ticket surface, and the client's ticket list.
///
/// Holds the controllers so the typed text survives a rebuild — and, more
/// importantly, survives a failed submit. Someone who has just hit a bug and
/// then loses their description of it will phone instead, which is the outcome
/// this whole feature exists to avoid. Nothing here clears the form except
/// [reset], and [raise] only calls it after a confirmed ticket.
class SupportTicketProvider extends DefaultChangeNotifier {
  SupportTicketProvider();

  final api = locator<ApiExporter>();

  final TextEditingController subject = TextEditingController();
  final TextEditingController message = TextEditingController();

  /// Client-side caps. A convenience only — the API validates independently
  /// and is the real control.
  static const int kSubjectMaxLength = 120;
  static const int kMessageMaxLength = 2000;

  /// Largest single attachment.
  static const int kAttachmentMaxBytes = 8 * 1024 * 1024;

  /// How many files one ticket may carry.
  static const int kAttachmentMaxCount = 20;

  /// `8 MB` — used in limit messages so they cannot drift from the caps.
  static String formatMb(int bytes) =>
      '${(bytes / (1024 * 1024)).round()} MB';

  // --- Topics and the topic's own form -------------------------------------

  /// The one topic every client ticket is raised under.
  ///
  /// The client is **not** asked to choose. Support triages and re-routes from
  /// their side, which they can do far better than a trading client picking
  /// between "MII-s" and "Partner/AP" — categories that mean nothing to
  /// someone whose order just failed. So the picker is not rendered at all.
  ///
  /// `1` is General's `topic_id` on the live install. Matches mobile.
  static const SupportTopic kFixedTopic =
      SupportTopic(id: 1, name: 'General');

  /// Fields the form fills in silently rather than asking for.
  ///
  ///  * `clientid` — deliberately **not** sent. The requester is identified by
  ///    the session, so repeating the trading code in a form field only
  ///    duplicates what the ticket already carries.
  ///  * `products` — General offers exactly one option, so asking is a dead
  ///    choice; it is resolved from the form and sent automatically.
  static const Set<String> _silentFields = {'clientid', 'products'};

  /// What the client is actually asked to fill.
  ///
  /// Anything else a help topic defines is still rendered, so an admin adding a
  /// required field does not silently start failing every create.
  List<SupportTicketField> get collectableFields => _topicFields
      .where((f) => f.editable && !_silentFields.contains(f.name.toLowerCase()))
      .toList();

  /// Help topics, from the API. Never hard-coded: admins change the set from
  /// the admin panel with no release on our side.
  List<SupportTopic> _topics = const [];
  List<SupportTopic> get topics => _topics;


  /// The chosen topic. Required — it is what routes the ticket to a department.
  SupportTopic? _topic;
  SupportTopic? get topic => _topic;

  /// The chosen topic's own fields, which vary per topic and can be required.
  List<SupportTicketField> _topicFields = const [];
  List<SupportTicketField> get topicFields => _topicFields;

  /// Fields the client should actually be asked to fill.
  ///
  /// `subject` and `priority` commonly arrive here as visible-but-locked;
  /// subject is a dedicated top-level field on create, not a `custom_fields`
  /// entry, and sending a locked field is a `422`.
  List<SupportTicketField> get editableTopicFields =>
      _topicFields.where((f) => f.editable).toList();

  /// Answers keyed by field name. Choice fields hold the choice **key**, not
  /// its label — that is what create accepts.
  final Map<String, String> _customFieldAnswers = {};
  Map<String, String> get customFieldAnswers =>
      Map.unmodifiable(_customFieldAnswers);

  /// True while the topic list is in flight.
  bool _loadingTopics = false;
  bool get loadingTopics => _loadingTopics;

  /// True while *a topic's own fields* are in flight.
  ///
  /// Separate from [loadingTopics] on purpose: they overlap, and one flag for
  /// both meant fetching the topic list also blanked the fields area of a topic
  /// already chosen.
  bool _loadingFields = false;
  bool get loadingFields => _loadingFields;

  /// Set when a topic's form could not be loaded.
  ///
  /// Its own error rather than a toast: the fields are the part that failed, so
  /// that is where it has to be said — and without it the section just silently
  /// renders nothing, which reads as "this topic asks for nothing".
  String? _formError;
  String? get formError => _formError;

  // --- The client's tickets ------------------------------------------------

  /// One page is fetched, at the API's maximum.
  ///
  /// A client with more than this many support tickets is not a case worth
  /// paging for, and the list's search and filters run client-side — so paging
  /// would mean a search that only finds matches on the page already loaded.
  /// [hasMoreTickets] exists so the table can say so rather than quietly
  /// showing a subset.
  static const int kTicketsPageSize = 50;

  List<SupportTicket> _tickets = const [];
  List<SupportTicket> get tickets => _tickets;

  bool _loadingTickets = false;
  bool get loadingTickets => _loadingTickets;

  /// Set when the last fetch failed, so the table can offer a retry instead of
  /// showing an empty state that reads as "you have no tickets".
  String? _ticketsError;
  String? get ticketsError => _ticketsError;

  int _ticketsTotal = 0;
  int get ticketsTotal => _ticketsTotal;

  bool get hasMoreTickets => _tickets.length < _ticketsTotal;

  /// Fetches the client's tickets.
  ///
  /// Returns early if a list is already held, unless [force] — which is what
  /// the post-raise refresh passes, since the new ticket must appear.
  Future<void> loadTickets({bool force = false}) async {
    if (_loadingTickets) return;
    if (!force && _tickets.isNotEmpty) return;

    _loadingTickets = true;
    _ticketsError = null;
    notifyListeners();
    try {
      final page = await api.fetchTickets(page: 1, limit: kTicketsPageSize);
      _tickets = _sorted(page.tickets);
      _ticketsTotal = page.total;
    } on SupportTicketException catch (e) {
      _ticketsError = e.message;
    } catch (_) {
      _ticketsError = "Couldn't load your tickets — please try again.";
    } finally {
      _loadingTickets = false;
      notifyListeners();
    }
  }

  /// Fetches the next page and appends it.
  ///
  /// Appends rather than replaces, because the search and filters above run
  /// over whatever is loaded — replacing would make paging feel like the list
  /// resetting.
  Future<void> loadMoreTickets() async {
    if (_loadingMore || _loadingTickets || !hasMoreTickets) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final next = (_tickets.length ~/ kTicketsPageSize) + 1;
      final page = await api.fetchTickets(page: next, limit: kTicketsPageSize);
      // Guard against a duplicate page: a ticket raised between two fetches
      // shifts everything down one, so the same row can arrive twice.
      final seen = _tickets.map((t) => t.id).toSet();
      _tickets = _sorted([
        ..._tickets,
        ...page.tickets.where((t) => !seen.contains(t.id)),
      ]);
      _ticketsTotal = page.total;
    } on SupportTicketException catch (e) {
      _ticketsError = e.message;
    } catch (_) {
      _ticketsError = "Couldn't load more tickets — please try again.";
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  /// Most recently active first, falling back to created when a ticket has
  /// never been updated.
  ///
  /// Sorted here rather than trusted from the server: paging appends, so a
  /// second page arriving after the first would otherwise sit below rows that
  /// are older than it.
  List<SupportTicket> _sorted(List<SupportTicket> tickets) {
    final list = [...tickets];
    list.sort((a, b) {
      final at = a.updated ?? a.created;
      final bt = b.updated ?? b.created;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return list;
  }

  // --- One ticket, open on screen ------------------------------------------

  /// The ticket being read, with its conversation.
  SupportTicket? _activeTicket;
  SupportTicket? get activeTicket => _activeTicket;

  List<SupportAttachment> _activeAttachments = const [];
  List<SupportAttachment> get activeAttachments => _activeAttachments;

  bool _loadingActive = false;
  bool get loadingActive => _loadingActive;

  String? _activeError;
  String? get activeError => _activeError;

  bool _sendingReply = false;
  bool get sendingReply => _sendingReply;

  final TextEditingController reply = TextEditingController();

  /// Files staged for the next reply.
  final List<PlatformFile> _replyAttachments = [];
  List<PlatformFile> get replyAttachments => List.unmodifiable(_replyAttachments);

  /// Opens a ticket.
  ///
  /// [preview] is the row already on screen. Showing it immediately means the
  /// header has a subject and status while the conversation loads, rather than
  /// a spinner over an empty panel.
  Future<void> openTicket(int id, {SupportTicket? preview}) async {
    // Replaces whatever the last panel left behind, which is why closing does
    // not need to clear it.
    _activeTicket = preview;
    _activeAttachments = const [];
    _activeError = null;
    _attachmentBytes.clear();
    _loadingActive = true;
    reply.clear();
    _replyAttachments.clear();
    notifyListeners();
    await _fetchActive(id);
  }

  /// Re-reads the open ticket — after a reply, or on pull-to-refresh.
  Future<void> refreshActiveTicket() async {
    final id = _activeTicket?.id;
    if (id == null || id == 0) return;
    await _fetchActive(id);
  }

  Future<void> _fetchActive(int id) async {
    _loadingActive = true;
    notifyListeners();
    try {
      final ticket = await api.fetchTicket(id);
      _activeTicket = ticket;
      // Secondary: a ticket that opens without its file list still works, so a
      // failure here is swallowed rather than failing the whole screen.
      try {
        _activeAttachments = await api.fetchTicketAttachments(id);
      } catch (_) {
        _activeAttachments = const [];
      }
      _activeError = null;
    } on SupportTicketException catch (e) {
      _activeError = e.message;
    } catch (_) {
      _activeError = "Couldn't load this ticket — please try again.";
    } finally {
      _loadingActive = false;
      notifyListeners();
    }
  }

  /// Called when the panel closes.
  ///
  /// Deliberately does **not** clear the ticket. The panel is still on screen
  /// while the drawer animates out, so nulling it here made the conversation
  /// blank to "Nothing here yet" for the length of the animation — the client
  /// watched the ticket empty itself on the way out.
  ///
  /// Nothing needs clearing: [openTicket] replaces the ticket outright, so a
  /// stale one is never shown. Only the half-typed reply has to go, or it would
  /// follow the client into the next ticket they open.
  void closeTicket() {
    reply.clear();
    _replyAttachments.clear();
    notifyListeners();
  }

  /// Picks files to send with the reply.
  Future<String?> pickReplyAttachments() async {
    final picked = await _pickFiles(_replyAttachments);
    notifyListeners();
    return picked;
  }

  void removeReplyAttachmentAt(int index) {
    if (index < 0 || index >= _replyAttachments.length) return;
    _replyAttachments.removeAt(index);
    notifyListeners();
  }

  /// Posts a reply, with any staged files.
  ///
  /// A reply with files but no text still lands: each upload posts its own
  /// `Attachment: <name>` entry, so the thread is not left silent.
  ///
  /// Returns an error message, or null on success.
  Future<String?> sendReply() async {
    final id = _activeTicket?.id;
    if (id == null || id == 0) return 'No ticket is open.';
    if (_sendingReply) return null;

    final text = reply.text.trim();
    if (text.isEmpty && _replyAttachments.isEmpty) {
      return 'Type a reply, or attach a file.';
    }

    _sendingReply = true;
    notifyListeners();
    try {
      if (text.isNotEmpty) {
        await api.replyToTicket(id, text);
      }
      for (final file in _replyAttachments) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        // Best effort: the reply itself already landed, and losing a
        // screenshot is not worth reporting the whole action as failed.
        try {
          await api.uploadTicketAttachment(id, bytes: bytes, filename: file.name);
        } catch (_) {}
      }
      reply.clear();
      _replyAttachments.clear();
      // The thread and the ticket's status both changed underneath us — a
      // reply can reopen a closed ticket, so the header needs re-reading too.
      await _fetchActive(id);
      // Keep the list's copy of this row in step with what was just fetched.
      final updated = _activeTicket;
      if (updated != null) {
        _tickets = [
          for (final t in _tickets) if (t.id == updated.id) updated else t,
        ];
      }
      return null;
    } on SupportTicketException catch (e) {
      return e.message;
    } catch (_) {
      return "Couldn't send that reply — please try again.";
    } finally {
      _sendingReply = false;
      notifyListeners();
    }
  }

  /// Reopens a resolved ticket.
  ///
  /// There is no reopen endpoint and none is needed: a reply reopens a
  /// closed-but-reopenable ticket by itself. One the model will not reopen
  /// simply stays closed with the reply attached, so this never invents a
  /// refusal the server does not enforce.
  Future<String?> reopenActiveTicket({String reason = ''}) async {
    reply.text = reason.trim().isEmpty
        ? 'Reopening this — the issue is not resolved.'
        : reason.trim();
    return sendReply();
  }

  /// Bytes already fetched, keyed by attachment id.
  ///
  /// Cached because the thread rebuilds on every keystroke in the reply box,
  /// and an inline preview that refetched each time would hammer the API and
  /// flicker. Cleared with the ticket, so it never outlives what it belongs to.
  final Map<int, Uint8List> _attachmentBytes = {};

  Uint8List? cachedAttachmentBytes(int id) => _attachmentBytes[id];

  /// Ids currently being fetched, so a rebuild mid-flight does not start a
  /// second request for the same file.
  final Set<int> _attachmentsLoading = {};

  /// Fetches an image attachment for inline preview.
  ///
  /// Bytes rather than a URL: the client API deliberately exposes no
  /// `download_url`, because such a URL would carry its own auth knowing
  /// nothing about ticket ownership. So `Image.network` is not an option and
  /// the bytes come through the authenticated route instead.
  Future<void> ensureAttachmentBytes(SupportAttachment attachment) async {
    final id = attachment.id;
    if (_attachmentBytes.containsKey(id) || _attachmentsLoading.contains(id)) {
      return;
    }
    final ticketId = _activeTicket?.id;
    if (ticketId == null || ticketId == 0) return;

    _attachmentsLoading.add(id);
    try {
      final bytes = await api.downloadTicketAttachment(ticketId, id);
      _attachmentBytes[id] = Uint8List.fromList(bytes);
      notifyListeners();
    } catch (_) {
      // A preview that will not load is not worth reporting — the chip below
      // it still opens the file.
    } finally {
      _attachmentsLoading.remove(id);
    }
  }

  /// Fetches an attachment's bytes, for the browser to save.
  Future<List<int>?> downloadAttachment(SupportAttachment attachment) async {
    final id = _activeTicket?.id;
    if (id == null || id == 0) return null;
    try {
      return await api.downloadTicketAttachment(id, attachment.id);
    } catch (_) {
      return null;
    }
  }

  // --- Attachments ---------------------------------------------------------

  final List<PlatformFile> _attachments = [];
  List<PlatformFile> get attachments => List.unmodifiable(_attachments);

  int get attachmentsTotalBytes =>
      _attachments.fold(0, (sum, f) => sum + f.size);

  /// False once the count cap is reached, so the form can hide the picker
  /// rather than opening one whose result it would refuse.
  bool get canAddAttachment => _attachments.length < kAttachmentMaxCount;

  // --- Form state ----------------------------------------------------------

  /// Per-field validation messages, keyed by field name.
  ///
  /// Only ever client-side checks and the fields a `validation` failure names.
  /// Everything else goes to a toast — an inline red under a field the client
  /// cannot fix is noise.
  Map<String, String> _fieldErrors = const {};
  Map<String, String> get fieldErrors => _fieldErrors;

  /// Set once a ticket is raised, so the surface can show its number.
  SupportTicket? _lastResult;
  SupportTicket? get lastResult => _lastResult;

  /// True only while a submit is in flight. This is the *only* thing that
  /// disables the button — validation never does. The click always fires and
  /// answers with an inline error, matching the login screen.
  bool get submitting => loading;

  // --- Topic selection -----------------------------------------------------

  /// Loads the topic list. Safe to call on every open — returns early once the
  /// list is held.
  ///
  /// This is also what establishes the support session, since it is the first
  /// authenticated call: the exchange happens underneath it.
  Future<void> loadTopics({void Function(String message)? onError}) async {
    if (_topicFields.isNotEmpty || _loadingFields) return;
    _topic = kFixedTopic;
    _formError = null;
    _loadingFields = true;
    notifyListeners();
    try {
      // Straight to the fixed topic's form. The topic list is not fetched at
      // all now that nothing offers a choice — one fewer call on open, and one
      // fewer thing to fail.
      _disposeFieldControllers();
      _topicFields = await api.fetchTicketForm(kFixedTopic.id);
    } on SupportTicketException catch (e) {
      _formError = e.message;
      onError?.call(e.message);
    } catch (_) {
      _formError = "Couldn't load the support form.";
      onError?.call("Couldn't load the support form — please try again.");
    } finally {
      _loadingFields = false;
      notifyListeners();
    }
  }

  /// Resolves the fields the client is never shown.
  ///
  /// A single-choice field is answered with its only option — General's
  /// `products` is exactly that, and leaving it blank would either fail a
  /// required check or land the ticket unclassified. A field with several
  /// options is left alone: guessing one would be inventing an answer.
  Map<String, String> _resolveSilentFields() {
    final resolved = <String, String>{};
    for (final field in _topicFields) {
      if (!field.editable) continue;
      final name = field.name.toLowerCase();
      if (!_silentFields.contains(name)) continue;
      // The client code is never echoed back into a form field.
      if (name == 'clientid') continue;
      final choices = field.choices;
      if (choices != null && choices.length == 1) {
        resolved[field.name] = choices.keys.first;
      }
    }
    return resolved;
  }

  /// One controller per dynamic text field, kept across rebuilds.
  ///
  /// Built fresh on each build, a controller resets its selection every time
  /// the widget rebuilds — and the form rebuilds on every keystroke, so the
  /// caret jumps back to the start and typing comes out reversed.
  ///
  /// Keyed by field name and discarded when the topic changes, since a field
  /// from the previous topic has nothing to hold.
  final Map<String, TextEditingController> _fieldControllers = {};

  TextEditingController fieldController(String name) =>
      _fieldControllers.putIfAbsent(
        name,
        () => TextEditingController(text: _customFieldAnswers[name] ?? ''),
      );

  void _disposeFieldControllers() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _fieldControllers.clear();
  }

  void setCustomField(String name, String value) {
    if (value.isEmpty) {
      _customFieldAnswers.remove(name);
    } else {
      _customFieldAnswers[name] = value;
    }
    _clearError(name);
    notifyListeners();
  }

  // --- Attachments ---------------------------------------------------------

  /// Opens the picker and keeps whatever passes.
  ///
  /// `withData: true` matters on web — without it `bytes` comes back null and
  /// there is nothing to upload, since there is no file path to read from.
  ///
  /// Anything acceptable is kept even when a sibling is rejected: refusing the
  /// whole selection because one file was too big means picking them all again.
  /// Returns a message describing what was skipped, or null.
  Future<String?> pickAttachments() async {
    final failure = await _pickFiles(_attachments);
    notifyListeners();
    return failure;
  }

  /// Adds files the client dragged onto the create form.
  ///
  /// Same rules as the picker — see [_acceptFiles]. Returns a message
  /// describing what was skipped, or null when everything was taken.
  String? addDroppedAttachments(List<PlatformFile> files) {
    if (files.isEmpty) return null;
    if (_attachments.length >= kAttachmentMaxCount) {
      return 'You can attach up to $kAttachmentMaxCount files.';
    }
    final failure = _acceptFiles(files, _attachments);
    notifyListeners();
    return failure;
  }

  /// Opens the picker and appends whatever passes into [target].
  ///
  /// Shared by the create form and the reply box: both cap the same way, and a
  /// second copy of these rules is a second place for them to drift.
  ///
  /// `withData: true` matters on web — without it `bytes` comes back null and
  /// there is nothing to upload, since there is no file path to read from.
  ///
  /// Anything acceptable is kept even when a sibling is rejected: refusing the
  /// whole selection because one file was too big means picking them all again.
  /// Returns a message describing what was skipped, or null.
  Future<String?> _pickFiles(List<PlatformFile> target) async {
    if (target.length >= kAttachmentMaxCount) {
      return 'You can attach up to $kAttachmentMaxCount files.';
    }

    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        // Every type. The desk asks for ledgers, contract notes, screen
        // recordings and archives, and an allow-list here only means a client
        // is refused something support would happily have taken. osTicket
        // enforces its own MIME rules server-side, which is the check that
        // actually counts.
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );
    } catch (_) {
      return "Couldn't open the file picker — please try again.";
    }
    if (result == null || result.files.isEmpty) return null; // Cancelled.

    return _acceptFiles(result.files, target);
  }

  /// Appends whatever passes the attachment rules into [target].
  ///
  /// Split out of [_pickFiles] so a browser drag-and-drop lands on exactly the
  /// same cap, size, readability and duplicate checks as the file picker. Two
  /// copies of these rules is two places for them to drift, and a client who
  /// drops a 20 MB file should be told the same thing as one who picks it.
  String? _acceptFiles(List<PlatformFile> incoming, List<PlatformFile> target) {
    final rejected = <String>[];
    var duplicates = 0;

    for (final file in incoming) {
      if (target.length >= kAttachmentMaxCount) {
        rejected.add('${file.name} (limit is $kAttachmentMaxCount files)');
        continue;
      }
      if (file.size > kAttachmentMaxBytes) {
        rejected.add('${file.name} (over ${formatMb(kAttachmentMaxBytes)})');
        continue;
      }
      if (file.bytes == null) {
        rejected.add('${file.name} (unreadable)');
        continue;
      }
      // Same name and size twice is a double-pick, not two files. Counted
      // rather than dropped in silence: picking a file that is already
      // attached looks identical to the picker failing, and the client is left
      // clicking Add another and watching nothing happen.
      if (target.any((a) => a.name == file.name && a.size == file.size)) {
        duplicates++;
        continue;
      }
      target.add(file);
      _clearError('attachment');
    }

    if (rejected.isEmpty && duplicates == 0) return null;

    final parts = <String>[];
    if (duplicates > 0) {
      parts.add(duplicates == 1
          ? 'That file is already attached.'
          : '$duplicates files were already attached.');
    }
    if (rejected.length == 1) {
      parts.add('Skipped ${rejected.first}.');
    } else if (rejected.length > 1) {
      parts.add('Skipped ${rejected.length} files: ${rejected.join(', ')}.');
    }
    return parts.join(' ');
  }

  void removeAttachmentAt(int index) {
    if (index < 0 || index >= _attachments.length) return;
    _attachments.removeAt(index);
    notifyListeners();
  }

  // --- Validation ----------------------------------------------------------

  /// Drops a field's error as soon as it is being corrected.
  void _clearError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    _fieldErrors = {..._fieldErrors}..remove(field);
    notifyListeners();
  }

  void onSubjectChanged(String _) => _clearError('subject');

  void onMessageChanged(String _) => _clearError('message');

  /// Client-side checks, per field rather than one banner at the top.
  ///
  /// Topic, subject and description are required. Attachments are not: plenty
  /// of issues have nothing to photograph — a payout that has not arrived, a
  /// charge someone disputes — and forcing a file there means attaching
  /// something irrelevant to get past the form, or giving up and phoning.
  Map<String, String> _validate() {
    final subjectText = subject.text.trim();
    final messageText = message.text.trim();
    return {
        // Whatever the chosen topic itself demands. Not ours to guess — a topic
      // can require "Account Name", and create fails without it.
      for (final field in collectableFields)
        if (field.required && (_customFieldAnswers[field.name] ?? '').isEmpty)
          field.name: '${field.label} is required',
      if (subjectText.isEmpty)
        'subject': 'Subject is required'
      else if (subjectText.length > kSubjectMaxLength)
        'subject': 'Keep the subject under $kSubjectMaxLength characters',
      if (messageText.isEmpty)
        'message': 'Description is required'
      else if (messageText.length > kMessageMaxLength)
        'message': 'Keep the description under $kMessageMaxLength characters',
    };
  }

  // --- Submit --------------------------------------------------------------

  /// Raises the ticket, then uploads any attachments.
  ///
  /// Returns the ticket on success and null on every failure. Failures arrive
  /// through [onError] as a message for a toast, except rejected fields, which
  /// go into [fieldErrors] for the form to show inline — never both, since the
  /// same message in two places reads as two separate problems.
  ///
  /// [onAttachmentsFailed] is a *partial* success: the ticket exists, some file
  /// did not attach.
  Future<SupportTicket?> raise({
    required String screen,
    void Function(String message)? onError,
    void Function(String message)? onAttachmentsFailed,
  }) async {
    if (loading) return null;

    final errors = _validate();
    if (errors.isNotEmpty) {
      _fieldErrors = errors;
      notifyListeners();
      return null;
    }

    _fieldErrors = const {};
    toggleLoadingOn(true);
    try {
      // The create route has no context field, so the diagnostics are appended
      // to the body. Doing it here rather than asking the client to type it is
      // most of what makes this faster than a phone call: the agent sees the
      // screen, build and browser without a round trip.
      final context = await SupportTicketContext.capture(screen: screen);
      final ticket = await api.createTicket(
        topicId: _topic!.id,
        subject: subject.text.trim(),
        message: '${message.text.trim()}\n\n${context.asMessageFooter()}',
        customFields: {..._resolveSilentFields(), ..._customFieldAnswers},
      );

      // Files go up only once the ticket exists, one request each. A failure
      // here must never be reported as a failed ticket: the ticket is already
      // raised, and telling the client otherwise makes them raise a second.
      final failed = await _uploadAttachments(ticket.id);
      if (failed.isNotEmpty) {
        onAttachmentsFailed?.call(
          failed.length == 1
              ? "Ticket raised, but ${failed.first} didn't attach."
              : 'Ticket raised, but ${failed.length} files did not attach.',
        );
      }

      _lastResult = ticket;
      // Only now — a confirmed ticket — is it safe to lose what was typed.
      reset(keepResult: true);
      // Refetch rather than inserting the returned row: the create response is
      // a point-in-time snapshot, and a status or SLA the server applies on
      // creation would leave the list showing something the ticket is not.
      // Deliberately not awaited — the client should see their confirmation
      // now, not after a second round trip.
      loadTickets(force: true);
      return ticket;
    } on SupportTicketException catch (e) {
      if (e.isValidationFailure && e.fields.isNotEmpty) {
        // The server keys these inconsistently: by field name for some
        // failures, by numeric field id for others — a missing required custom
        // field comes back as {"57": [...]}, and 57 matches no widget on this
        // form. Anything that cannot be placed goes to a toast, or the client
        // sees a rejected submit with nothing on screen explaining it.
        final known = {
          'subject',
          'message',
          for (final field in _topicFields) field.name,
        };
        final inline = <String, String>{};
        final unplaceable = <String>[];
        for (final entry in e.fields.entries) {
          if (known.contains(entry.key)) {
            inline[entry.key] = entry.value;
          } else if (entry.value.trim().isNotEmpty) {
            unplaceable.add(entry.value.trim());
          }
        }
        if (inline.isNotEmpty) {
          _fieldErrors = inline;
          notifyListeners();
        }
        if (unplaceable.isNotEmpty) onError?.call(unplaceable.join(' '));
        if (inline.isNotEmpty || unplaceable.isNotEmpty) return null;
      }
      onError?.call(e.message);
      return null;
    } catch (_) {
      onError?.call("Couldn't raise this — please try again.");
      return null;
    } finally {
      toggleLoadingOn(false);
    }
  }

  /// Uploads every attached file, returning the names that did not make it.
  ///
  /// One request each, because the route takes a single `file` part. Sequential
  /// rather than concurrent: osTicket writes a thread message per upload, and
  /// firing several at once produces them out of order.
  Future<List<String>> _uploadAttachments(int ticketId) async {
    final failed = <String>[];
    for (final file in _attachments) {
      final bytes = file.bytes;
      if (bytes == null) {
        failed.add(file.name);
        continue;
      }
      try {
        await api.uploadTicketAttachment(
          ticketId,
          bytes: bytes,
          filename: file.name,
        );
      } catch (_) {
        failed.add(file.name);
      }
    }
    return failed;
  }

  // --- Reset ---------------------------------------------------------------

  /// Clears the form. [keepResult] retains the raised ticket so the success
  /// state can still name its number.
  ///
  /// [topics] survives: it is reference data, not form input, and refetching it
  /// on every open costs a round trip for a list that rarely changes.
  void reset({bool keepResult = false}) {
    subject.clear();
    message.clear();
    // [kFixedTopic] is not cleared: it is not a choice the client made, and
    // clearing it would leave the next create with no topic to raise against.
    _topicFields = const [];
    _formError = null;
    _customFieldAnswers.clear();
    _disposeFieldControllers();
    _attachments.clear();
    _fieldErrors = const {};
    if (!keepResult) _lastResult = null;
    notifyListeners();
  }

  /// Leaves the success state and returns to an empty form.
  void raiseAnother() {
    _lastResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    reply.dispose();
    _disposeFieldControllers();
    super.dispose();
  }
}
