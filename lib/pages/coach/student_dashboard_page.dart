// lib/pages/coach/student_dashboard_page.dart
// 🎯 學員管理儀表板 v2.0
// ✅ 莫蘭迪設計風格
// ✅ 整合真實進度數據

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import 'trainee_detail_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({Key? key}) : super(key: key);

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '學員管理',
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 搜尋列
          _buildSearchBar(),
          
          // 學員列表
          Expanded(
            child: _buildStudentList(),
          ),
        ],
      ),
    );
  }

  // 🎨 搜尋列
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.small,
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: '搜尋學員...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppColors.textTertiary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // 🎨 學員列表
  Widget _buildStudentList() {
    if (_currentUserId == null) {
      return _buildErrorState('請先登入');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('coachId', isEqualTo: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        // 載入中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coach),
            ),
          );
        }

        // 錯誤處理
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        // 沒有資料
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // 過濾搜尋結果
        final students = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['displayName'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        if (students.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            final data = student.data() as Map<String, dynamic>;
            return _buildStudentCard(student.id, data);
          },
        );
      },
    );
  }

  // 🎨 學員卡片
  Widget _buildStudentCard(String studentId, Map<String, dynamic> data) {
    final name = data['displayName'] ?? '未命名';
    final email = data['email'] ?? '';

    return FutureBuilder<Map<String, dynamic>>(
      future: _getStudentProgress(studentId),
      builder: (context, progressSnapshot) {
        final progress = progressSnapshot.data ?? {};
        final totalCompletions = progress['total'] ?? 0;
        final thisWeekCompletions = progress['thisWeek'] ?? 0;
        final onScheduleRate = progress['onScheduleRate'] ?? 0;
        final needsAttention = progress['needsAttention'] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.small,
            border: needsAttention
                ? Border.all(color: AppColors.warning, width: 2)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _navigateToDetail(studentId, name),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 頭像
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: needsAttention
                            ? AppColors.warningGradient
                            : AppColors.secondaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.small,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: AppTextStyles.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 資訊
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (needsAttention)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber,
                                        size: 14,
                                        color: AppColors.warning,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '需關注',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatChip(
                                Icons.fitness_center,
                                '本週 $thisWeekCompletions 次',
                                AppColors.coach,
                              ),
                              const SizedBox(width: 8),
                              _buildStatChip(
                                Icons.schedule,
                                '按時率 $onScheduleRate%',
                                onScheduleRate >= 80
                                    ? AppColors.success
                                    : onScheduleRate >= 50
                                        ? AppColors.warning
                                        : AppColors.error,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 箭頭
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🎨 統計標籤
  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 取得學員進度
  Future<Map<String, dynamic>> _getStudentProgress(String studentId) async {
    try {
      // 計算本週起始日
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final completions = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .collection('workoutCompletions')
          .get();

      int total = completions.docs.length;
      int onSchedule = 0;
      int thisWeek = 0;

      for (final doc in completions.docs) {
        final data = doc.data();
        
        // 計算按時數
        if (data['isOnSchedule'] == true) {
          onSchedule++;
        }
        
        // 計算本週數
        if (data['actualDate'] is Timestamp) {
          final date = (data['actualDate'] as Timestamp).toDate();
          if (date.isAfter(startDate)) {
            thisWeek++;
          }
        }
      }

      // 計算按時率
      final onScheduleRate = total > 0 ? (onSchedule / total * 100).round() : 0;
      
      // 判斷是否需要關注
      final needsAttention = thisWeek == 0 || (total > 3 && onScheduleRate < 50);

      return {
        'total': total,
        'onSchedule': onSchedule,
        'thisWeek': thisWeek,
        'onScheduleRate': onScheduleRate,
        'needsAttention': needsAttention,
      };
    } catch (e) {
      return {
        'total': 0,
        'onSchedule': 0,
        'thisWeek': 0,
        'onScheduleRate': 0,
        'needsAttention': false,
      };
    }
  }

  // 🔥 導航到詳情頁
  void _navigateToDetail(String studentId, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraineeDetailPage(
          traineeId: studentId,
          traineeName: name,
        ),
      ),
    );
  }

  // 🎨 錯誤狀態
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 60,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            '載入失敗',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 空狀態
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.coach.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.coach.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '尚無學員',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '邀請學員加入後會顯示在這裡',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 無搜尋結果
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            '找不到符合的學員',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '請嘗試其他搜尋條件',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}