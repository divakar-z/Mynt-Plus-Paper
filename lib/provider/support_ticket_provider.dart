import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/support_ticket_model/support_html.dart';
import '../models/support_ticket_model/support_ticket.dart';
import '../models/support_ticket_model/support_ticket_context.dart';
import '../models/support_ticket_model/support_ticket_exception.dart';
import '../models/support_ticket_model/support_ticket_validation.dart';
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
  ///
  /// Forwarded from [TicketTextRules], which also carries the floors, so the
  /// screen has one place to read a limit from and the rules cannot drift —
  /// nor drift from mobile, which reads the same numbers.
  static const int kSubjectMaxLength = TicketTextRules.subjectMaxLength;
  static const int kMessageMaxLength = TicketTextRules.descriptionMaxLength;

  /// Largest single attachment.
  static const int kAttachmentMaxBytes = 8 * 1024 * 1024;

  /// How many files one ticket may carry.
  static const int kAttachmentMaxCount = 20;

  /// `8 MB` — used in limit messages so they cannot drift from the caps.
  static String formatMb(int bytes) =>
      '${(bytes / (1024 * 1024)).round()} MB';

  // --- The create form -----------------------------------------------------

  // Was: a hard-coded General topic, posted as `topic_id: 1`.
  //
  // static const SupportTopic kFixedTopic =
  //     SupportTopic(id: 1, name: 'General');
  //
  // Retired — the server now files every ticket raised from the app under
  // General itself and ignores a `topic_id` that arrives. Pinning the id here
  // meant a rename or re-number in the admin panel would have failed every
  // create with nothing on screen to explain it.

  /// Fields the form fills in silently, or drops, rather than asking for.
  ///
  ///  * `clientid` — the signed-in trading code, taken from [Preferences] and
  ///    never typed. An agent triaging the queue reads the field on the ticket,
  ///    not the session behind it, so the code has to be on the ticket itself.
  ///    (Previously left blank on the reasoning that the session already
  ///    identified the requester; it reached the desk empty. Mobile fills it.)
  ///  * `products` — the server sets it to General on every ticket and no
  ///    longer returns it on the form. Filtered anyway, so an install that
  ///    still offers it cannot put a dead one-option picker on the screen.
  ///
  /// Compared lower-cased: field names come from the admin panel, where the
  /// same field is as likely to be `ClientID` as `clientid`.
  static const Set<String> _silentFields = {'clientid', productFieldName};

  /// What the client is actually asked to fill.
  ///
  /// The category comes first: it is the one filing decision the client makes
  /// and it belongs above the free text, whatever order the admin panel happens
  /// to return the fields in. Anything else the form defines is still rendered
  /// after it, so an admin adding a required field does not silently start
  /// failing every create.
  List<SupportTicketField> get collectableFields {
    final fields = _topicFields
        .where(
            (f) => f.editable && !_silentFields.contains(f.name.toLowerCase()))
        .toList();
    final subIssue = fields.indexWhere(_isSubIssue);
    if (subIssue > 0) fields.insert(0, fields.removeAt(subIssue));
    return fields;
  }

  static bool _isSubIssue(SupportTicketField field) =>
      field.name.trim().toLowerCase() == subIssueFieldName;

  /// The category picker, or null while the form is still loading or if this
  /// install does not offer one.
  ///
  /// Read rather than assumed: its label, whether it is required and every one
  /// of its options live in the admin panel, and support changes them with no
  /// release on our side.
  SupportTicketField? get subIssueField {
    for (final field in _topicFields) {
      if (_isSubIssue(field) && field.editable) return field;
    }
    return null;
  }

  /// The chosen category's **key** — what `POST /tickets` takes — or `''`.
  String get selectedSubIssueKey {
    final field = subIssueField;
    if (field == null) return '';
    return (_customFieldAnswers[field.name] ?? '').trim();
  }

  /// The chosen category's label, for the picker to display. Null when nothing
  /// is chosen, or when the stored key is no longer one the form offers — a
  /// stale key must read as "not chosen" rather than blank-looking.
  String? get selectedSubIssueLabel {
    final key = selectedSubIssueKey;
    if (key.isEmpty) return null;
    final label = subIssueField?.choices?[key];
    return (label == null || label.trim().isEmpty) ? null : label;
  }

  /// What to print above a field.
  ///
  /// The category is shown as [subIssueDisplayLabel] rather than the helpdesk's
  /// own "Sub Issue Categories": the client never sees the topic it sits under,
  /// so to them it is just the category. Every other field keeps the label the
  /// admin panel gave it.
  String fieldLabel(SupportTicketField field) => _isSubIssue(field)
      ? subIssueDisplayLabel
      : (field.label.isEmpty ? field.name : field.label);

  /// Whether a field must be answered before the ticket can be sent.
  ///
  /// The category is mandatory here **whatever the form says**. The install
  /// marks it optional, which lets every ticket arrive with no category at all
  /// and land on the desk as one undifferentiated pile — the thing this picker
  /// exists to stop. Being stricter than the API is safe in this direction: a
  /// ticket that carries a category is always accepted.
  bool fieldRequired(SupportTicketField field) =>
      field.required || _isSubIssue(field);

  /// Chooses the category by its choice key. No-op when the form offers no
  /// category field, so a caller never has to check first.
  void selectSubIssue(String choiceKey) {
    final field = subIssueField;
    if (field == null) return;
    setCustomField(field.name, choiceKey);
  }

  /// Set when the server refused the category that was sent — a key that went
  /// stale while the form was open. Shown against the picker, which by then has
  /// been refetched, so the client picks again from the current list.
  String? _subIssueError;
  String? get subIssueError => _subIssueError;

  // Was: the help-topic list and the client's chosen topic.
  //
  // List<SupportTopic> _topics = const [];
  // List<SupportTopic> get topics => _topics;
  // SupportTopic? _topic;
  // SupportTopic? get topic => _topic;
  //
  // Retired with the topic picker — the server chooses the topic now. Kept as
  // comments because re-exposing the picker is otherwise a rewrite rather than
  // an un-comment.

  /// The create form's fields, from `GET /tickets/form`. They are defined in
  /// the admin panel and change without a release, so they are always rendered
  /// from this list and never hard-coded.
  ///
  /// There is no topic or product picker: the server files every ticket under
  /// General / General and the client's only filing choice is the category,
  /// which is one of these fields — see [subIssueField].
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

  // Was: a separate flag for the topic-list fetch, which no longer happens.
  //
  // bool _loadingTopics = false;
  // bool get loadingTopics => _loadingTopics;

  /// True while the create form is in flight.
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
        // Same store, same rules as create: HTML in, so the client's line
        // breaks need converting and their text needs escaping.
        // await api.replyToTicket(id, text);
        await api.replyToTicket(id, supportTextToHtml(text));
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

  // --- The create form -----------------------------------------------------

  /// Bumped on every fetch so a slow response cannot overwrite a newer one.
  ///
  /// Two fetches can be in flight at once: the retry link and the refetch that
  /// follows a rejected category both start one, and without this the older
  /// answer wins whenever it happens to land second.
  int _formGeneration = 0;

  /// Fetches the create form — the category picker and anything else the admin
  /// panel defines.
  ///
  /// No topic is passed and none is chosen: the server files under General and
  /// answers with General's own fields. There is deliberately NO hard-coded
  /// fallback list of categories; a made-up choice key is a `422` that would
  /// fail the create, so when the fetch fails the form says so and the picker
  /// stays empty.
  ///
  /// [force] refetches a form that is already held — what the retry link and
  /// the stale-category recovery need. Without it an open dialog would keep
  /// showing the list it opened with.
  ///
  /// This is also what establishes the support session, since it is the first
  /// authenticated call: the exchange happens underneath it.
  Future<void> loadFormFields({
    void Function(String message)? onError,
    bool force = false,
  }) async {
    if (!force && (_topicFields.isNotEmpty || _loadingFields)) return;
    final generation = ++_formGeneration;
    _formError = null;
    _subIssueError = null;
    _loadingFields = true;
    notifyListeners();
    try {
      final fetched = await api.fetchTicketForm();
      // A newer fetch started while this was in flight; its answers win.
      if (generation != _formGeneration) return;
      // The answers go with the old fields. A choice key the refreshed form no
      // longer offers has to leave with it — kept, it sits in the map behind a
      // picker that renders it blank, and only the submit guards stop it being
      // posted. [_refetchFormKeepingText] is what puts back the answers that
      // were never the problem.
      _customFieldAnswers.clear();
      _disposeFieldControllers();
      _topicFields = fetched;
    } on SupportTicketException catch (e) {
      if (generation != _formGeneration) return;
      _formError = e.message;
      onError?.call(e.message);
    } catch (_) {
      if (generation != _formGeneration) return;
      _formError = "Couldn't load the support form.";
      onError?.call("Couldn't load the support form — please try again.");
    } finally {
      if (generation == _formGeneration) {
        _loadingFields = false;
        notifyListeners();
      }
    }
  }

  // Was: loadTopics(), which seeded the hard-coded General topic and fetched
  // `GET /tickets/form?topic_id=1`. Renamed rather than kept as an alias — the
  // name described a call that is not made any more.
  //
  // Future<void> loadTopics({void Function(String message)? onError}) =>
  //     loadFormFields(onError: onError);

  /// Resolves the fields the client is never shown.
  ///
  /// `clientid` is answered from the signed-in session, so the agent opening
  /// the ticket can see whose account it is without asking.
  ///
  /// `products` is not resolved any more and not sent: the server sets it to
  /// General on every ticket. It stays in [_silentFields] only so an install
  /// that still returns the field cannot put a dead one-option picker on the
  /// screen.
  Map<String, String> _resolveSilentFields() {
    final resolved = <String, String>{};
    for (final field in _topicFields) {
      if (!field.editable) continue;
      final name = field.name.toLowerCase();
      if (!_silentFields.contains(name)) continue;
      // Was: the client code is never echoed back into a form field.
      // if (name == 'clientid') continue;
      //
      // Now filled from the signed-in session, matching mobile. Never rendered
      // and never typed, so it cannot be mistyped or pointed at someone else's
      // account. Sent only when the topic offers a plain editable text field
      // for it — a locked or choice-backed key is a 422 that would fail the
      // whole create, and a code is not a valid choice key anyway.
      if (name == 'clientid') {
        final code = (locator<Preferences>().clientId ?? '').trim();
        if (code.isNotEmpty && !field.isChoice) resolved[field.name] = code;
        continue;
      }
      // Was: a single-choice silent field was answered with its only option,
      // which is how `products` used to reach the ticket.
      //
      // final choices = field.choices;
      // if (choices != null && choices.length == 1) {
      //   resolved[field.name] = choices.keys.first;
      // }
      //
      // Dropped — the server assigns the product itself, and posting one it
      // did not ask for is a 422 that fails the whole create.
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
    // A fresh answer clears the "pick one again" notice the server's rejection
    // put up; leaving it would accuse the new choice of the old one's fault.
    if (name.trim().toLowerCase() == subIssueFieldName) _subIssueError = null;
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
  /// Category, subject and description are required. Attachments are not:
  /// plenty of issues have nothing to photograph — a payout that has not
  /// arrived, a charge someone disputes — and forcing a file there means
  /// attaching something irrelevant to get past the form, or giving up and
  /// phoning.
  ///
  /// Both free-text fields have to say something, not merely be filled. The
  /// desk was being handed chat-length tickets — "not working", "please check"
  /// — that cost a round trip before work could even start, so the rules in
  /// [TicketTextRules] are enforced here rather than left to an agent to chase.
  Map<String, String> _validate() => {
        // Whatever the form itself demands, plus the category, which is
        // mandatory even where the install marks it optional — see
        // [fieldRequired].
        for (final field in collectableFields)
          if (fieldRequired(field)) ...{
            if (_answerMissing(field)) field.name: _missingFieldMessage(field),
          },
        if (validateTicketSubject(subject.text) case final error?)
          'subject': error,
        if (validateTicketDescription(message.text) case final error?)
          'message': error,
      };

  /// True when a required field has no usable answer.
  ///
  /// A choice key the refreshed form no longer offers counts as unanswered:
  /// the picker already renders it blank, and sending it would be a 422 for an
  /// option that is not on screen to be corrected.
  bool _answerMissing(SupportTicketField field) {
    final answer = (_customFieldAnswers[field.name] ?? '').trim();
    if (answer.isEmpty) return true;
    return field.isChoice && !(field.choices?.containsKey(answer) ?? false);
  }

  /// "Select a category" for a picker, "Enter account name" for a box.
  ///
  /// Telling someone to enter a dropdown is how a form reads when it was
  /// written against a field list rather than against what is on screen.
  String _missingFieldMessage(SupportTicketField field) {
    final label = fieldLabel(field);
    final what = label.isEmpty
        ? 'a value'
        : '${field.isChoice ? 'a ' : ''}${label.toLowerCase()}';
    return '${field.isChoice ? 'Select' : 'Enter'} $what';
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
        subject: subject.text.trim(),
        // The body is stored and rendered as HTML, so the client's own line
        // breaks need converting too — not just the footer's. Escaped on the
        // way in, or a description containing `<` is interpreted as markup in
        // the agent's console instead of being shown as typed.
        // message: '${message.text.trim()}\n\n${context.asMessageFooter()}',
        message: '${supportTextToHtml(message.text.trim())}<br><br>'
            '${context.asMessageFooter()}',
        customFields: {..._resolveSilentFields(), ..._safeCustomFieldAnswers()},
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
      if (_rejectedSubIssue(e)) {
        // The key went stale while the form was open — support edited the list
        // in the admin panel. Refetching is the only way back: the ticket text
        // is still on screen, so the client picks again and resubmits rather
        // than retyping.
        _subIssueError = 'That option is no longer available. Pick one again.';
        notifyListeners();
        unawaited(_refetchFormKeepingText());
        return null;
      }
      if (e.statusCode == 500) {
        // One cause here is worth naming: General has been disabled or renamed
        // in the admin panel, so there is nowhere to file the ticket. That is
        // not something the client can fix by editing their text, and the raw
        // message would send them round the form looking for a mistake that is
        // not theirs.
        onError?.call('Support is temporarily unavailable. '
            'Please try again later.');
        return null;
      }
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

  /// Only answers the current form still offers.
  ///
  /// Guards the one value the server validates against a list it can change
  /// under us: a choice key the form no longer offers is a 422 that fails the
  /// whole create, so a stale one is dropped rather than sent. A free-text
  /// answer is never dropped — there is no list for it to fall off.
  Map<String, String> _safeCustomFieldAnswers() {
    final byName = {for (final field in _topicFields) field.name: field};
    final out = <String, String>{};
    for (final entry in _customFieldAnswers.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      final field = byName[entry.key];
      if (field != null &&
          field.isChoice &&
          !(field.choices?.containsKey(value) ?? false)) {
        continue;
      }
      out[entry.key] = value;
    }
    return out;
  }

  /// True when the server refused the category itself — a validation failure
  /// whose `fields` names it.
  ///
  /// Narrow on purpose: a rejection of something the client typed must surface
  /// as its own message, not send them back to the picker.
  bool _rejectedSubIssue(SupportTicketException e) =>
      e.isValidationFailure &&
      e.fields.keys.any((k) => k.trim().toLowerCase() == subIssueFieldName);

  /// Refetches the form after the server rejected the category, keeping what
  /// the client wrote.
  ///
  /// [loadFormFields] clears every answer, which for a free-text field the
  /// admin panel defines would throw away typing that was never the problem —
  /// so those answers are put back, and only choices the refreshed form still
  /// offers are restored.
  Future<void> _refetchFormKeepingText() async {
    final previous = Map<String, String>.from(_customFieldAnswers);
    final notice = _subIssueError;
    await loadFormFields(force: true);
    for (final field in _topicFields) {
      final answer = previous[field.name];
      if (answer == null || answer.trim().isEmpty) continue;
      // A choice key is only restored when it is still on offer; the stale one
      // that caused this is exactly what must not come back.
      if (field.isChoice && !(field.choices?.containsKey(answer) ?? false)) {
        continue;
      }
      _customFieldAnswers[field.name] = answer;
      if (!field.isChoice) fieldController(field.name).text = answer;
    }
    _subIssueError = notice;
    notifyListeners();
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
  /// The fields go with it: the category list is not reference data, support
  /// edits it in the admin panel with no release, and the next open refetches
  /// it rather than offering options that may no longer exist.
  void reset({bool keepResult = false}) {
    subject.clear();
    message.clear();
    _topicFields = const [];
    _formError = null;
    _subIssueError = null;
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
