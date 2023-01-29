import 'dart:collection';

import 'package:davi/src/column.dart';
import 'package:davi/src/sort.dart';
import 'package:davi/src/sort_callback_typedef.dart';
import 'package:davi/src/sort_direction.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// The [Davi] model.
///
/// The type [DATA] represents the data of each row.
class DaviModel<DATA> extends ChangeNotifier {
  DaviModel(
      {List<DATA> rows = const [],
      List<DaviColumn<DATA>> columns = const [],
      this.ignoreSortFunctions = false,
      this.alwaysSorted = false,
      this.multiSortEnabled = false,
      this.onSort}) {
    _originalRows = List.from(rows);
    addColumns(columns);
    _updateRows(notify: false);
  }

  /// The event that will be triggered at each sorting.
  OnSortCallback<DATA>? onSort;

  final bool multiSortEnabled;

  final List<DaviColumn<DATA>> _columns = [];
  late final List<DATA> _originalRows;

  final List<DaviColumn<DATA>> _sortedColumns = [];

  /// Gets the sorted columns.
  List<DaviColumn<DATA>> get sortedColumns =>
      UnmodifiableListView(_sortedColumns);

  late List<DATA> _rows;

  /// Ignore column sorting functions to maintain the natural order of the data.
  ///
  /// Allows the header to be sortable if the column is also sortable.
  final bool ignoreSortFunctions;

  /// Defines if there will always be some sorted column.
  final bool alwaysSorted;

  bool get _isRowsModifiable => _rows is! UnmodifiableListView;

  int get originalRowsLength => _originalRows.length;

  bool get isOriginalRowsEmpty => _originalRows.isEmpty;

  bool get isOriginalRowsNotEmpty => _originalRows.isNotEmpty;

  int get rowsLength => _rows.length;

  bool get isRowsEmpty => _rows.isEmpty;

  bool get isRowsNotEmpty => _rows.isNotEmpty;

  int get columnsLength => _columns.length;

  bool get isColumnsEmpty => _columns.isEmpty;

  bool get isColumnsNotEmpty => _columns.isNotEmpty;

  DaviColumn<DATA>? _columnInResizing;

  DaviColumn<DATA>? get columnInResizing => _columnInResizing;

  @internal
  set columnInResizing(DaviColumn<DATA>? column) {
    _columnInResizing = column;
    notifyListeners();
  }

  /// Indicates whether the model is sorted.
  bool get isSorted => alwaysSorted || _sortedColumns.isNotEmpty;

  /// Indicates whether the model is sorted by multiple columns.
  bool get isMultiSorted => _sortedColumns.length > 1;

  DATA rowAt(int index) => _rows[index];

  void addRow(DATA row) {
    _originalRows.add(row);
    _updateRows(notify: true);
  }

  void addRows(Iterable<DATA> rows) {
    _originalRows.addAll(rows);
    _updateRows(notify: true);
  }

  /// Remove all rows.
  void removeRows() {
    _originalRows.clear();
    _updateRows(notify: true);
  }

  void replaceRows(Iterable<DATA> rows) {
    _originalRows.clear();
    _originalRows.addAll(rows);
    _updateRows(notify: true);
  }

  void removeRowAt(int index) {
    if (_isRowsModifiable) {
      DATA row = _rows.removeAt(index);
      _originalRows.remove(row);
    } else {
      _originalRows.removeAt(index);
    }
    notifyListeners();
  }

  void removeRow(DATA row) {
    _originalRows.remove(row);
    if (_isRowsModifiable) {
      _rows.remove(row);
    }
    notifyListeners();
  }

  DaviColumn<DATA> columnAt(int index) => _columns[index];

  /// Gets a column given an [id]. If [id] is [NULL], no columns are returned.
  DaviColumn<DATA>? getColumn(dynamic id) {
    if (id != null) {
      for (DaviColumn<DATA> column in _columns) {
        if (column.id == id) {
          return column;
        }
      }
    }
    return null;
  }

  void addColumn(DaviColumn<DATA> column) {
    _columns.add(column);
    column.addListener(notifyListeners);
    _ensureSortIfNeeded();
    notifyListeners();
  }

  void addColumns(Iterable<DaviColumn<DATA>> columns) {
    for (DaviColumn<DATA> column in columns) {
      _columns.add(column);
      column.addListener(notifyListeners);
    }
    _ensureSortIfNeeded();
    notifyListeners();
  }

  /// Remove all columns.
  void removeColumns() {
    _columns.clear();
    _sortedColumns.clear();
    _columnInResizing = null;
    _updateRows(notify: true);
  }

  void _updateSortPriorities() {
    int priority = 1;
    for (DaviColumn<DATA> column in _sortedColumns) {
      column._sortPriority = priority++;
    }
  }

  void removeColumnAt(int index) {
    DaviColumn<DATA> column = _columns[index];
    removeColumn(column);
  }

  void removeColumn(DaviColumn<DATA> column) {
    if (_columns.remove(column)) {
      column.removeListener(notifyListeners);
      if (_columnInResizing == column) {
        _columnInResizing = null;
      }
      if (_sortedColumns.remove(column)) {
        column._clearSortData();
        _updateSortPriorities();
        _updateRows(notify: false);
      }
      notifyListeners();
    }
  }

  void _notifyOnSort() {
    if (onSort != null) {
      onSort!(sortedColumns);
    }
  }

  /// Revert to original sort order
  void clearSort() {
    _sortedColumns.clear();
    _clearColumnsSortData();
    _ensureSortIfNeeded();
    _updateRows(notify: true);
    _notifyOnSort();
  }

  void _clearColumnsSortData() {
    for (DaviColumn<DATA> column in _columns) {
      column._clearSortData();
    }
  }

  /// Defines the columns that will be used in sorting.
  ///
  /// If multi sorting is disabled, only the first one in the list will be used.
  void sort(List<DaviSort> sortList) {
    _sortedColumns.clear();
    _clearColumnsSortData();
    for (DaviSort sort in sortList) {
      DaviColumn<DATA>? column = getColumn(sort.id);
      if (column != null &&
          column.sortable &&
          (column.sort != null || ignoreSortFunctions)) {
        column._direction = sort.direction;
        _sortedColumns.add(column);
        if (!multiSortEnabled) {
          // ignoring other columns
          break;
        }
      }
    }
    _ensureSortIfNeeded();
    _updateSortPriorities();
    _updateRows(notify: true);
    _notifyOnSort();
  }

  void _ensureSortIfNeeded() {
    if (alwaysSorted && _sortedColumns.isEmpty && _columns.isNotEmpty) {
      DaviColumn<DATA> column = _columns.first;
      column._direction = DaviSortDirection.ascending;
      _sortedColumns.add(column);
    }
  }

  /// Notifies any data update by calling all the registered listeners.
  void notifyUpdate() {
    notifyListeners();
  }

  /// Updates the visible rows given the sorts and filters.
  void _updateRows({required bool notify}) {
    if (isSorted && !ignoreSortFunctions) {
      List<DATA> list = List.from(_originalRows);
      list.sort(_compoundSort);
      _rows = list;
    } else {
      _rows = UnmodifiableListView(_originalRows);
    }
    if (notify) {
      notifyListeners();
    }
  }

  /// Function to realize the multi sort.
  int _compoundSort(DATA a, DATA b) {
    int r = 0;
    for (int i = 0; i < _sortedColumns.length; i++) {
      final DaviColumn<DATA> column = _sortedColumns[i];
      if (column.sort != null && column.direction != null) {
        final DaviDataComparator<DATA> sort = column.sort!;
        final DaviSortDirection direction = column.direction!;

        if (direction == DaviSortDirection.descending) {
          r = sort(b, a, column);
        } else {
          r = sort(a, b, column);
        }
        if (r != 0) {
          break;
        }
      }
    }
    return r;
  }
}

mixin ColumnSortMixin {
  int? _sortPriority;

  int? get sortPriority => _sortPriority;
  DaviSortDirection? _direction;

  DaviSortDirection? get direction => _direction;

  void _clearSortData() {
    _sortPriority = null;
    _direction = null;
  }

  bool get isSorted => _direction != null;
}
