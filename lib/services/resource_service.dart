import 'package:supabase_flutter/supabase_flutter.dart';

final _sb = Supabase.instance.client;

class ResourceDto {
  final int id;
  final String title;
  final String? summary;
  final String contentType;
  final List<String> tags;
  final bool isPublished;
  final String? categoryName;
  final int? categoryId;
  final ResourceContent? content;

  ResourceDto({
    required this.id,
    required this.title,
    required this.contentType,
    required this.isPublished,
    this.summary,
    this.tags = const [],
    this.categoryName,
    this.categoryId,
    this.content,
  });

  factory ResourceDto.fromMap(Map<String, dynamic> map) {
    return ResourceDto(
      id: map['resource_id'] as int,
      title: map['title'] ?? '',
      summary: map['summary'],
      contentType: map['content_type'] ?? '',
      tags: _coerceTags(map['tags']),
      isPublished: map['is_published'] ?? false,
      categoryName: map['category']?['name'],
      categoryId: map['category']?['category_id'],
      content: map['content'] != null
          ? ResourceContent.fromMap(map['content'])
          : null,
    );
  }

  static List<String> _coerceTags(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => '$e').toList();
    if (raw is String) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }
}

class ResourceContent {
  final String? videoUrl;
  final String? articleBody;
  final String? externalLink;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? officeLocation;
  final String? officeHours;

  ResourceContent({
    this.videoUrl,
    this.articleBody,
    this.externalLink,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.officeLocation,
    this.officeHours,
  });

  factory ResourceContent.fromMap(Map<String, dynamic> map) {
    return ResourceContent(
      videoUrl: map['video_url'],
      articleBody: map['article_body'],
      externalLink: map['external_link'],
      contactName: map['contact_name'],
      contactEmail: map['contact_email'],
      contactPhone: map['contact_phone'],
      officeLocation: map['office_location'],
      officeHours: map['office_hours'],
    );
  }

  Map<String, dynamic> toJson() => {
    'video_url': videoUrl,
    'article_body': articleBody,
    'external_link': externalLink,
    'contact_name': contactName,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
    'office_location': officeLocation,
    'office_hours': officeHours,
  };
}

class ResourceService {
  static Future<int> _currentUserId() async {
    final user = _sb.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not authenticated');
    }
    final data = await _sb
        .from('user')
        .select('user_id, user_email')
        .order('user_id')
        .limit(500);
    final row = (data as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['user_email'] == user.email,
        orElse: () => {});
    if (row.isEmpty) throw Exception('User not found in table');
    return row['user_id'] as int;
  }

  static Future<List<ResourceDto>> fetchPublished({
    int? categoryId,
    String? search,
    String? tag,
  }) async {
    final data = await _sb
        .from('resource')
        .select('''
          resource_id, category_id, title, summary, content_type, tags, is_published, deleted_at,
          category:resourceCategory(category_id, name),
          content:resourceContent(
            video_url, article_body, external_link,
            contact_name, contact_email, contact_phone,
            office_location, office_hours
          )
        ''')
        .order('created_at', ascending: false);

    String q = (search ?? '').toLowerCase();
    String t = (tag ?? '').toLowerCase();

    return (data as List)
        .where((e) => (e['is_published'] ?? false) == true && e['deleted_at'] == null)
        .where((e) => categoryId == null || e['category_id'] == categoryId)
        .where((e) {
      if (q.isEmpty) return true;
      final title = (e['title'] ?? '').toString().toLowerCase();
      final summary = (e['summary'] ?? '').toString().toLowerCase();
      final tags = ResourceDto._coerceTags(e['tags'])
          .map((s) => s.toLowerCase())
          .join(' ');
      return title.contains(q) || summary.contains(q) || tags.contains(q);
    })
        .where((e) {
      if (t.isEmpty) return true;
      final tags = ResourceDto._coerceTags(e['tags'])
          .map((s) => s.toLowerCase())
          .toList();
      return tags.contains(t);
    })
        .map((e) => ResourceDto.fromMap(e))
        .toList();
  }

  static Future<ResourceDto?> fetchById(int id) async {
    final data = await _sb
        .from('resource')
        .select('''
          resource_id, category_id, title, summary, content_type, tags, is_published, deleted_at,
          category:resourceCategory(category_id, name),
          content:resourceContent(
            video_url, article_body, external_link,
            contact_name, contact_email, contact_phone,
            office_location, office_hours
          )
        ''');

    final list = (data as List)
        .where((e) => e['deleted_at'] == null)
        .where((e) => e['resource_id'] == id)
        .map((e) => ResourceDto.fromMap(e))
        .toList();
    if (list.isEmpty) return null;
    return list.first;
  }

  // Favorites
  static Future<Set<int>> fetchFavoriteIds() async {
    final uid = await _currentUserId();
    final data = await _sb
        .from('resource_favorites')
        .select('user_id, resource_id')
        .order('created_at', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .where((e) => e['user_id'] == uid)
        .map<int>((e) => e['resource_id'] as int)
        .toSet();
  }

  static Future<void> toggleFavorite(int resourceId, bool shouldBeFav) async {
    final uid = await _currentUserId();
    if (shouldBeFav) {
      await _sb.from('resource_favorites').upsert({
        'user_id': uid,
        'resource_id': resourceId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,resource_id');
    } else {
      await _sb
          .from('resource_favorites')
          .delete()
          .match({'user_id': uid, 'resource_id': resourceId});
    }
  }

  // Recently viewed
  static Future<void> recordView(int resourceId) async {
    final uid = await _currentUserId();
    await _sb.from('resource_recent').upsert({
      'user_id': uid,
      'resource_id': resourceId,
      'viewed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,resource_id');
  }

  static Future<List<ResourceDto>> fetchRecent({int limit = 10}) async {
    final uid = await _currentUserId();
    final recent = await _sb
        .from('resource_recent')
        .select('user_id, resource_id, viewed_at')
        .order('viewed_at', ascending: false);

    final ids = (recent as List)
        .cast<Map<String, dynamic>>()
        .where((e) => e['user_id'] == uid)
        .map<int>((e) => e['resource_id'] as int)
        .toList();

    final limited = ids.take(limit).toList();
    final results = <ResourceDto>[];
    for (final id in limited) {
      final r = await fetchById(id);
      if (r != null) results.add(r);
    }
    return results;
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await _sb
        .from('resourceCategory')
        .select('category_id, name')
        .order('name');
    return (data as List).cast<Map<String, dynamic>>();
  }

  // Admin helpers
  static Future<List<ResourceDto>> fetchAll({bool includeDeleted = false}) async {
    final data = await _sb
        .from('resource')
        .select('''
          resource_id, category_id, title, summary, content_type, tags, is_published, deleted_at,
          category:resourceCategory(category_id, name),
          content:resourceContent(
            video_url, article_body, external_link,
            contact_name, contact_email, contact_phone,
            office_location, office_hours
          )
        ''')
        .order('created_at', ascending: false);

    return (data as List)
        .where((e) => includeDeleted || e['deleted_at'] == null)
        .map((e) => ResourceDto.fromMap(e))
        .toList();
  }

  static Future<void> upsertResource({
    int? resourceId,
    required int categoryId,
    required String title,
    String? summary,
    required String contentType,
    List<String>? tags,
    bool isPublished = false,
    ResourceContent? content,
  }) async {
    final payload = {
      'category_id': categoryId,
      'title': title,
      'summary': summary,
      'content_type': contentType,
      'tags': tags?.join(','),
      'is_published': isPublished,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (resourceId == null) 'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    int id = resourceId ??
        await _sb
            .from('resource')
            .insert(payload)
            .select('resource_id')
            .single()
            .then((r) => r['resource_id'] as int);

    if (resourceId != null) {
      await _sb.from('resource').update(payload).match({'resource_id': id});
    }

    if (content != null) {
      final existing = await _sb
          .from('resourceContent')
          .select('content_id')
          .match({'resource_id': id})
          .maybeSingle();

      if (existing == null) {
        await _sb.from('resourceContent').insert({
          'resource_id': id,
          ...content.toJson(),
        });
      } else {
        await _sb
            .from('resourceContent')
            .update(content.toJson())
            .match({'resource_id': id});
      }
    }
  }

  static Future<void> setPublish(int id, bool publish) async {
    await _sb
        .from('resource')
        .update({
      'is_published': publish,
      'updated_at': DateTime.now().toUtc().toIso8601String()
    })
        .match({'resource_id': id});
  }

  static Future<void> softDelete(int id) async {
    await _sb
        .from('resource')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .match({'resource_id': id});
  }
}