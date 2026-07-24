enum EmailTemplateMode {
  visual('visual'),
  html('html');

  const EmailTemplateMode(this.value);
  final String value;

  static EmailTemplateMode fromString(String v) =>
      EmailTemplateMode.values.firstWhere((e) => e.value == v,
          orElse: () => EmailTemplateMode.visual);
}

enum EmailBlockType {
  logo('logo'),
  heading('heading'),
  text('text'),
  button('button'),
  divider('divider'),
  spacer('spacer'),
  footer('footer');

  const EmailBlockType(this.value);
  final String value;

  static EmailBlockType fromString(String v) =>
      EmailBlockType.values.firstWhere((e) => e.value == v,
          orElse: () => EmailBlockType.text);
}

class EmailTemplateBlock {
  final String id;
  EmailBlockType type;
  String? text;
  String? imageUrl;
  String? buttonUrl;
  double fontSize;
  bool bold;
  String textAlign;
  String textColor;
  String? bgFill;
  double spacerHeight;

  EmailTemplateBlock({
    required this.id,
    required this.type,
    this.text,
    this.imageUrl,
    this.buttonUrl,
    this.fontSize = 16,
    this.bold = false,
    this.textAlign = 'right',
    this.textColor = '#1A1A1A',
    this.bgFill,
    this.spacerHeight = 24,
  });

  factory EmailTemplateBlock.fromJson(Map<String, dynamic> j) => EmailTemplateBlock(
        id: j['id'] as String,
        type: EmailBlockType.fromString(j['type'] as String? ?? 'text'),
        text: j['text'] as String?,
        imageUrl: j['image_url'] as String?,
        buttonUrl: j['button_url'] as String?,
        fontSize: (j['font_size'] as num?)?.toDouble() ?? 16,
        bold: j['bold'] as bool? ?? false,
        textAlign: j['text_align'] as String? ?? 'right',
        textColor: j['text_color'] as String? ?? '#1A1A1A',
        bgFill: j['bg_fill'] as String?,
        spacerHeight: (j['spacer_height'] as num?)?.toDouble() ?? 24,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'text': text,
        'image_url': imageUrl,
        'button_url': buttonUrl,
        'font_size': fontSize,
        'bold': bold,
        'text_align': textAlign,
        'text_color': textColor,
        'bg_fill': bgFill,
        'spacer_height': spacerHeight,
      };

  EmailTemplateBlock copyWith({
    EmailBlockType? type,
    String? text,
    String? imageUrl,
    String? buttonUrl,
    double? fontSize,
    bool? bold,
    String? textAlign,
    String? textColor,
    String? bgFill,
    double? spacerHeight,
  }) =>
      EmailTemplateBlock(
        id: id,
        type: type ?? this.type,
        text: text ?? this.text,
        imageUrl: imageUrl ?? this.imageUrl,
        buttonUrl: buttonUrl ?? this.buttonUrl,
        fontSize: fontSize ?? this.fontSize,
        bold: bold ?? this.bold,
        textAlign: textAlign ?? this.textAlign,
        textColor: textColor ?? this.textColor,
        bgFill: bgFill ?? this.bgFill,
        spacerHeight: spacerHeight ?? this.spacerHeight,
      );
}

class EmailTemplate {
  final String? id;
  EmailTemplateMode mode;
  List<EmailTemplateBlock> blocks;
  String? htmlSource;

  EmailTemplate({
    this.id,
    this.mode = EmailTemplateMode.visual,
    List<EmailTemplateBlock>? blocks,
    this.htmlSource,
  }) : blocks = blocks ?? [];

  factory EmailTemplate.fromJson(Map<String, dynamic> j) => EmailTemplate(
        id: j['id'] as String?,
        mode: EmailTemplateMode.fromString(j['mode'] as String? ?? 'visual'),
        blocks: ((j['blocks'] as List?) ?? [])
            .map((b) => EmailTemplateBlock.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList(),
        htmlSource: j['html_source'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'html_source': htmlSource,
      };

  factory EmailTemplate.blank() => EmailTemplate(
        blocks: [
          EmailTemplateBlock(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: EmailBlockType.heading,
            text: '{{title}}',
            fontSize: 20,
            bold: true,
          ),
          EmailTemplateBlock(
            id: '${DateTime.now().microsecondsSinceEpoch}2',
            type: EmailBlockType.text,
            text: '{{message}}',
          ),
        ],
      );
}

const kEmailMergeFields = ['title', 'message', 'recipient_name', 'app_name'];
