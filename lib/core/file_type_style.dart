import 'package:flutter/material.dart';

/// Estilo visual (icono + color) según tipo de archivo (extensión o mime).
class FileTypeStyle {
  const FileTypeStyle({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;

  static FileTypeStyle forFile(String fileName, [String? mimeType]) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final mime = (mimeType ?? '').toLowerCase();

    // PDF
    if (ext == 'pdf' || mime.contains('pdf')) {
      return const FileTypeStyle(
        icon: Icons.picture_as_pdf_rounded,
        color: Color(0xFFE53935),
        backgroundColor: Color(0xFFFFEBEE),
      );
    }

    // Word
    if (['doc', 'docx'].contains(ext) || mime.contains('word') || mime.contains('msword') || mime.contains('document')) {
      return const FileTypeStyle(
        icon: Icons.description_rounded,
        color: Color(0xFF2B579A),
        backgroundColor: Color(0xFFE3F2FD),
      );
    }

    // Excel
    if (['xls', 'xlsx', 'csv'].contains(ext) || mime.contains('sheet') || mime.contains('excel') || mime.contains('spreadsheet')) {
      return const FileTypeStyle(
        icon: Icons.table_chart_rounded,
        color: Color(0xFF217346),
        backgroundColor: Color(0xFFE8F5E9),
      );
    }

    // PowerPoint
    if (['ppt', 'pptx'].contains(ext) || mime.contains('presentation') || mime.contains('powerpoint')) {
      return const FileTypeStyle(
        icon: Icons.slideshow_rounded,
        color: Color(0xFFD24726),
        backgroundColor: Color(0xFFFFF3E0),
      );
    }

    // Imágenes
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic'].contains(ext) ||
        mime.contains('image')) {
      return const FileTypeStyle(
        icon: Icons.image_rounded,
        color: Color(0xFF7B1FA2),
        backgroundColor: Color(0xFFF3E5F5),
      );
    }

    // Video
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext) || mime.contains('video')) {
      return const FileTypeStyle(
        icon: Icons.videocam_rounded,
        color: Color(0xFFE91E63),
        backgroundColor: Color(0xFFFCE4EC),
      );
    }

    // Audio
    if (['mp3', 'wav', 'm4a', 'ogg', 'flac'].contains(ext) || mime.contains('audio')) {
      return const FileTypeStyle(
        icon: Icons.audiotrack_rounded,
        color: Color(0xFF009688),
        backgroundColor: Color(0xFFE0F2F1),
      );
    }

    // Texto
    if (['txt', 'md', 'rtf'].contains(ext) || mime.contains('text')) {
      return const FileTypeStyle(
        icon: Icons.text_snippet_rounded,
        color: Color(0xFF607D8B),
        backgroundColor: Color(0xFFECEFF1),
      );
    }

    // Zip / comprimidos
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext) || mime.contains('zip') || mime.contains('compressed')) {
      return const FileTypeStyle(
        icon: Icons.folder_zip_rounded,
        color: Color(0xFF795548),
        backgroundColor: Color(0xFFEFEBE9),
      );
    }

    // Por defecto
    return const FileTypeStyle(
      icon: Icons.insert_drive_file_rounded,
      color: Color(0xFF64B4E6),
      backgroundColor: Color(0xFFE8F4FC),
    );
  }
}
