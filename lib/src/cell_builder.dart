import 'package:flutter/widgets.dart';

/// Signature for a function that builds a widget for a given column and row.
///
/// Used by [EasyTableColumn].
typedef EasyTableCellBuilder<ROW> = Widget Function(
    BuildContext context, ROW row);