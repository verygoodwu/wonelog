class ArticleSummary {
  ArticleSummary({
    required this.filename,
    required this.title,
    required this.date,
    required this.description,
  });

  final String filename;
  final String title;
  final String date;
  final String description;

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      filename: (json['filename'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class VersionSummary {
  VersionSummary({
    required this.timestamp,
    required this.createdAt,
    required this.articlesCount,
    required this.linksCount,
    required this.citiesCount,
  });

  final String timestamp;
  final String createdAt;
  final int articlesCount;
  final int linksCount;
  final int citiesCount;

  factory VersionSummary.fromJson(Map<String, dynamic> json) {
    return VersionSummary(
      timestamp: (json['timestamp'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      articlesCount: _asInt(json['articles_count']),
      linksCount: _asInt(json['links_count']),
      citiesCount: _asInt(json['cities_count']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }
}
class ArticleDraft {
  ArticleDraft({
    required this.filename,
    required this.title,
    required this.pubDate,
    required this.description,
    required this.heroImage,
    required this.tags,
    required this.body,
  });

  final String filename;
  final String title;
  final String pubDate;
  final String description;
  final String heroImage;
  final List<String> tags;
  final String body;

  factory ArticleDraft.fromMarkdown(String filename, String markdown) {
    var title = filename.replaceAll(RegExp(r'\.md$'), '');
    var pubDate = '';
    var description = '';
    var heroImage = '';
    var tags = <String>[];
    var body = markdown;

    final lines = markdown.split('\n');
    if (lines.isNotEmpty && lines.first.trim() == '---') {
      var end = -1;
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          end = i;
          break;
        }
      }

      if (end > 0) {
        for (final line in lines.sublist(1, end)) {
          final separator = line.indexOf(':');
          if (separator <= 0) continue;
          final key = line.substring(0, separator).trim();
          final value = _unquote(line.substring(separator + 1).trim());
          switch (key) {
            case 'title':
              title = value;
            case 'pubDate':
              pubDate = value;
            case 'description':
              description = value;
            case 'heroImage':
              heroImage = value;
            case 'tags':
              tags = _parseTags(value);
          }
        }
        body = lines.sublist(end + 1).join('\n').trimLeft();
      }
    }

    return ArticleDraft(
      filename: filename,
      title: title,
      pubDate: pubDate,
      description: description,
      heroImage: heroImage,
      tags: tags,
      body: body,
    );
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln("title: '${_escape(title)}'")
      ..writeln("description: '${_escape(description)}'")
      ..writeln("pubDate: '${_escape(pubDate)}'");
    if (heroImage.trim().isNotEmpty) {
      buffer.writeln("heroImage: '${_escape(heroImage.trim())}'");
    }
    if (tags.isNotEmpty) {
      buffer.writeln('tags: [${tags.map((tag) => "'${_escape(tag)}'").join(', ')}]');
    }
    buffer
      ..writeln('---')
      ..writeln()
      ..write(body.trimRight())
      ..writeln();
    return buffer.toString();
  }

  static String _unquote(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  static List<String> _parseTags(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'^\['), '').replaceAll(RegExp(r'\]$'), '');
    if (cleaned.isEmpty) return <String>[];
    return cleaned.split(',').map((tag) => _unquote(tag.trim())).where((tag) => tag.isNotEmpty).toList();
  }

  static String _escape(String value) => value.replaceAll("'", "\\'");
}

