import 'package:flutter/material.dart';

/// String-keyed deterministic Material icons for Smart Gen templates.
/// (Master spec bans glitter/AI-tell icons; only functional icons here.)
IconData smartGenIcon(String name) {
  switch (name) {
    case 'task_alt_rounded':
      return Icons.task_alt_rounded;
    case 'folder_special_rounded':
      return Icons.folder_special_rounded;
    case 'alarm_rounded':
      return Icons.alarm_rounded;
    case 'note_rounded':
      return Icons.note_rounded;
    case 'book_rounded':
      return Icons.book_rounded;
    case 'checklist_rounded':
      return Icons.checklist_rounded;
    case 'description_rounded':
      return Icons.description_rounded;
    case 'attach_file_rounded':
      return Icons.attach_file_rounded;
    case 'bookmark_rounded':
      return Icons.bookmark_rounded;
    case 'new_releases_rounded':
      return Icons.new_releases_rounded;
    case 'work_rounded':
      return Icons.work_rounded;
    case 'image_rounded':
      return Icons.image_rounded;
    case 'splitscreen_rounded':
      return Icons.splitscreen_rounded;
    case 'layers_rounded':
      return Icons.layers_rounded;
    case 'flip_rounded':
      return Icons.flip_rounded;
    case 'view_column_rounded':
      return Icons.view_column_rounded;
    case 'view_stream_rounded':
      return Icons.view_stream_rounded;
    case 'business_center_rounded':
      return Icons.business_center_rounded;
    case 'menu_book_rounded':
      return Icons.menu_book_rounded;
    case 'collections_rounded':
      return Icons.collections_rounded;
    case 'folder_rounded':
      return Icons.folder_rounded;
    case 'photo_library_rounded':
      return Icons.photo_library_rounded;
    case 'lock_rounded':
      return Icons.lock_rounded;
    case 'auto_stories_rounded':
      return Icons.auto_stories_rounded;
    case 'dashboard_rounded':
      return Icons.dashboard_rounded;
    case 'table_chart_rounded':
      return Icons.table_chart_rounded;
    case 'calendar_month_rounded':
      return Icons.calendar_month_rounded;
    case 'pie_chart_rounded':
      return Icons.pie_chart_rounded;
    case 'badge_rounded':
      return Icons.badge_rounded;
    case 'view_kanban_rounded':
      return Icons.view_kanban_rounded;
    case 'calendar_today_rounded':
      return Icons.calendar_today_rounded;
    case 'draw_rounded':
      return Icons.draw_rounded;
    case 'desk_rounded':
      return Icons.desk_rounded;
    case 'construction_rounded':
      return Icons.construction_rounded;
    case 'table_restaurant_rounded':
      return Icons.table_restaurant_rounded;
    case 'table_bar_rounded':
      return Icons.table_bar_rounded;
    case 'nightstand_rounded':
      return Icons.bed_rounded;
    case 'coffee_rounded':
      return Icons.coffee_rounded;
    case 'insert_chart_rounded':
      return Icons.insert_chart_rounded;
    default:
      return Icons.widgets_rounded;
  }
}

/// Soft genie-fog mark for the Smart Genie: layered translucent mist,
/// no lamp, no mascot, no fantasy theatrics.
class GenieFogIcon extends StatelessWidget {
  final double size;
  final Color color;
  const GenieFogIcon({super.key, this.size = 18, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FogPainter(color)),
    );
  }
}

class _FogPainter extends CustomPainter {
  final Color color;
  _FogPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    // Three drifting mist bands.
    paint.color = color.withValues(alpha: 0.85);
    canvas.drawRRect(
        RRect.fromLTRBR(
            w * 0.12, h * 0.30, w * 0.88, h * 0.46, Radius.circular(h * 0.08)),
        paint);
    paint.color = color.withValues(alpha: 0.55);
    canvas.drawRRect(
        RRect.fromLTRBR(
            w * 0.22, h * 0.50, w * 0.78, h * 0.64, Radius.circular(h * 0.07)),
        paint);
    paint.color = color.withValues(alpha: 0.35);
    canvas.drawRRect(
        RRect.fromLTRBR(
            w * 0.32, h * 0.68, w * 0.68, h * 0.80, Radius.circular(h * 0.06)),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
