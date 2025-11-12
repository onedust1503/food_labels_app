// lib/pages/workout/workout_summary_page.dart
// 🔥 訓練總結頁面 - 修正版

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/workout_service.dart';

class WorkoutSummaryPage extends StatefulWidget {
  final String sessionId;
  const WorkoutSummaryPage({super.key, required this.sessionId});

  @override
  State<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage> {
  final _service = WorkoutService();
  Map<String, dynamic>? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _service.getWorkoutSessionDetails(widget.sessionId);
      setState(() {
        _details = d;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入總結失敗：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }
    if (_details == null) {
      return const Scaffold(body: Center(child: Text('找不到此訓練記錄')));
    }

    final sess = _details!;
    final exercises = (sess['exercises'] as List).cast<Map<String, dynamic>>();

    final startedAtTs = sess['startedAt'] as Timestamp?;
    final endedAtTs = sess['endedAt'] as Timestamp?;
    final startedAt = startedAtTs?.toDate();
    final endedAt = endedAtTs?.toDate();
    final durationMin = (startedAt != null && endedAt != null)
        ? endedAt.difference(startedAt).inMinutes.clamp(0, 999)
        : null;

    int totalSets = 0;
    num totalVolume = 0;
    for (final ex in exercises) {
      final sets = (ex['sets'] as List).cast<Map<String, dynamic>>();
      for (final s in sets) {
        final st = (s['status'] as String?) ?? 'pending';
        if (st == 'completed' || st == 'resting') {
          totalSets += 1;
          final w = (s['weight'] as num?) ?? 0;
          final r = (s['actualReps'] as int?) ?? 0;
          totalVolume += (w * r);
        }
      }
    }
    final totalExercises = exercises.length;
    final estCalories = totalSets * 12.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('訓練總結', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: Container(), // 🔥 移除返回按鈕，強制用戶點擊「完成」按鈕
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 🔥 恭喜訊息
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22C55E), width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.celebration,
                  color: Color(0xFF22C55E),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎉 訓練完成！',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '太棒了！你完成了今天的訓練',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          _buildHeaderCard(
            dateText: startedAt != null
                ? DateFormat('yyyy年 MM月 dd日 (E)', 'zh_TW').format(startedAt)
                : '-',
            duration: durationMin ?? 0,
            calories: estCalories.toInt(),
            totalExercises: totalExercises,
            totalSets: totalSets,
          ),
          const SizedBox(height: 20),
          const Text('動作詳情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...exercises.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final ex = entry.value;
            return _buildExerciseCard(ex, index);
          }),
          const SizedBox(height: 20),
          // 🔥 修正：返回按鈕改為「完成」
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle, size: 28),
              label: const Text(
                '完成',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String dateText,
    required int duration,
    required int calories,
    required int totalExercises,
    required int totalSets,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF2DC4EA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.fitness_center, size: 28, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('自由訓練', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(dateText, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _buildStatBox(Icons.timer, '$duration', '分鐘')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatBox(Icons.local_fire_department, '$calories', '卡路里')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildStatBox(Icons.list, '$totalExercises', '動作')),
            const SizedBox(width: 12),
            Expanded(child: _buildStatBox(Icons.fitness_center, '$totalSets', '總組數')),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
      ]),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int index) {
    final name = (exercise['name'] as String?) ?? (exercise['exerciseName'] as String? ?? '');
    final allSets = (exercise['sets'] as List).cast<Map<String, dynamic>>();
    final sets = allSets.where((s) {
      final st = s['status'] as String?;
      return st == 'completed' || st == 'resting' || st == 'skipped';
    }).toList();
    final completedSets = sets.where((s) {
      final st = s['status'] as String?;
      return st == 'completed' || st == 'resting';
    }).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.1),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text('$index', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text('$completedSets 組', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: sets.asMap().entries.map((entry) {
              final setIndex = entry.key + 1;
              final s = entry.value;
              return _buildSetRow(s, setIndex);
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildSetRow(Map<String, dynamic> set, int setNumber) {
    final status = set['status'] as String?;
    final reps = set['actualReps'] as int?;
    final weight = set['weight'] as num?;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
      case 'resting':
        statusColor = const Color(0xFF22C55E);
        statusIcon = Icons.check_circle;
        statusText = '完成';
        break;
      case 'skipped':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        statusText = '略過';
        break;
      default:
        statusColor = Colors.grey.shade300;
        statusIcon = Icons.radio_button_unchecked;
        statusText = '未完成';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(statusIcon, size: 18, color: statusColor),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 50, child: Text('第 $setNumber 組', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        Expanded(
          child: Row(children: [
            if (reps != null) ...[
              const Icon(Icons.repeat, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$reps 次', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
            if (weight != null) ...[
              const Icon(Icons.fitness_center, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
        ),
      ]),
    );
  }
}