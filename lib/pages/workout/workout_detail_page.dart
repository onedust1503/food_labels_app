// lib/pages/workout/workout_detail_page.dart
import 'package:flutter/material.dart';
import '../../models/workout_model.dart';

class WorkoutDetailPage extends StatelessWidget {
  final WorkoutModel workout;

  const WorkoutDetailPage({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('訓練詳情'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 訓練標題卡片
            _buildHeaderCard(),
            const SizedBox(height: 20),
            
            // 訓練數據
            _buildStatsGrid(),
            const SizedBox(height: 20),
            
            // 詳細資訊
            if (_hasAdditionalInfo()) _buildDetailSection(),
            
            // 備註
            if (workout.notes != null && workout.notes!.isNotEmpty)
              _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    IconData icon;
    Color iconColor;

    switch (workout.type) {
      case 'weight_training':
        icon = Icons.fitness_center;
        iconColor = Colors.red;
        break;
      case 'cardio':
        icon = Icons.directions_run;
        iconColor = Colors.blue;
        break;
      case 'yoga':
        icon = Icons.self_improvement;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.sports;
        iconColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[600]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            workout.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getTypeLabel(workout.type),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDate(workout.createdAt),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: Icons.timer,
          label: '時長',
          value: '${workout.duration}',
          unit: '分鐘',
          color: Colors.blue,
        ),
        if (workout.caloriesBurned != null)
          _buildStatCard(
            icon: Icons.local_fire_department,
            label: '卡路里',
            value: '${workout.caloriesBurned!.toInt()}',
            unit: '大卡',
            color: Colors.orange,
          ),
        if (workout.sets != null)
          _buildStatCard(
            icon: Icons.repeat,
            label: '組數',
            value: '${workout.sets}',
            unit: '組',
            color: Colors.purple,
          ),
        if (workout.reps != null)
          _buildStatCard(
            icon: Icons.loop,
            label: '次數',
            value: '${workout.reps}',
            unit: '次',
            color: Colors.green,
          ),
        if (workout.weight != null)
          _buildStatCard(
            icon: Icons.fitness_center,
            label: '重量',
            value: '${workout.weight}',
            unit: 'kg',
            color: Colors.red,
          ),
        if (workout.distance != null)
          _buildStatCard(
            icon: Icons.straighten,
            label: '距離',
            value: '${workout.distance}',
            unit: 'km',
            color: Colors.cyan,
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text(
                '詳細資訊',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (workout.intensity != null)
            _buildDetailRow('強度', _getIntensityLabel(workout.intensity!)),
          
          _buildDetailRow('日期', workout.date),
          
          _buildDetailRow('記錄時間', _formatDateTime(workout.createdAt)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.note_alt_outlined, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text(
                '備註',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            workout.notes!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAdditionalInfo() {
    return workout.intensity != null || 
           workout.date.isNotEmpty;
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'weight_training':
        return '重量訓練';
      case 'cardio':
        return '有氧運動';
      case 'yoga':
        return '瑜珈';
      case 'plan_workout':
        return '計畫訓練';
      default:
        return '其他運動';
    }
  }

  String _getIntensityLabel(String intensity) {
    switch (intensity) {
      case 'low':
        return '低強度';
      case 'medium':
        return '中強度';
      case 'high':
        return '高強度';
      default:
        return intensity;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}