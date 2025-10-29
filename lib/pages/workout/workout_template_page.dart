// lib/pages/workout/workout_template_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/workout_model.dart';
import '../../services/user_service.dart';

/// 訓練模板頁面 - 教練端管理常用訓練計畫模板
class WorkoutTemplatePage extends StatefulWidget {
  const WorkoutTemplatePage({super.key});

  @override
  State<WorkoutTemplatePage> createState() => _WorkoutTemplatePageState();
}

class _WorkoutTemplatePageState extends State<WorkoutTemplatePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  
  List<WorkoutTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      String? coachId = _userService.currentUserId;
      if (coachId == null) return;

      QuerySnapshot snapshot = await _firestore
          .collection('workoutTemplates')
          .where('coachId', isEqualTo: coachId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _templates = snapshot.docs
            .map((doc) => WorkoutTemplate.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _deleteTemplate(String templateId) async {
    try {
      await _firestore.collection('workoutTemplates').doc(templateId).delete();
      _showSnackBar('模板已刪除', Colors.green);
      _loadTemplates();
    } catch (e) {
      _showSnackBar('刪除失敗：$e', Colors.red);
    }
  }

  void _showDeleteConfirmation(WorkoutTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${template.name}」模板嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTemplate(template.id!);
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _useTemplate(WorkoutTemplate template) {
    // 導航到創建訓練計畫頁面，並預填模板數據
    Navigator.pop(context, template);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訓練模板'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showCreateTemplateDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: _templates.isEmpty
                  ? _buildEmptyState()
                  : _buildTemplateList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '尚無訓練模板',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊右上角 + 建立新模板',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        return _buildTemplateCard(_templates[index]);
      },
    );
  }

  Widget _buildTemplateCard(WorkoutTemplate template) {
    int totalExercises = template.days.fold(
      0,
      (sum, day) => sum + day.exercises.length,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _useTemplate(template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (template.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            template.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(template);
                      } else if (value == 'edit') {
                        _showEditTemplateDialog(template);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('編輯'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('刪除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    '${template.days.length} 天',
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    '$totalExercises 動作',
                    Icons.fitness_center,
                    Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('創建訓練模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '模板名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（選填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                _showSnackBar('請輸入模板名稱', Colors.red);
                return;
              }

              // TODO: 導航到模板編輯頁面，讓教練添加訓練日和動作
              Navigator.pop(context);
              _showSnackBar('功能開發中：將導航到模板編輯頁面', Colors.orange);
            },
            child: const Text('下一步'),
          ),
        ],
      ),
    );
  }

  void _showEditTemplateDialog(WorkoutTemplate template) {
    // TODO: 導航到模板編輯頁面
    _showSnackBar('功能開發中：編輯模板', Colors.orange);
  }
}

// ========== 訓練模板數據模型 ==========

class WorkoutTemplate {
  final String? id;
  final String coachId;
  final String name;
  final String? description;
  final List<WorkoutPlanDay> days;
  final DateTime createdAt;

  WorkoutTemplate({
    this.id,
    required this.coachId,
    required this.name,
    this.description,
    required this.days,
    required this.createdAt,
  });

  factory WorkoutTemplate.fromFirestore(Map<String, dynamic> data, String docId) {
    return WorkoutTemplate(
      id: docId,
      coachId: data['coachId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      days: (data['days'] as List<dynamic>?)
              ?.map((day) => WorkoutPlanDay.fromMap(day as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'coachId': coachId,
      'name': name,
      if (description != null) 'description': description,
      'days': days.map((day) => day.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}