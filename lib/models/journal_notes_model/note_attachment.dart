/// A screenshot or PDF attached to a note. Max 3 per note, 5 MB each.
class NoteAttachment {
  /// UUID string, not an int — unlike every other id in this API.
  final String attachmentId;
  final int noteId;

  /// Sanitised server-side; display only. Do not use it to infer the type —
  /// the backend detects that from file content.
  final String filename;
  final String contentType;

  /// The **stored** size, not what was uploaded. Images are re-encoded
  /// server-side (EXIF/GPS stripped, capped at 2000px on the long edge), so
  /// expect this to differ from the bytes sent.
  final int byteSize;

  final String? sha256;
  final DateTime? createdAt;

  const NoteAttachment({
    required this.attachmentId,
    required this.noteId,
    required this.filename,
    required this.contentType,
    required this.byteSize,
    this.sha256,
    this.createdAt,
  });

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    return NoteAttachment(
      attachmentId: json['attachment_id']?.toString() ?? '',
      noteId: (json['note_id'] as num?)?.toInt() ?? 0,
      filename: json['filename']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
      sha256: json['sha256']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static List<NoteAttachment> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => NoteAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// PDFs are served with `Content-Disposition: attachment` and will download
  /// rather than render. Do not try to embed them.
  bool get isPdf => contentType == 'application/pdf';

  bool get isImage => contentType.startsWith('image/');

  @override
  bool operator ==(Object other) =>
      other is NoteAttachment && other.attachmentId == attachmentId;

  @override
  int get hashCode => attachmentId.hashCode;

  @override
  String toString() => 'NoteAttachment($attachmentId, $filename)';
}
