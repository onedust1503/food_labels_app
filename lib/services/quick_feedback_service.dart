// lib/services/quick_feedback_service.dart
// 🎯 快速回饋模板服務 v1.0
// ✅ 管理教練的快速回饋模板
// ✅ 支援預設模板 + 自訂模板
// ✅ 模板分類：鼓勵、訓練建議、營養提醒

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 模板分類
enum FeedbackCategory {
  encouragement, // 😊 鼓勵類
  training,      // 💪 訓練建議
  nutrition,     // 🍎 營養提醒
  reminder,      // ⏰ 提醒類
  custom,        // ✏️ 自訂
}

/// 模板類型
enum TemplateType {
  quick,  // 短模板 - 直接發送
  long,   // 長模板 - 跳轉編輯
}

/// 快速回饋模板
class FeedbackTemplate {
  final String id;
  final String content;
  final FeedbackCategory category;
  final TemplateType type;
  final bool isDefault;      // 是否為系統預設
  final String? coachId;     // 教練ID（自訂模板才有）
  final int usageCount;      // 使用次數
  final DateTime createdAt;
  final DateTime? updatedAt;

  FeedbackTemplate({
    required this.id,
    required this.content,
    required this.category,
    this.type = TemplateType.quick,
    this.isDefault = false,
    this.coachId,
    this.usageCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// 是否為短模板（直接發送）
  bool get isQuickSend => type == TemplateType.quick || content.length <= 30;

  /// 獲取分類圖標
  String get categoryIcon {
    switch (category) {
      case FeedbackCategory.encouragement:
        return '😊';
      case FeedbackCategory.training:
        return '💪';
      case FeedbackCategory.nutrition:
        return '🍎';
      case FeedbackCategory.reminder:
        return '⏰';
      case FeedbackCategory.custom:
        return '✏️';
    }
  }

  /// 獲取分類名稱
  String get categoryName {
    switch (category) {
      case FeedbackCategory.encouragement:
        return '鼓勵';
      case FeedbackCategory.training:
        return '訓練';
      case FeedbackCategory.nutrition:
        return '營養';
      case FeedbackCategory.reminder:
        return '提醒';
      case FeedbackCategory.custom:
        return '自訂';
    }
  }

  /// 從 Firestore 創建
  factory FeedbackTemplate.fromFirestore(Map<String, dynamic> data, String docId) {
    return FeedbackTemplate(
      id: docId,
      content: data['content'] ?? '',
      category: FeedbackCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => FeedbackCategory.custom,
      ),
      type: data['type'] == 'long' ? TemplateType.long : TemplateType.quick,
      isDefault: data['isDefault'] ?? false,
      coachId: data['coachId'],
      usageCount: data['usageCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 轉換為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'category': category.name,
      'type': type.name,
      'isDefault': isDefault,
      'coachId': coachId,
      'usageCount': usageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// 複製並修改
  FeedbackTemplate copyWith({
    String? id,
    String? content,
    FeedbackCategory? category,
    TemplateType? type,
    bool? isDefault,
    String? coachId,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeedbackTemplate(
      id: id ?? this.id,
      content: content ?? this.content,
      category: category ?? this.category,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      coachId: coachId ?? this.coachId,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 快速回饋服務
class QuickFeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// 集合路徑
  static const String _collectionPath = 'feedbackTemplates';

  // ========== 預設模板 ==========

  /// 系統預設模板
  static final List<FeedbackTemplate> _defaultTemplates = [
    // 😊 鼓勵類
    FeedbackTemplate(
      id: 'default_enc_1',
      content: '做得很好，繼續保持！💪',
      category: FeedbackCategory.encouragement,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_enc_2',
      content: '這週進步很大，加油！🎉',
      category: FeedbackCategory.encouragement,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_enc_3',
      content: '辛苦了，好好休息！😊',
      category: FeedbackCategory.encouragement,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_enc_4',
      content: '看到你的努力了，繼續堅持下去！',
      category: FeedbackCategory.encouragement,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),

    // 💪 訓練建議
    FeedbackTemplate(
      id: 'default_train_1',
      content: '記得補足今天的訓練喔 📅',
      category: FeedbackCategory.training,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_train_2',
      content: '注意動作姿勢，避免受傷 ⚠️',
      category: FeedbackCategory.training,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_train_3',
      content: '可以試著增加一點重量了！',
      category: FeedbackCategory.training,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_train_4',
      content: '這週的訓練還沒完成，需要幫忙調整計畫嗎？',
      category: FeedbackCategory.training,
      type: TemplateType.long,
      isDefault: true,
      createdAt: DateTime.now(),
    ),

    // 🍎 營養提醒
    FeedbackTemplate(
      id: 'default_nutr_1',
      content: '記得多補充蛋白質 🥩',
      category: FeedbackCategory.nutrition,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_nutr_2',
      content: '水分攝取要足夠喔 💧',
      category: FeedbackCategory.nutrition,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_nutr_3',
      content: '訓練後記得補充營養 🍌',
      category: FeedbackCategory.nutrition,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),

    // ⏰ 提醒類
    FeedbackTemplate(
      id: 'default_remind_1',
      content: '別忘了今天的訓練！',
      category: FeedbackCategory.reminder,
      type: TemplateType.quick,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    FeedbackTemplate(
      id: 'default_remind_2',
      content: '好久沒看到你訓練了，一切還好嗎？',
      category: FeedbackCategory.reminder,
      type: TemplateType.long,
      isDefault: true,
      createdAt: DateTime.now(),
    ),
  ];

  // ========== 模板管理 ==========

  /// 獲取所有模板（預設 + 自訂）
  Future<List<FeedbackTemplate>> getAllTemplates() async {
    try {
      final templates = <FeedbackTemplate>[];

      // 1. 加入預設模板
      templates.addAll(_defaultTemplates);

      // 2. 獲取教練自訂模板
      if (_currentUserId != null) {
        final customTemplates = await _firestore
            .collection(_collectionPath)
            .where('coachId', isEqualTo: _currentUserId)
            .orderBy('usageCount', descending: true)
            .get();

        for (final doc in customTemplates.docs) {
          templates.add(FeedbackTemplate.fromFirestore(doc.data(), doc.id));
        }
      }

      // 3. 排序：常用優先
      templates.sort((a, b) => b.usageCount.compareTo(a.usageCount));

      return templates;
    } catch (e) {
      debugPrint('❌ 獲取模板失敗: $e');
      return _defaultTemplates;
    }
  }

  /// 按分類獲取模板
  Future<Map<FeedbackCategory, List<FeedbackTemplate>>> getTemplatesByCategory() async {
    final allTemplates = await getAllTemplates();
    final grouped = <FeedbackCategory, List<FeedbackTemplate>>{};

    for (final category in FeedbackCategory.values) {
      grouped[category] = allTemplates
          .where((t) => t.category == category)
          .toList();
    }

    return grouped;
  }

  /// 獲取最常用的模板
  Future<List<FeedbackTemplate>> getFrequentTemplates({int limit = 5}) async {
    final allTemplates = await getAllTemplates();
    return allTemplates.take(limit).toList();
  }

  /// 新增自訂模板
  Future<FeedbackTemplate> addCustomTemplate({
    required String content,
    required FeedbackCategory category,
    TemplateType type = TemplateType.quick,
  }) async {
    if (_currentUserId == null) {
      throw Exception('請先登入');
    }

    try {
      final template = FeedbackTemplate(
        id: '',  // Firestore 會自動生成
        content: content,
        category: category,
        type: type,
        isDefault: false,
        coachId: _currentUserId,
        usageCount: 0,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(_collectionPath)
          .add(template.toFirestore());

      debugPrint('✅ 新增自訂模板成功: ${docRef.id}');
      
      return template.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('❌ 新增模板失敗: $e');
      rethrow;
    }
  }

  /// 更新模板
  Future<void> updateTemplate(FeedbackTemplate template) async {
    if (template.isDefault) {
      throw Exception('無法修改預設模板');
    }

    try {
      await _firestore
          .collection(_collectionPath)
          .doc(template.id)
          .update({
        'content': template.content,
        'category': template.category.name,
        'type': template.type.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 更新模板成功: ${template.id}');
    } catch (e) {
      debugPrint('❌ 更新模板失敗: $e');
      rethrow;
    }
  }

  /// 刪除模板
  Future<void> deleteTemplate(String templateId) async {
    // 檢查是否為預設模板
    final isDefault = _defaultTemplates.any((t) => t.id == templateId);
    if (isDefault) {
      throw Exception('無法刪除預設模板');
    }

    try {
      await _firestore
          .collection(_collectionPath)
          .doc(templateId)
          .delete();

      debugPrint('✅ 刪除模板成功: $templateId');
    } catch (e) {
      debugPrint('❌ 刪除模板失敗: $e');
      rethrow;
    }
  }

  /// 記錄模板使用
  Future<void> recordTemplateUsage(String templateId) async {
    // 預設模板不記錄
    final isDefault = _defaultTemplates.any((t) => t.id == templateId);
    if (isDefault) return;

    try {
      await _firestore
          .collection(_collectionPath)
          .doc(templateId)
          .update({
        'usageCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('⚠️ 記錄使用次數失敗: $e');
    }
  }

  // ========== 發送回饋 ==========

  /// 發送快速回饋訊息
  /// 返回 chatRoomId 供導航使用
  Future<String> sendQuickFeedback({
    required String traineeId,
    required String templateId,
    required String content,
    String? customNote,  // 額外備註
  }) async {
    if (_currentUserId == null) {
      throw Exception('請先登入');
    }

    try {
      // 1. 創建或獲取聊天室
      final chatRoomId = await _getOrCreateChatRoom(traineeId);

      // 2. 準備訊息內容
      String messageContent = content;
      if (customNote != null && customNote.isNotEmpty) {
        messageContent = '$content\n\n$customNote';
      }

      // 3. 發送訊息
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': _currentUserId,
        'content': messageContent,
        'type': 'quickFeedback',  // 標記為快速回饋
        'templateId': templateId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 4. 更新聊天室最後訊息
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .update({
        'lastMessage': messageContent,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': _currentUserId,
      });

      // 5. 記錄模板使用
      await recordTemplateUsage(templateId);

      debugPrint('✅ 發送快速回饋成功');
      
      return chatRoomId;
    } catch (e) {
      debugPrint('❌ 發送快速回饋失敗: $e');
      rethrow;
    }
  }

  /// 獲取或創建聊天室
  Future<String> _getOrCreateChatRoom(String traineeId) async {
    if (_currentUserId == null) throw Exception('請先登入');

    // 查找現有聊天室
    final existingRooms = await _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: _currentUserId)
        .get();

    for (final doc in existingRooms.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(traineeId)) {
        return doc.id;
      }
    }

    // 創建新聊天室
    final newRoom = await _firestore.collection('chatRooms').add({
      'participants': [_currentUserId, traineeId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    return newRoom.id;
  }

  // ========== 情境推薦 ==========

  /// 根據學員狀態推薦模板
  Future<List<FeedbackTemplate>> getRecommendedTemplates({
    required String traineeId,
    int? daysSinceLastWorkout,
    double? completionRate,
    double? onTimeRate,
    bool? achievedGoal,
  }) async {
    final allTemplates = await getAllTemplates();
    final recommended = <FeedbackTemplate>[];

    // 情境 1：達成目標 → 推薦鼓勵
    if (achievedGoal == true) {
      recommended.addAll(
        allTemplates.where((t) => t.category == FeedbackCategory.encouragement)
      );
    }

    // 情境 2：長時間未訓練 → 推薦提醒
    if (daysSinceLastWorkout != null && daysSinceLastWorkout >= 3) {
      recommended.addAll(
        allTemplates.where((t) => t.category == FeedbackCategory.reminder)
      );
    }

    // 情境 3：完成率偏低 → 推薦訓練建議
    if (completionRate != null && completionRate < 0.5) {
      recommended.addAll(
        allTemplates.where((t) => t.category == FeedbackCategory.training)
      );
    }

    // 情境 4：按時率偏低 → 推薦提醒
    if (onTimeRate != null && onTimeRate < 0.6) {
      recommended.addAll(
        allTemplates.where((t) => 
          t.category == FeedbackCategory.training ||
          t.category == FeedbackCategory.reminder
        )
      );
    }

    // 去重並限制數量
    final seen = <String>{};
    return recommended
        .where((t) => seen.add(t.id))
        .take(5)
        .toList();
  }
}