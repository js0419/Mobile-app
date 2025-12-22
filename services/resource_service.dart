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
      content: map['content'] != null && (map['content'] as List).isNotEmpty
          ? ResourceContent.fromMap((map['content'] as List)[0] as Map<String, dynamic>)
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
  // current user_id (bigint) resolved by email
  static Future<int> _currentUserId() async {
    final user = _sb.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not authenticated');
    }
    final data = await _sb
        .from('user') // <- was from('"user"')
        .select('user_id, user_email')
        .order('user_id')
        .limit(500);
    final row = (data as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['user_email'] == user.email, orElse: () => {});
    if (row.isEmpty) throw Exception('User not found in table');
    return row['user_id'] as int;
  }

  static Future<List<ResourceDto>> fetchPublished({
    int? categoryId,
    String? search,
    String? tag,
  }) async {
    try {
      final data = await _sb.from('resource').select('''
        resource_id, category_id, title, summary, content_type, tags, is_published, deleted_at,
        category:resource_category(category_id, name),
        content:resource_content(
          video_url, article_body, external_link,
          contact_name, contact_email, contact_phone,
          office_location, office_hours
        )
      ''');

      final publishedData =
      (data as List).where((e) => (e['is_published'] ?? false) == true).toList();
      final notDeletedData = publishedData.where((e) => e['deleted_at'] == null).toList();

      final categoryFiltered = categoryId == null
          ? notDeletedData
          : notDeletedData.where((e) => e['category_id'] == categoryId).toList();

      final q = (search ?? '').toLowerCase();
      final searchFiltered = q.isEmpty
          ? categoryFiltered
          : categoryFiltered.where((e) {
        final title = (e['title'] ?? '').toString().toLowerCase();
        final summary = (e['summary'] ?? '').toString().toLowerCase();
        final tags = ResourceDto._coerceTags(e['tags'])
            .map((s) => s.toLowerCase())
            .join(' ');
        return title.contains(q) || summary.contains(q) || tags.contains(q);
      }).toList();

      final t = (tag ?? '').toLowerCase();
      final tagFiltered = t.isEmpty
          ? searchFiltered
          : searchFiltered.where((e) {
        final tags = ResourceDto._coerceTags(e['tags'])
            .map((s) => s.toLowerCase())
            .toList();
        return tags.contains(t);
      }).toList();

      return tagFiltered
          .map((e) {
        try {
          return ResourceDto.fromMap(e);
        } catch (_) {
          return null;
        }
      })
          .whereType<ResourceDto>()
          .toList();
    } catch (e, stackTrace) {
      print('❌ ERROR in fetchPublished: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  static Future<ResourceDto?> fetchById(int id) async {
    try {
      final data = await _sb
          .from('resource')
          .select('''
            resource_id, category_id, title, summary, content_type, tags, is_published, deleted_at,
            category:resource_category(category_id, name),
            content:resource_content(
              video_url, article_body, external_link,
              contact_name, contact_email, contact_phone,
              office_location, office_hours
            )
          ''')
          .eq('is_published', true)
          .eq('resource_id', id)
          .order('created_at', ascending: false);

      final list = (data as List)
          .where((e) => e['deleted_at'] == null)
          .map((e) => ResourceDto.fromMap(e))
          .toList();
      if (list.isEmpty) return null;
      return list.first;
    } catch (e) {
      print('Error fetching resource by id: $e');
      return null;
    }
  }

  // Favorites: ids
  static Future<Set<int>> fetchFavoriteIds() async {
    try {
      final uid = await _currentUserId();
      final data = await _sb
          .from('resource_favorites')
          .select('user_id, resource_id')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      return (data as List)
          .cast<Map<String, dynamic>>()
          .map<int>((e) => e['resource_id'] as int)
          .toSet();
    } catch (e) {
      print('Error fetching favorite ids: $e');
      return {};
    }
  }

  // Favorites: full resources
  static Future<List<ResourceDto>> fetchFavoriteResources() async {
    try {
      final uid = await _currentUserId();
      final data = await _sb
          .from('resource_favorites')
          .select('''
            created_at,
            resource:resource(
              resource_id, category_id, title, summary, content_type, tags, is_published, deleted_at,
              category:resource_category(category_id, name),
              content:resource_content(
                video_url, article_body, external_link,
                contact_name, contact_email, contact_phone,
                office_location, office_hours
              )
            )
          ''')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      return (data as List)
          .map((row) => row['resource'])
          .where((r) => r != null)
          .map<ResourceDto>((r) => ResourceDto.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching favorite resources: $e');
      return [];
    }
  }

  // Toggle favorite (insert/delete)
  static Future<void> toggleFavorite(int resourceId, bool shouldBeFav) async {
    final uid = await _currentUserId();
    try {
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
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }

  // Recently viewed: record
  static Future<void> recordView(int resourceId) async {
    try {
      final uid = await _currentUserId();
      await _sb.from('resource_recent').upsert({
        'user_id': uid,
        'resource_id': resourceId,
        'viewed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,resource_id');
    } catch (e) {
      print('Error recording view: $e');
    }
  }

  // Recently viewed: list
  static Future<List<ResourceDto>> fetchRecent({int limit = 10}) async {
    try {
      final uid = await _currentUserId();
      final recent = await _sb
          .from('resource_recent')
          .select('user_id, resource_id, viewed_at')
          .eq('user_id', uid)
          .order('viewed_at', ascending: false)
          .limit(limit);

      final ids = (recent as List)
          .cast<Map<String, dynamic>>()
          .map<int>((e) => e['resource_id'] as int)
          .toList();

      final results = <ResourceDto>[];
      for (final id in ids) {
        final r = await fetchById(id);
        if (r != null) results.add(r);
      }
      return results;
    } catch (e) {
      print('Error fetching recent: $e');
      return [];
    }
  }

  // Categories
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final data =
      await _sb.from('resource_category').select('category_id, name').order('name');
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  // Admin: fetch all
  static Future<List<ResourceDto>> fetchAll({bool includeDeleted = false}) async {
    try {
      final data = await _sb.from('resource').select('''
        resource_id, category_id, title, summary, content_type, tags, is_published, deleted_at,
        category:resource_category(category_id, name),
        content:resource_content(
          video_url, article_body, external_link,
          contact_name, contact_email, contact_phone,
          office_location, office_hours
        )
      ''').order('created_at', ascending: false);

      return (data as List)
          .where((e) => includeDeleted || e['deleted_at'] == null)
          .map((e) => ResourceDto.fromMap(e))
          .toList();
    } catch (e) {
      print('Error fetching all resources: $e');
      return [];
    }
  }

  // Admin: upsert resource and its content
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
      'content_type': contentType, // critical: send new type
      'tags': tags?.join(','),     // comma-separated
      'is_published': isPublished,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (resourceId == null)
        'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final int id;
      if (resourceId == null) {
        // insert
        final inserted = await _sb
            .from('resource')
            .insert(payload)
            .select('resource_id')
            .single();
        id = inserted['resource_id'] as int;
      } else {
        // update; if no rows affected -> throw
        final updated = await _sb
            .from('resource')
            .update(payload)
            .eq('resource_id', resourceId);

        if (updated is List && updated.isEmpty) {
          throw Exception('Update blocked or not found (id=$resourceId)');
        }
        id = resourceId;
      }

      // insert/update content
      if (content != null) {
        final existing = await _sb
            .from('resource_content')
            .select('content_id')
            .eq('resource_id', id)
            .maybeSingle();

        if (existing == null) {
          await _sb.from('resource_content').insert({
            'resource_id': id,
            ...content.toJson(),
          });
        } else {
          await _sb
              .from('resource_content')
              .update(content.toJson())
              .eq('resource_id', id);
        }
      }
    } catch (e) {
      print('Error upserting resource: $e');
      rethrow; // surface the error to the UI
    }
  }

  static Future<void> setPublish(int id, bool publish) async {
    try {
      await _sb.from('resource').update({
        'is_published': publish,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      }).match({'resource_id': id});
    } catch (e) {
      print('Error setting publish: $e');
    }
  }

  static Future<void> softDelete(int id) async {
    try {
      await _sb.from('resource').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String()
      }).match({'resource_id': id});
    } catch (e) {
      print('Error deleting resource: $e');
    }
  }
}