import 'smartgen_models.dart';

FieldDef _f(String label,
        {FieldKind kind = FieldKind.text,
        bool required = false,
        dynamic defaultValue,
        List<String>? options}) =>
    FieldDef(
        label: label,
        kind: kind,
        required: required,
        defaultValue: defaultValue,
        options: options);

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

ComponentTemplate _tpl(ComponentKind kind, String typeKey, String name,
    String iconName, List<FieldDef> fields,
    [Map<String, dynamic> settings = const {}]) {
  // Deterministic IDs: built-in templates are regenerated on every launch
  // and never persisted, so their IDs must be stable or persisted
  // deployed-instance references (templateId, field ids in values) would
  // break after a restart.
  final tplId = 'builtin_${kind.name}_$typeKey';
  final used = <String>{};
  final fixedFields = fields.map((f) {
    final base = '${tplId}__${_slug(f.label)}';
    var id = base;
    var n = 2;
    while (!used.add(id)) {
      id = '${base}_$n';
      n++;
    }
    return FieldDef(
      id: id,
      label: f.label,
      kind: f.kind,
      required: f.required,
      defaultValue: f.defaultValue,
      options: f.options,
    );
  }).toList();
  return ComponentTemplate(
      id: tplId,
      kind: kind,
      typeKey: typeKey,
      name: name,
      iconName: iconName,
      fields: fixedFields,
      settings: Map.of(settings),
      isBuiltIn: true);
}

/// Default card types (Smart Gen Summary + Master Spec §7.3).
List<ComponentTemplate> builtinCardTypes() => [
      _tpl(ComponentKind.card, 'task', 'Task', 'task_alt_rounded', [
        _f('Title', required: true),
        _f('Description', kind: FieldKind.text),
        _f('Status',
            kind: FieldKind.dropdown,
            defaultValue: 'To Do',
            options: ['To Do', 'In Progress', 'Done']),
        _f('Priority',
            kind: FieldKind.dropdown,
            defaultValue: 'P2',
            options: ['P0', 'P1', 'P2', 'P3']),
        _f('Assignee'),
        _f('Due date', kind: FieldKind.date),
        _f('Private notes'),
      ], {
        'accent': '0xFF64FFDA'
      }),
      _tpl(ComponentKind.card, 'project', 'Project', 'folder_special_rounded', [
        _f('Title', required: true),
        _f('Description'),
        _f('Status',
            kind: FieldKind.dropdown,
            defaultValue: 'Active',
            options: ['Active', 'Paused', 'Completed', 'Archived']),
        _f('Start date', kind: FieldKind.date),
        _f('Target date', kind: FieldKind.date),
        _f('Private notes'),
      ]),
      _tpl(ComponentKind.card, 'reminder', 'Reminder', 'alarm_rounded', [
        _f('Title', required: true),
        _f('Remind at', kind: FieldKind.date, required: true),
        _f('Repeat',
            kind: FieldKind.dropdown,
            defaultValue: 'Never',
            options: ['Never', 'Daily', 'Weekly', 'Monthly']),
        _f('Notes'),
      ]),
      _tpl(ComponentKind.card, 'note', 'Note', 'note_rounded', [
        _f('Title', required: true),
        _f('Body'),
      ]),
      _tpl(ComponentKind.card, 'journal_entry', 'Journal Entry',
          'book_rounded', [
        _f('Title', required: true),
        _f('Entry'),
        _f('Mood',
            kind: FieldKind.dropdown,
            options: ['Great', 'Good', 'Okay', 'Low', 'Rough']),
        _f('Private notes'),
      ]),
      _tpl(ComponentKind.card, 'list', 'List', 'checklist_rounded', [
        _f('Title', required: true),
        _f('Items'),
        _f('Show completed', kind: FieldKind.toggle, defaultValue: true),
      ]),
      _tpl(ComponentKind.card, 'artifact', 'Artifact', 'description_rounded', [
        _f('Title', required: true),
        _f('Content'),
        _f('Kind',
            kind: FieldKind.dropdown,
            defaultValue: 'Document',
            options: ['Document', 'Code', 'Diagram', 'Design', 'Audio']),
        _f('Source', kind: FieldKind.url),
      ]),
      _tpl(ComponentKind.card, 'file', 'File', 'attach_file_rounded', [
        _f('Title', required: true),
        _f('Location', kind: FieldKind.url),
        _f('Notes'),
      ]),
      _tpl(ComponentKind.card, 'memory', 'Memory', 'bookmark_rounded', [
        _f('Title', required: true),
        _f('Detail'),
        _f('Pinned', kind: FieldKind.toggle, defaultValue: false),
      ]),
      _tpl(ComponentKind.card, 'feature', 'Feature', 'new_releases_rounded', [
        _f('Title', required: true),
        _f('Specification'),
        _f('Status',
            kind: FieldKind.dropdown,
            defaultValue: 'Proposed',
            options: ['Proposed', 'Approved', 'Building', 'Shipped']),
        _f('Priority',
            kind: FieldKind.dropdown,
            defaultValue: 'P2',
            options: ['P0', 'P1', 'P2', 'P3']),
      ]),
      _tpl(ComponentKind.card, 'job', 'Job', 'work_rounded', [
        _f('Title', required: true),
        _f('Company', required: true),
        _f('Role'),
        _f('Start date', kind: FieldKind.date),
        _f('End date', kind: FieldKind.date),
        _f('Achievements'),
        _f('Private notes'),
      ]),
      _tpl(ComponentKind.card, 'poster', 'Poster', 'image_rounded', [
        _f('Title', required: true),
        _f('Caption'),
        _f('Image', kind: FieldKind.url),
      ]),
      _tpl(ComponentKind.card, 'segment', 'Segment', 'splitscreen_rounded', [
        _f('Title', required: true),
        _f('Color', kind: FieldKind.color, defaultValue: '0xFF64FFDA'),
      ]),
    ];

/// Default canvas types (Smart Gen Summary + Master Spec §7.4).
List<ComponentTemplate> builtinCanvasTypes() => [
      _tpl(ComponentKind.canvas, 'glass', 'Glass', 'layers_rounded', [
        _f('Title', required: true),
        _f('Tint', kind: FieldKind.color, defaultValue: '0x1EFFFFFF'),
      ]),
      _tpl(ComponentKind.canvas, 'mirror', 'Mirror', 'flip_rounded', [
        _f('Title', required: true),
        _f('Reflect', kind: FieldKind.toggle, defaultValue: true),
      ]),
      _tpl(ComponentKind.canvas, 'swimlane_vertical', 'Swimlane (Vertical)',
          'view_column_rounded', [
        _f('Title', required: true),
        _f('Lanes'),
      ]),
      _tpl(ComponentKind.canvas, 'swimlane_horizontal', 'Swimlane (Horizontal)',
          'view_stream_rounded', [
        _f('Title', required: true),
        _f('Lanes'),
      ]),
      _tpl(ComponentKind.canvas, 'portfolio', 'Portfolio',
          'business_center_rounded', [
        _f('Title', required: true),
        _f('Owner'),
      ]),
      _tpl(ComponentKind.canvas, 'notebook', 'Notebook', 'menu_book_rounded', [
        _f('Title', required: true),
        _f('Page', kind: FieldKind.number, defaultValue: 1),
      ]),
      _tpl(ComponentKind.canvas, 'collection', 'Collection',
          'collections_rounded', [
        _f('Title', required: true),
        _f('Description'),
      ]),
      _tpl(ComponentKind.canvas, 'folder', 'Folder', 'folder_rounded', [
        _f('Title', required: true),
      ]),
      _tpl(
          ComponentKind.canvas, 'gallery', 'Gallery', 'photo_library_rounded', [
        _f('Title', required: true),
        _f('Layout',
            kind: FieldKind.dropdown,
            defaultValue: 'Grid',
            options: ['Grid', 'Masonry', 'Carousel']),
      ]),
      _tpl(ComponentKind.canvas, 'diary', 'Diary', 'lock_rounded', [
        _f('Title', required: true),
        _f('Private notes'),
      ]),
      _tpl(ComponentKind.canvas, 'journal', 'Journal', 'auto_stories_rounded', [
        _f('Title', required: true),
      ]),
      _tpl(ComponentKind.canvas, 'kanban_widget', 'Kanban Widget',
          'dashboard_rounded', [
        _f('Title', required: true),
        _f('Columns'),
      ]),
      _tpl(ComponentKind.canvas, 'table', 'Table', 'table_chart_rounded', [
        _f('Title', required: true),
        _f('Columns'),
      ]),
      _tpl(ComponentKind.canvas, 'calendar_widget', 'Calendar Widget',
          'calendar_month_rounded', [
        _f('Title', required: true),
        _f('Month', kind: FieldKind.date),
      ]),
      _tpl(ComponentKind.canvas, 'diagrams_charts', 'Diagrams & Charts',
          'pie_chart_rounded', [
        _f('Title', required: true),
        _f('Diagram kind',
            kind: FieldKind.dropdown,
            defaultValue: 'Flow',
            options: ['Flow', 'Pie', 'Bar', 'Line', 'Mind map']),
      ]),
      _tpl(ComponentKind.canvas, 'name_photo_description',
          'Name · Photo · Description', 'badge_rounded', [
        _f('Name', required: true),
        _f('Photo', kind: FieldKind.url),
        _f('Description'),
      ]),
    ];

/// Default board types (Smart Gen Summary + Master Spec §7.5).
List<ComponentTemplate> builtinBoardTypes() => [
      _tpl(ComponentKind.board, 'kanban_swimlanes', 'Kanban with Swimlanes',
          'view_kanban_rounded', [
        _f('Title', required: true),
      ], {
        'columns': ['To Do', 'In Progress', 'Done'],
        'swimlanes': true,
      }),
      _tpl(ComponentKind.board, 'calendar', 'Calendar',
          'calendar_today_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'calendar'
      }),
      _tpl(ComponentKind.board, 'notebook', 'Notebook', 'menu_book_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'notebook'
      }),
      _tpl(ComponentKind.board, 'photo_album', 'Photo Album',
          'photo_library_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'album'
      }),
      _tpl(ComponentKind.board, 'storyboard', 'Storyboard',
          'view_carousel_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'storyboard'
      }),
      _tpl(ComponentKind.board, 'vision_board', 'Vision Board',
          'dashboard_customize_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'vision'
      }),
      _tpl(ComponentKind.board, 'swimlane', 'Swimlane Board',
          'view_column_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'swimlane'
      }),
      _tpl(ComponentKind.board, 'us_map', 'US Map', 'map_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'us_map'
      }),
      _tpl(ComponentKind.board, 'world_map', 'World Map', 'public_rounded', [
        _f('Title', required: true),
      ], {
        'view': 'world_map'
      }),
      _tpl(ComponentKind.board, 'whiteboard_empty', 'Whiteboard',
          'draw_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true
      }),
      _tpl(ComponentKind.board, 'whiteboard_swimlanes',
          'Whiteboard with Swimlanes', 'splitscreen_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'swimlanes': true
      }),
      _tpl(ComponentKind.board, 'desk', 'Desk', 'desk_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'wood'
      }),
      _tpl(ComponentKind.board, 'workbench', 'Workbench',
          'construction_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'metal'
      }),
      _tpl(ComponentKind.board, 'table', 'Table', 'table_restaurant_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'wood'
      }),
      _tpl(ComponentKind.board, 'long_wood_bench', 'Long Wood Bench',
          'table_bar_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'wood'
      }),
      _tpl(ComponentKind.board, 'wood_round_table', 'Wood Round Table',
          'table_bar_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'wood'
      }),
      _tpl(ComponentKind.board, 'wood_nightstand', 'Wood Nightstand',
          'nightstand_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'wood'
      }),
      _tpl(ComponentKind.board, 'wood_long_table', 'Wood Long Table',
          'table_restaurant_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'wood'
      }),
      _tpl(ComponentKind.board, 'wood_coffee_table', 'Wood Coffee Table',
          'coffee_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true,
        'surface': 'wood'
      }),
      _tpl(ComponentKind.board, 'charts_diagrams', 'Charts & Diagrams',
          'insert_chart_rounded', [
        _f('Title', required: true),
      ], {
        'freeform': true
      }),
    ];

/// All built-in templates across the three component kinds.
List<ComponentTemplate> builtinTemplates() => [
      ...builtinCardTypes(),
      ...builtinCanvasTypes(),
      ...builtinBoardTypes(),
    ];
