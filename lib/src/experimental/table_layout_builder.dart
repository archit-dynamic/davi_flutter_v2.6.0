import 'dart:math' as math;
import 'package:easy_table/src/cell_style.dart';
import 'package:easy_table/src/column.dart';
import 'package:easy_table/src/experimental/columns_metrics_exp.dart';
import 'package:easy_table/src/experimental/content_area_id.dart';
import 'package:easy_table/src/experimental/table_scroll_bar_exp.dart';
import 'package:easy_table/src/experimental/layout_child.dart';
import 'package:easy_table/src/experimental/table_layout_exp.dart';
import 'package:easy_table/src/experimental/table_layout_settings.dart';
import 'package:easy_table/src/experimental/table_paint_settings.dart';
import 'package:easy_table/src/experimental/table_scroll_controllers.dart';
import 'package:easy_table/src/internal/cell.dart';
import 'package:easy_table/src/internal/columns_metrics.dart';
import 'package:easy_table/src/internal/header_cell.dart';
import 'package:easy_table/src/internal/horizontal_scroll_bar.dart';
import 'package:easy_table/src/model.dart';
import 'package:easy_table/src/row_hover_listener.dart';
import 'package:easy_table/src/theme/header_theme_data.dart';
import 'package:easy_table/src/theme/row_color.dart';
import 'package:easy_table/src/theme/theme.dart';
import 'package:easy_table/src/theme/theme_data.dart';
import 'package:flutter/material.dart';

class TableLayoutBuilder<ROW> extends StatelessWidget {
  const TableLayoutBuilder(
      {Key? key,
      required this.onHoverListener,
      required this.hoveredRowIndex,
      required this.layoutSettings,
      required this.scrollControllers,
      required this.multiSortEnabled,
      required this.model})
      : super(key: key);

  final int? hoveredRowIndex;
  final OnRowHoverListener onHoverListener;
  final TableScrollControllers scrollControllers;
  final TableLayoutSettings layoutSettings;
  final EasyTableModel<ROW>? model;
  final bool multiSortEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _builder);
  }

  Widget _builder(BuildContext context, BoxConstraints constraints) {
    if (!constraints.hasBoundedHeight &&
        layoutSettings.visibleRowsCount == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('EasyTable was given unbounded height.'),
        ErrorDescription(
            'EasyTable already is scrollable in the vertical axis.'),
        ErrorHint(
          'Consider using the "visibleRowsCount" property to limit the height'
          ' or use it in another Widget like Expanded or SliverFillRemaining.',
        ),
      ]);
    }
    if (!constraints.hasBoundedWidth) {
      throw FlutterError('EasyTable was given unbounded width.');
    }

    final EasyTableThemeData theme = EasyTableTheme.of(context);

    TablePaintSettings paintSettings = TablePaintSettings(
        hoveredRowIndex: hoveredRowIndex, hoveredColor: theme.row.hoveredColor);
    if (model != null) {
      return _buildTable(
          context: context,
          constraints: constraints,
          model: model!,
          paintSettings: paintSettings);
    }
    return _buildEmptyTable(
        context: context,
        constraints: constraints,
        paintSettings: paintSettings);
  }

  Widget _buildTable(
      {required BuildContext context,
      required BoxConstraints constraints,
      required EasyTableModel<ROW> model,
      required TablePaintSettings paintSettings}) {
    final EasyTableThemeData theme = EasyTableTheme.of(context);

    ColumnsMetricsExp<ROW> leftPinnedColumnsMetrics = ColumnsMetricsExp.empty();
    ColumnsMetricsExp<ROW> unpinnedColumnsMetrics = ColumnsMetricsExp.empty();
    ColumnsMetricsExp<ROW> rightPinnedColumnsMetrics =
        ColumnsMetricsExp.empty();

    final List<ROW> rows = [];
    final List<LayoutChild> children = [];

    int visibleRowsCount = layoutSettings.visibleRowsCount ?? 0;
    if (constraints.hasBoundedHeight) {
      //TODO scrollbarSize should have separator
      final double contentAvailableHeight = math.max(
          0,
          constraints.maxHeight -
              layoutSettings.headerHeight -
              layoutSettings.scrollbarSize);
      visibleRowsCount = (contentAvailableHeight /
              (layoutSettings.cellHeight + theme.row.dividerThickness))
          .ceil();
    }
    layoutSettings.contentHeight =
        (model.rowsLength * layoutSettings.cellHeight) +
            (math.max(0, model.rowsLength - 1) * theme.row.dividerThickness);

    children.add(LayoutChild.verticalScrollbar(
        child: EasyTableScrollBarExp(
            axis: Axis.vertical,
            contentSize: layoutSettings.contentHeight,
            scrollController: scrollControllers.vertical,
            color: theme.scrollbar.verticalColor)));

    final int firstRowIndex =
        (scrollControllers.verticalOffset / layoutSettings.rowHeight).floor();
    final int lastRowIndex = firstRowIndex + visibleRowsCount;

    final bool allowPin = !layoutSettings.columnsFit;

    for (int columnIndex = 0;
        columnIndex < model.columnsLength;
        columnIndex++) {
      EasyTableColumn<ROW> column = model.columnAt(columnIndex);
      final ContentAreaId contentAreaId =
          _contentAreaId(allowPin: allowPin, column: column);
      children.add(LayoutChild.header(
          contentAreaId: contentAreaId,
          column: columnIndex,
          child: EasyTableHeaderCell<ROW>(
              model: model,
              column: column,
              resizable: !layoutSettings.columnsFit,
              multiSortEnabled: multiSortEnabled)));
    }

    //TODO scrollbarSize border?
    final double maxContentAreaWidth =
        math.max(0, constraints.maxWidth - layoutSettings.scrollbarSize);

    if (layoutSettings.columnsFit) {
      unpinnedColumnsMetrics = ColumnsMetricsExp.columnsFit(
          model: model,
          containerWidth: maxContentAreaWidth,
          columnDividerThickness: theme.columnDividerThickness);
    } else {
      leftPinnedColumnsMetrics = ColumnsMetricsExp.resizable(
          model: model,
          columnDividerThickness: theme.columnDividerThickness,
          filter: ColumnFilterExp.pinnedOnly);

      unpinnedColumnsMetrics = ColumnsMetricsExp.resizable(
          model: model,
          columnDividerThickness: theme.columnDividerThickness,
          filter: ColumnFilterExp.unpinnedOnly);

      final double pinnedAreaWidth = leftPinnedColumnsMetrics.maxWidth;
      layoutSettings.needLeftPinnedHorizontalScrollbar =
          pinnedAreaWidth > maxContentAreaWidth;

      final double unpinnedAreaWidth = unpinnedColumnsMetrics.maxWidth;
      layoutSettings.needUnpinnedHorizontalScrollbar =
          unpinnedAreaWidth > maxContentAreaWidth - pinnedAreaWidth;

      if (layoutSettings.hasHorizontalScrollbar) {
        children.add(LayoutChild.horizontalScrollbar(
            contentAreaId: ContentAreaId.leftPinned,
            child: EasyTableScrollBarExp(
                axis: Axis.horizontal,
                scrollController: scrollControllers.leftPinnedContentArea,
                color: theme.scrollbar.pinnedHorizontalColor,
                contentSize: pinnedAreaWidth)));

        children.add(LayoutChild.horizontalScrollbar(
            contentAreaId: ContentAreaId.unpinned,
            child: EasyTableScrollBarExp(
                axis: Axis.horizontal,
                scrollController: scrollControllers.unpinnedContentArea,
                color: theme.scrollbar.unpinnedHorizontalColor,
                contentSize: unpinnedAreaWidth)));
      }
    }

    for (int rowIndex = firstRowIndex;
        rowIndex < model.visibleRowsLength && rowIndex < lastRowIndex;
        rowIndex++) {
      ROW row = model.visibleRowAt(rowIndex);
      rows.add(row);
      for (int columnIndex = 0;
          columnIndex < unpinnedColumnsMetrics.columns.length;
          columnIndex++) {
        EasyTableColumn<ROW> column =
            unpinnedColumnsMetrics.columns[columnIndex];
        if (column.cellBuilder != null) {
          Widget cellChild = column.cellBuilder!(context, row, rowIndex);
          EdgeInsets? padding;
          Alignment? alignment;
          Color? background;
          if (column.cellStyleBuilder != null) {
            CellStyle? cellStyle = column.cellStyleBuilder!(row);
            if (cellStyle != null) {
              background = cellStyle.background;
              alignment = cellStyle.alignment;
              padding = cellStyle.padding;
            }
          }
          Widget cell = ClipRect(
              child: EasyTableCell(
                  child: cellChild,
                  alignment: alignment,
                  padding: padding,
                  background: background));
          children.add(LayoutChild.cell(
              contentAreaId: ContentAreaId.unpinned,
              row: rowIndex,
              column: columnIndex,
              child: cell));
        }
      }
    }

    return TableLayoutExp(
        onHoverListener: onHoverListener,
        layoutSettings: layoutSettings,
        paintSettings: paintSettings,
        leftPinnedColumnsMetrics: leftPinnedColumnsMetrics,
        unpinnedColumnsMetrics: unpinnedColumnsMetrics,
        rightPinnedColumnsMetrics: rightPinnedColumnsMetrics,
        rows: rows,
        children: children);
  }

  ContentAreaId _contentAreaId(
      {required bool allowPin, required EasyTableColumn<ROW> column}) {
    if (allowPin) {
      if (column.pinned) {
        return ContentAreaId.leftPinned;
      }
    }
    return ContentAreaId.unpinned;
  }

  void _addHeaders(
      {required ContentAreaId contentAreaId,
      required ColumnFilter columnFilter,
      required bool multiSortEnabled,
      required EasyTableModel<ROW> model,
      required List<LayoutChild> children}) {
    for (int columnIndex = 0;
        columnIndex < model.columnsLength;
        columnIndex++) {
      EasyTableColumn<ROW> column = model.columnAt(columnIndex);
      if (columnFilter == ColumnFilter.all ||
          (columnFilter == ColumnFilter.unpinnedOnly &&
              column.pinned == false) ||
          (columnFilter == ColumnFilter.pinnedOnly && column.pinned)) {
        children.add(LayoutChild.header(
            contentAreaId: contentAreaId,
            column: columnIndex,
            child: EasyTableHeaderCell<ROW>(
                model: model,
                column: column,
                resizable: !layoutSettings.columnsFit,
                multiSortEnabled: multiSortEnabled)));
      }
    }
  }

  Widget _buildEmptyTable(
      {required BuildContext context,
      required BoxConstraints constraints,
      required TablePaintSettings paintSettings}) {
    final EasyTableThemeData theme = EasyTableTheme.of(context);

    List<LayoutChild> children = [];
    if (layoutSettings.allowHorizontalScrollbar &&
        !theme.scrollbar.horizontalOnlyWhenNeeded) {
      children.add(LayoutChild.verticalScrollbar(
          child: EasyTableScrollBarExp(
              axis: Axis.vertical,
              contentSize: constraints.maxHeight,
              scrollController: scrollControllers.vertical,
              color: theme.scrollbar.verticalColor)));
      children.add(LayoutChild.horizontalScrollbar(
          contentAreaId: ContentAreaId.unpinned,
          child: EasyTableScrollBarExp(
              axis: Axis.horizontal,
              contentSize: constraints.maxWidth,
              scrollController: scrollControllers.unpinnedContentArea,
              color: theme.scrollbar.unpinnedHorizontalColor)));
    }

    return TableLayoutExp(
        onHoverListener: onHoverListener,
        layoutSettings: layoutSettings,
        paintSettings: paintSettings,
        leftPinnedColumnsMetrics: ColumnsMetricsExp.empty(),
        unpinnedColumnsMetrics: ColumnsMetricsExp.empty(),
        rightPinnedColumnsMetrics: ColumnsMetricsExp.empty(),
        rows: const [],
        children: children);
  }
}