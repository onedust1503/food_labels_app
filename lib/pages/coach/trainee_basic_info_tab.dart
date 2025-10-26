// lib/pages/coach/trainee_basic_info_tab.dart
// 學員基本資料分頁

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TraineeBasicInfoTab extends StatelessWidget {
  final String traineeId;

  const TraineeBasicInfoTab({
    Key? key,
    required this.traineeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(traineeId)
          .snapshots(),
      builder: (context, snapshot) {
        // 載入中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
        }

        // 錯誤處理
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  '載入失敗',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // 找不到資料
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  '找不到學員資料',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // 取得學員資料
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['displayName'] ?? '未命名';
        final email = data['email'] ?? '';
        final height = data['height'];
        final weight = data['weight'];
        final targetWeight = data['targetWeight'];
        final dailyCalories = data['dailyCalories'];
        final goal = data['goal'] ?? '未設定';
        final phone = data['phone'];
        final joinedAt = data['joinedAt'];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 頭像與基本資訊
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green[100],
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 身體數據卡片
              _buildInfoCard(
                context: context,
                title: '身體數據',
                icon: Icons.monitor_weight,
                items: [
                  _InfoItem(
                    label: '身高',
                    value: height != null ? '$height cm' : '未設定',
                  ),
                  _InfoItem(
                    label: '體重',
                    value: weight != null ? '$weight kg' : '未設定',
                  ),
                  _InfoItem(
                    label: 'BMI',
                    value: _calculateBMI(height, weight),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 目標設定卡片
              _buildInfoCard(
                context: context,
                title: '目標設定',
                icon: Icons.flag,
                items: [
                  _InfoItem(
                    label: '目標體重',
                    value: targetWeight != null ? '$targetWeight kg' : '未設定',
                  ),
                  _InfoItem(
                    label: '每日熱量目標',
                    value: dailyCalories != null ? '$dailyCalories kcal' : '未設定',
                  ),
                  _InfoItem(
                    label: '健身目標',
                    value: goal,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 聯絡資訊卡片
              _buildInfoCard(
                context: context,
                title: '聯絡資訊',
                icon: Icons.contact_phone,
                items: [
                  _InfoItem(
                    label: '電話',
                    value: phone ?? '未提供',
                  ),
                  _InfoItem(
                    label: '加入日期',
                    value: _formatDate(joinedAt),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 建立資訊卡片
  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // 計算 BMI
  String _calculateBMI(dynamic height, dynamic weight) {
    if (height == null || weight == null) return '未設定';
    
    try {
      final h = height is int ? height.toDouble() : height as double;
      final w = weight is int ? weight.toDouble() : weight as double;
      
      final bmi = w / ((h / 100) * (h / 100));
      return bmi.toStringAsFixed(1);
    } catch (e) {
      return '計算錯誤';
    }
  }

  // 格式化日期
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '未知';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      }
      return '未知';
    } catch (e) {
      return '未知';
    }
  }
}

// 資訊項目資料類別
class _InfoItem {
  final String label;
  final String value;

  _InfoItem({
    required this.label,
    required this.value,
  });
}