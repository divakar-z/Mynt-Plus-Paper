import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/insta_options/insta_options_api.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/buildup_row.dart';
import 'package:mynt_plus/models/insta_options/selection.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';

final instaOptionsBuildupProvider =
    ChangeNotifierProvider((ref) => InstaOptionsBuildupProvider(ref));

enum BuildupFilter { all, ce, pe, fut }

enum BuildupSort { oiChangeDesc, strikeAsc }

class InstaOptionsBuildupProvider extends DefaultChangeNotifier {
  final InstaOptionsApi _api = locator<InstaOptionsApi>();
  final Ref ref;

  List<BuildupRow> _rows = const [];
  String? _error;
  InstaOptionsSelection? _lastLoaded;

  BuildupFilter _filter = BuildupFilter.all;
  BuildupSort _sort = BuildupSort.oiChangeDesc;

  InstaOptionsBuildupProvider(this.ref) {
    ref.listen<InstaOptionsSelectionProvider>(
      instaOptionsSelectionProvider,
      (_, next) => _maybeFetch(next.selection),
      fireImmediately: true,
    );
  }

  List<BuildupRow> get rows => _rows;
  String? get error => _error;
  BuildupFilter get filter => _filter;
  BuildupSort get sort => _sort;

  /// Visible rows after filter + sort.
  List<BuildupRow> get visible {
    final filtered = _rows.where((r) {
      switch (_filter) {
        case BuildupFilter.all:
          return true;
        case BuildupFilter.ce:
          return r.isCe;
        case BuildupFilter.pe:
          return r.isPe;
        case BuildupFilter.fut:
          return r.isFut;
      }
    }).toList();
    switch (_sort) {
      case BuildupSort.oiChangeDesc:
        filtered.sort((a, b) => b.oiChange.abs().compareTo(a.oiChange.abs()));
        break;
      case BuildupSort.strikeAsc:
        filtered.sort((a, b) => a.strike.compareTo(b.strike));
        break;
    }
    return filtered;
  }

  void setFilter(BuildupFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  void setSort(BuildupSort s) {
    if (_sort == s) return;
    _sort = s;
    notifyListeners();
  }

  Future<void> refresh() async {
    final sel = ref.read(instaOptionsSelectionProvider).selection;
    await _fetch(sel, force: true);
  }

  Future<void> _maybeFetch(InstaOptionsSelection sel) async {
    if (sel.expiry.isEmpty) return;
    final same = _lastLoaded != null &&
        _lastLoaded!.exchange == sel.exchange &&
        _lastLoaded!.symbol == sel.symbol &&
        _lastLoaded!.expiry == sel.expiry;
    if (same) return;
    await _fetch(sel);
  }

  Future<void> _fetch(InstaOptionsSelection sel, {bool force = false}) async {
    if (loading) return;
    if (sel.expiry.isEmpty) return;
    loading = true;
    _error = null;
    notifyListeners();
    try {
      _rows = await _api.getBuildup(
        exchange: sel.exchange,
        symbol: sel.symbol,
        expiry: sel.expiry,
      );
      _lastLoaded = sel;
    } catch (e) {
      _error = e.toString();
      if (force) _rows = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
