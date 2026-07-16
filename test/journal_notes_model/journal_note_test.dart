import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/models/desk_reports_model/calender_pnl_model.dart';
import 'package:mynt_plus/models/journal_notes_model/journal_note.dart';
import 'package:mynt_plus/models/journal_notes_model/segment_group.dart';

void main() {
  group('toIso8601WithOffset', () {
    test('emits an explicit offset, which toIso8601String() cannot', () {
      final dt = DateTime(2026, 7, 15, 18, 30, 0);
      final formatted = toIso8601WithOffset(dt);

      // The shape the API documents: 2026-07-15T18:30:00+05:30
      expect(
        formatted,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$')),
      );
      expect(formatted, startsWith('2026-07-15T18:30:00'));
      // The bug this function exists to avoid.
      expect(dt.toIso8601String(), isNot(contains('+')));
    });

    test('drops sub-second precision', () {
      final dt = DateTime(2026, 7, 15, 18, 30, 0, 436, 361);
      expect(toIso8601WithOffset(dt), isNot(contains('.')));
    });

    test('round-trips back to the same instant', () {
      final dt = DateTime(2026, 7, 15, 18, 30, 0);
      final parsed = DateTime.parse(toIso8601WithOffset(dt));
      expect(parsed.isAtSameMomentAs(dt), isTrue);
    });

    test('a UTC input is converted to local, not labelled +00:00', () {
      final utc = DateTime.utc(2026, 7, 15, 13, 0, 0);
      final formatted = toIso8601WithOffset(utc);
      expect(DateTime.parse(formatted).isAtSameMomentAs(utc), isTrue);
    });
  });

  group('kNoteDatePattern', () {
    test('accepts the notes API format', () {
      expect(kNoteDatePattern.hasMatch('2026-07-14'), isTrue);
    });

    test('rejects the DD/MM/YYYY the P&L endpoints use', () {
      // Sending this is a 400 BAD_DATE — the documented footgun of having two
      // date formats against one host.
      expect(kNoteDatePattern.hasMatch('14/07/2026'), isFalse);
    });

    test('rejects the "unknown" dateWise key', () {
      // getJournalDiary3 returns a literal "unknown" key holding trades whose
      // dates could not be parsed. It is not a date.
      expect(kNoteDatePattern.hasMatch('unknown'), isFalse);
    });
  });

  group('SegmentGroup', () {
    test('maps every P&L Summary tab label', () {
      expect(SegmentGroup.fromTabLabel('Equity'), SegmentGroup.equity);
      expect(SegmentGroup.fromTabLabel('FNO'), SegmentGroup.fno);
      expect(SegmentGroup.fromTabLabel('Commodity'), SegmentGroup.commodity);
      expect(SegmentGroup.fromTabLabel('Currency'), SegmentGroup.currency);
    });

    test('returns null for an unknown label rather than defaulting', () {
      // getcalenderpnldata's ternary chain treats Currency as its else branch,
      // so an unknown label silently gets currency COCD codes. Not repeated here.
      expect(SegmentGroup.fromTabLabel('Nonsense'), isNull);
      expect(SegmentGroup.fromTabLabel(''), isNull);
    });

    test('cocd scopes match what the ledger API sends', () {
      expect(SegmentGroup.equity.cocdScope, 'NSE_CASH,BSE_CASH');
      expect(SegmentGroup.fno.cocdScope, 'NSE_FNO,BSE_FNO');
      expect(SegmentGroup.commodity.cocdScope, 'MCX,NCDEX,NSE_COM,BSE_COM');
      expect(SegmentGroup.currency.cocdScope, 'CD_NSE,CD_BSE,CD_MCX,CD_USE');
    });

    test('only commodity uses getJournalDiary3', () {
      expect(SegmentGroup.commodity.usesJournalDiary3, isTrue);
      expect(SegmentGroup.equity.usesJournalDiary3, isFalse);
      expect(SegmentGroup.fno.usesJournalDiary3, isFalse);
      expect(SegmentGroup.currency.usesJournalDiary3, isFalse);
    });
  });

  group('NotePnlSnapshot', () {
    test('fromJournalRow reads the backend rollup, not the folded trades', () {
      final row = Journal(
        tRADEDATE: '2026-07-14T00:00:00',
        realisedpnl: '-4200.5',
        unrealisedpnl: '0',
        totalBillNet: '-4310.2',
      );
      final pnl = NotePnlSnapshot.fromJournalRow(row, SegmentGroup.fno);

      expect(pnl.realised, -4200.5);
      expect(pnl.unrealised, 0);
      expect(pnl.cocdScope, 'NSE_FNO,BSE_FNO');
    });

    test('fromDateWise reads commodity unrealised, which journal[] zeroes', () {
      // CalenderpnlModel synthesises commodity journal[] rows with
      // unrealisedpnl hardcoded to '0'; dateWise is the only real source.
      final day = {'realised_pnl': -4200.5, 'total_unrealized_pnl': 300.0};
      final pnl = NotePnlSnapshot.fromDateWise(day, SegmentGroup.commodity);

      expect(pnl.realised, -4200.5);
      expect(pnl.unrealised, 300.0);
      expect(pnl.cocdScope, 'MCX,NCDEX,NSE_COM,BSE_COM');
    });

    test('serialises money as JSON numbers, not strings', () {
      final json = const NotePnlSnapshot(
        realised: -4200.5,
        unrealised: 0,
        cocdScope: 'NSE_FNO,BSE_FNO',
      ).toJson();

      expect(json['realised'], isA<num>());
      expect(json['realised'], -4200.5);
      expect(json['unrealised'], isA<num>());
    });

    test('omits snapshot_at when absent so the server defaults it', () {
      final json = const NotePnlSnapshot(realised: 1).toJson();
      expect(json.containsKey('snapshot_at'), isFalse);
    });

    test('round-trips through the response shape', () {
      final parsed = NotePnlSnapshot.fromJson({
        'realised': -4200.5,
        'unrealised': 0.0,
        'snapshot_at': '2026-07-15T18:30:00+05:30',
        'cocd_scope': 'NSE_FNO,BSE_FNO',
      });

      expect(parsed.realised, -4200.5);
      expect(parsed.cocdScope, 'NSE_FNO,BSE_FNO');
      expect(parsed.snapshotAt, isNotNull);
      expect(parsed.total, -4200.5);
    });

    test('tolerates a null cocd_scope', () {
      final parsed = NotePnlSnapshot.fromJson({
        'realised': -2000.0,
        'unrealised': 0.0,
        'snapshot_at': '2026-07-01T18:30:00+05:30',
        'cocd_scope': null,
      });
      expect(parsed.cocdScope, isNull);
    });
  });

  group('JournalNote', () {
    // The captured 201 response from the spec.
    final saveResponse = {
      'note_id': 1,
      'note_date': '2026-07-14',
      'segment_group': 'fno',
      'title': 'Revenge traded after the morning loss',
      'comment': 'Took 3 unplanned BANKNIFTY entries after being stopped out.',
      'pnl': {
        'realised': -4200.5,
        'unrealised': 0.0,
        'snapshot_at': '2026-07-15T18:30:00+05:30',
        'cocd_scope': 'NSE_FNO,BSE_FNO',
      },
      'tags': [],
      'created_at': '2026-07-15T19:25:59.436361+05:30',
      'updated_at': '2026-07-15T19:25:59.436361+05:30',
    };

    test('parses a real save response', () {
      final note = JournalNote.fromJson(saveResponse);

      expect(note.noteId, 1);
      expect(note.noteDate, '2026-07-14');
      expect(note.segmentGroup, SegmentGroup.fno);
      expect(note.title, 'Revenge traded after the morning loss');
      expect(note.pnl?.realised, -4200.5);
      expect(note.tags, isEmpty);
      expect(note.createdAt, isNotNull);
    });

    test('parses a note with tags', () {
      final note = JournalNote.fromJson({
        ...saveResponse,
        'tags': [
          {'tag_id': 1, 'name': 'revenge-trade', 'color': '#CC3344'},
        ],
      });

      expect(note.tags, hasLength(1));
      expect(note.tags.first.name, 'revenge-trade');
      expect(note.tags.first.color, '#CC3344');
    });

    test('a note with no snapshot parses with a null pnl, not a zeroed one', () {
      // Such a note is excluded from analytics entirely — not counted as zero.
      final note = JournalNote.fromJson({...saveResponse, 'pnl': null});
      expect(note.pnl, isNull);
    });

    test('flags a snapshot taken on the note date as provisional', () {
      // Saved intraday, before the day settled — the stored P&L is unsettled
      // and is never refreshed.
      final note = JournalNote.fromJson({
        ...saveResponse,
        'note_date': '2026-07-15',
        'pnl': {
          'realised': -100.0,
          'unrealised': 0.0,
          'snapshot_at': '2026-07-15T11:00:00+05:30',
        },
      });
      expect(note.hasProvisionalSnapshot, isTrue);
    });

    test('a snapshot taken after the close is not provisional', () {
      final note = JournalNote.fromJson(saveResponse); // 07-14 note, 07-15 snap
      expect(note.hasProvisionalSnapshot, isFalse);
    });

    test('a note with no snapshot is not provisional', () {
      final note = JournalNote.fromJson({...saveResponse, 'pnl': null});
      expect(note.hasProvisionalSnapshot, isFalse);
    });

    test('parses the attachments array now returned on every note object', () {
      // The backend serializer now includes attachments[] on save/get/list —
      // the exact shape captured in §7.2 of the spec.
      final note = JournalNote.fromJson({
        ...saveResponse,
        'attachments': [
          {
            'attachment_id': 'ac19c45f-02ca-4eba-b509-2a5f06b1865b',
            'note_id': 1,
            'filename': 'banknifty-5m.jpg',
            'content_type': 'image/jpeg',
            'byte_size': 996,
            'sha256': '2ca16c29',
            'created_at': '2026-07-16T14:39:50+05:30',
          },
        ],
      });

      expect(note.attachments, hasLength(1));
      final a = note.attachments.first;
      expect(a.attachmentId, 'ac19c45f-02ca-4eba-b509-2a5f06b1865b');
      expect(a.filename, 'banknifty-5m.jpg');
      expect(a.isImage, isTrue);
      expect(a.isPdf, isFalse);
      // byte_size is the STORED size after re-encode, not what was uploaded.
      expect(a.byteSize, 996);
    });

    test('a note with no attachments parses to an empty list, not null', () {
      final note = JournalNote.fromJson(saveResponse); // no attachments key
      expect(note.attachments, isEmpty);
    });

    test('distinguishes a PDF attachment from an image', () {
      final note = JournalNote.fromJson({
        ...saveResponse,
        'attachments': [
          {
            'attachment_id': 'p1',
            'note_id': 1,
            'filename': 'contract.pdf',
            'content_type': 'application/pdf',
            'byte_size': 4200,
          },
        ],
      });
      expect(note.attachments.single.isPdf, isTrue);
      expect(note.attachments.single.isImage, isFalse);
    });
  });

  group('NoteListResult', () {
    test('parses a real list response and indexes by date', () {
      final result = NoteListResult.fromJson({
        'notes': [
          {
            'note_id': 7,
            'note_date': '2026-06-05',
            'segment_group': 'fno',
            'title': 'Day 5',
            'comment': 'auto',
            'pnl': {
              'realised': -2000.0,
              'unrealised': 0.0,
              'snapshot_at': '2026-07-01T18:30:00+05:30',
              'cocd_scope': null,
            },
            'tags': [
              {'tag_id': 1, 'name': 'revenge-trade', 'color': '#CC3344'},
            ],
          },
        ],
        'total': 5,
        'limit': 3,
        'offset': 0,
      });

      expect(result.notes, hasLength(1));
      // total is the unpaginated count, not notes.length — it drives pagination.
      expect(result.total, 5);
      expect(result.byDate['2026-06-05']?.noteId, 7);
    });

    test('an empty result is a valid success, not an error', () {
      final result = NoteListResult.fromJson({'notes': [], 'total': 0});
      expect(result.notes, isEmpty);
      expect(result.total, 0);
      expect(result.byDate, isEmpty);
    });
  });
}
