/// Rules for the two free-text fields on "Raise a Ticket".
///
/// Kept as pure functions outside the provider on purpose. The support desk's
/// complaint is about what actually reaches them — chat-length subjects, a
/// description that says "not working" and nothing else — so the rules that
/// decide what may be sent are worth asserting directly rather than only
/// through a screen that needs a locator to build.
///
/// Ported from mobile so the two apps reject the same text. A rule that holds
/// on one platform and not the other is worse than no rule: the desk still
/// gets the junk ticket, and the client who was stopped on mobile learns to
/// raise it on web instead.
library;

/// The floors and caps the form enforces.
///
/// The floors are deliberately modest: enough to stop a one-word ticket, low
/// enough that a genuinely simple report ("Unable to log in with the correct
/// password") still goes through in one attempt.
///
/// Both caps are shown live beside the field, so the number the client
/// watches and the number the field enforces are the same constant.
class TicketTextRules {
  const TicketTextRules._();

  static const int subjectMinLength = 10;
  static const int subjectMinWords = 2;
  static const int subjectMaxLength = 120;

  static const int descriptionMinLength = 40;
  static const int descriptionMinWords = 6;
  static const int descriptionMaxLength = 1000;
}

final RegExp _nonWord = RegExp(r'[^A-Za-z0-9]+');
final RegExp _letter = RegExp(r'[A-Za-z]');

List<String> _words(String raw) =>
    raw.trim().split(_nonWord).where((w) => w.isNotEmpty).toList();

/// Words in [raw], counting anything separated by punctuation or space.
int ticketWordCount(String raw) => _words(raw).length;

/// [raw] reduced to lowercase words joined by single spaces, so "Not
/// working!!!" and "not working" are the same phrase to the filler check.
String ticketNormalisedText(String raw) => _words(raw).join(' ').toLowerCase();

/// Openers and one-liners that pass a length check but tell an agent nothing.
///
/// Matched whole, never as a prefix: "Not working" is a wasted ticket, while
/// "Not working since the 3.1 update on Chrome" is a real one and must not be
/// caught by the same rule.
const Set<String> _uninformativePhrases = {
  'hi', 'hii', 'hiii', 'hello', 'hey', 'sir', 'dear sir', 'hi sir',
  'hello sir', 'madam', 'good morning', 'good evening',
  'help', 'help me', 'need help', 'please help', 'pls help', 'plz help',
  'kindly help', 'help please', 'support', 'need support', 'i need help',
  'issue', 'issues', 'my issue', 'some issue', 'an issue', 'app issue',
  'problem', 'problems', 'my problem', 'app problem', 'error', 'errors',
  'query', 'my query', 'doubt', 'my doubt', 'question', 'complaint',
  'urgent', 'very urgent', 'urgent issue', 'urgent help',
  'not working', 'its not working', 'it is not working', 'app not working',
  'not working properly', 'app not opening', 'app is not working',
  'not able', 'unable', 'not able to do', 'not opening',
  'please check', 'pls check', 'kindly check', 'check this', 'check it',
  'please look into this', 'kindly look into it',
  'please call', 'call me', 'please call me', 'kindly call me', 'call back',
  'please call back', 'contact me',
  'please resolve', 'kindly resolve', 'resolve this', 'fix this',
  'please do the needful', 'do the needful', 'needful',
  'test', 'testing', 'na', 'nil', 'none', 'nothing', 'asdf', 'asdfgh',
  'abcd', 'xyz', 'ok', 'okay', 'yes', 'no',
};

/// True when [raw] is one of the stock openers above, or carries no letters at
/// all ("......", "1234") and so cannot be describing anything.
bool isUninformativeTicketText(String raw) {
  final normalised = ticketNormalisedText(raw);
  if (normalised.isEmpty) return true;
  if (!_letter.hasMatch(normalised)) return true;
  return _uninformativePhrases.contains(normalised);
}

/// The problem with the subject as typed, or null when it may be sent.
String? validateTicketSubject(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return 'Enter a subject';
  if (isUninformativeTicketText(v)) {
    return 'Too general — say what the issue is about';
  }
  if (v.length < TicketTextRules.subjectMinLength ||
      ticketWordCount(v) < TicketTextRules.subjectMinWords) {
    return 'Add a few more words '
        '(at least ${TicketTextRules.subjectMinLength} characters)';
  }
  return null;
}

/// The problem with the description as typed, or null when it may be sent.
String? validateTicketDescription(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return 'Describe your issue';
  if (isUninformativeTicketText(v)) {
    return 'Tell us what you did and what happened';
  }
  if (v.length < TicketTextRules.descriptionMinLength ||
      ticketWordCount(v) < TicketTextRules.descriptionMinWords) {
    return 'Add more detail '
        '(at least ${TicketTextRules.descriptionMinLength} characters)';
  }
  return null;
}

/// The live line under the description while it is still too short.
///
/// Counts what is missing from the floor rather than what is left of the cap:
/// the counter beside it already shows the cap, and what stalls a ticket is
/// too little detail, not too much. Returns null once there is enough, leaving
/// the short static hint in place.
String? ticketDescriptionProgress(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  final short = TicketTextRules.descriptionMinLength - v.length;
  if (short > 0) return '$short more character${short == 1 ? '' : 's'}';
  final missingWords = TicketTextRules.descriptionMinWords - ticketWordCount(v);
  if (missingWords > 0) {
    return '$missingWords more word${missingWords == 1 ? '' : 's'}';
  }
  return null;
}
