// lib/pages/workout/exercise_library_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_service.dart';

/// 動作庫頁面 - 教練管理自訂運動動作資料庫
class ExerciseLibraryPage extends StatefulWidget {
  final bool isSelectionMode; // 是否為選擇模式（從創建菜單進入）
  
  const ExerciseLibraryPage({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  
  List<ExerciseData> _allExercises = [];
  List<ExerciseData> _filteredExercises = [];
  String _selectedCategory = '全部';
  bool _isLoading = true;

  final List<String> _categories = [
    '全部',
    '胸部',
    '背部',
    '腿部',
    '肩膀',
    '手臂',
    '核心',
    '有氧',
    '伸展',
  ];

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_filterExercises);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    try {
      String? coachId = _userService.currentUserId;
      if (coachId == null) return;

      // 載入教練自訂的動作
      QuerySnapshot snapshot = await _firestore
          .collection('exerciseLibrary')
          .where('coachId', isEqualTo: coachId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _allExercises = snapshot.docs
            .map((doc) => ExerciseData.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList();
        _filteredExercises = _allExercises;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('載入失敗：$e', Colors.red);
    }
  }

  void _filterExercises() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExercises = _allExercises.where((exercise) {
        bool matchesSearch = query.isEmpty ||
            exercise.name.toLowerCase().contains(query) ||
            (exercise.nameEn?.toLowerCase().contains(query) ?? false);
        bool matchesCategory = _selectedCategory == '全部' ||
            exercise.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _deleteExercise(String exerciseId) async {
    try {
      await _firestore.collection('exerciseLibrary').doc(exerciseId).delete();
      _showSnackBar('動作已刪除', Colors.green);
      _loadExercises();
    } catch (e) {
      _showSnackBar('刪除失敗：$e', Colors.red);
    }
  }

  void _showAddExerciseDialog() {
    final nameController = TextEditingController();
    final nameEnController = TextEditingController();
    final descriptionController = TextEditingController();
    final videoUrlController = TextEditingController();
    String selectedCategory = '胸部';
    String selectedEquipment = '槓鈴';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增動作'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '動作中文名稱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameEnController,
                  decoration: const InputDecoration(
                    labelText: '動作英文名稱（選填）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '類別',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.where((c) => c != '全部').map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedEquipment,
                  decoration: const InputDecoration(
                    labelText: '器材',
                    border: OutlineInputBorder(),
                  ),
                  items: ['槓鈴', '啞鈴', '機械', '滑輪', '自體重', '無'].map((equipment) {
                    return DropdownMenuItem(
                      value: equipment,
                      child: Text(equipment),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedEquipment = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '動作描述（選填）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: videoUrlController,
                  decoration: const InputDecoration(
                    labelText: '示範影片連結（選填）',
                    border: OutlineInputBorder(),
                    hintText: 'YouTube 或其他影片連結',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  _showSnackBar('請輸入動作名稱', Colors.red);
                  return;
                }

                try {
                  String? coachId = _userService.currentUserId;
                  if (coachId == null) return;

                  await _firestore.collection('exerciseLibrary').add({
                    'coachId': coachId,
                    'name': nameController.text,
                    'nameEn': nameEnController.text.isNotEmpty
                        ? nameEnController.text
                        : null,
                    'category': selectedCategory,
                    'equipment': selectedEquipment,
                    'description': descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
                    'videoUrl': videoUrlController.text.isNotEmpty
                        ? videoUrlController.text
                        : null,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _showSnackBar('動作已新增', Colors.green);
                  _loadExercises();
                } catch (e) {
                  _showSnackBar('新增失敗：$e', Colors.red);
                }
              },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? '選擇動作' : '動作庫'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddExerciseDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildExerciseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜尋動作名稱...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          String category = _categories[index];
          bool isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                  _filterExercises();
                });
              },
              selectedColor: Colors.green,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseList() {
    if (_filteredExercises.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredExercises.length,
      itemBuilder: (context, index) {
        return _buildExerciseCard(_filteredExercises[index]);
      },
    );
  }

  Widget _buildExerciseCard(ExerciseData exercise) {
    IconData categoryIcon;
    Color categoryColor;

    switch (exercise.category) {
      case '胸部':
        categoryIcon = Icons.fitness_center;
        categoryColor = Colors.orange;
        break;
      case '背部':
        categoryIcon = Icons.accessibility_new;
        categoryColor = Colors.blue;
        break;
      case '腿部':
        categoryIcon = Icons.directions_run;
        categoryColor = Colors.green;
        break;
      case '肩膀':
        categoryIcon = Icons.airline_seat_recline_extra;
        categoryColor = Colors.purple;
        break;
      case '手臂':
        categoryIcon = Icons.sports_martial_arts;
        categoryColor = Colors.red;
        break;
      case '有氧':
        categoryIcon = Icons.directions_run;
        categoryColor = Colors.cyan;
        break;
      default:
        categoryIcon = Icons.sports_gymnastics;
        categoryColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.isSelectionMode
            ? () => Navigator.pop(context, exercise)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (exercise.nameEn != null) ...[
                          Text(
                            exercise.nameEn!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!widget.isSelectionMode)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(exercise);
                        } else if (value == 'edit') {
                          _showEditExerciseDialog(exercise);
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
                  _buildInfoChip(exercise.category, Icons.category),
                  const SizedBox(width: 8),
                  _buildInfoChip(exercise.equipment, Icons.build),
                ],
              ),
              if (exercise.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  exercise.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (exercise.videoUrl != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.play_circle_outline, 
                         size: 18, 
                         color: Colors.blue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '示範影片',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '尚無動作',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '點擊右上角 + 新增動作',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ExerciseData exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${exercise.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteExercise(exercise.id!);
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditExerciseDialog(ExerciseData exercise) {
    // TODO: 實作編輯功能
    _showSnackBar('功能開發中：編輯動作', Colors.orange);
  }
}

// ========== 動作數據模型 ==========

class ExerciseData {
  final String? id;
  final String coachId;
  final String name;
  final String? nameEn;
  final String category;
  final String equipment;
  final String? description;
  final String? videoUrl;
  final DateTime createdAt;

  ExerciseData({
    this.id,
    required this.coachId,
    required this.name,
    this.nameEn,
    required this.category,
    required this.equipment,
    this.description,
    this.videoUrl,
    required this.createdAt,
  });

  factory ExerciseData.fromFirestore(Map<String, dynamic> data, String docId) {
    return ExerciseData(
      id: docId,
      coachId: data['coachId'] ?? '',
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      category: data['category'] ?? '',
      equipment: data['equipment'] ?? '',
      description: data['description'],
      videoUrl: data['videoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'coachId': coachId,
      'name': name,
      if (nameEn != null) 'nameEn': nameEn,
      'category': category,
      'equipment': equipment,
      if (description != null) 'description': description,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}