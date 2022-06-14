import 'package:easy_table/src/experimental/columns_metrics_exp.dart';
import 'package:easy_table/src/experimental/layout_child.dart';
import 'package:easy_table/src/experimental/row_callbacks.dart';
import 'package:easy_table/src/experimental/table_layout_element_exp.dart';
import 'package:easy_table/src/experimental/table_layout_render_box_exp.dart';
import 'package:easy_table/src/experimental/table_layout_settings.dart';
import 'package:easy_table/src/experimental/table_paint_settings.dart';
import 'package:easy_table/src/row_hover_listener.dart';
import 'package:easy_table/src/theme/theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// [EasyTable] table layout.
@internal
class TableLayoutExp<ROW> extends MultiChildRenderObjectWidget {
  TableLayoutExp(
      {Key? key,
      required this.onHoverListener,
      required this.layoutSettings,
      required this.paintSettings,
      required this.leftPinnedColumnsMetrics,
      required this.unpinnedColumnsMetrics,
      required this.rightPinnedColumnsMetrics,
      required this.theme,
      required this.rowCallbacks,
      required List<LayoutChild> children})
      : super(key: key, children: children);

  final OnRowHoverListener onHoverListener;
  final TableLayoutSettings layoutSettings;
  final TablePaintSettings paintSettings;
  final ColumnsMetricsExp leftPinnedColumnsMetrics;
  final ColumnsMetricsExp unpinnedColumnsMetrics;
  final ColumnsMetricsExp rightPinnedColumnsMetrics;
  final EasyTableThemeData theme;
  final RowCallbacks? rowCallbacks;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return TableLayoutRenderBoxExp<ROW>(
        onHoverListener: onHoverListener,
        layoutSettings: layoutSettings,
        paintSettings: paintSettings,
        leftPinnedColumnsMetrics: leftPinnedColumnsMetrics,
        unpinnedColumnsMetrics: unpinnedColumnsMetrics,
        rightPinnedColumnsMetrics: rightPinnedColumnsMetrics,
        theme: theme,
        rowCallbacks: rowCallbacks);
  }

  @override
  MultiChildRenderObjectElement createElement() {
    return TableLayoutElementExp(this);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant TableLayoutRenderBoxExp renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject
      ..onHoverListener = onHoverListener
      ..layoutSettings = layoutSettings
      ..paintSettings = paintSettings
      ..leftPinnedColumnsMetrics = leftPinnedColumnsMetrics
      ..unpinnedColumnsMetrics = unpinnedColumnsMetrics
      ..rightPinnedColumnsMetrics = rightPinnedColumnsMetrics
      ..theme = theme
      ..rowCallbacks = rowCallbacks;
  }
}
