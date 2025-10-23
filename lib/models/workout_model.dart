// lib/models/workout_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutModel {
  final String? id;
  final String userId;
  final String date; // yyyy-MM-dd
  final String type; // 運動類型：weight_training, cardio, yoga, etc.
  final String name; // 運動名稱
  final int duration; // 分鐘
  final double? caloriesBurned; // 消耗卡路里
  final int? sets; // 組數（重訓用）
  final int? reps; // 次數（重訓用）
  final double? weight; // 重量kg（重訓用）
  final double? distance; // 距離km（有氧用）
  final String? intensity; // 強度：low, medium, high
  final String? notes; // 備註
  final DateTime createdAt;

  WorkoutModel({
    this.id,
    required this.userId,
    required this.date,
    required this.type,
    required this.name,
    required this.duration,
    this.caloriesBurned,
    this.sets,
    this.reps,
    this.weight,
    this.distance,
    this.intensity,
    this.notes,
    required this.createdAt,
  });

  // 從 Firestore 轉換
  factory WorkoutModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return WorkoutModel(
      id: docId,
      userId: data['userId'] ?? '',
      date: data['date'] ?? '',
      type: data['type'] ?? '',
      name: data['name'] ?? '',
      duration: data['duration'] ?? 0,
      caloriesBurned: data['caloriesBurned']?.toDouble(),
      sets: data['sets'],
      reps: data['reps'],
      weight: data['weight']?.toDouble(),
      distance: data['distance']?.toDouble(),
      intensity: data['intensity'],
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // 轉為 Firestore 格式
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': date,
      'type': type,
      'name': name,
      'duration': duration,
      if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (weight != null) 'weight': weight,
      if (distance != null) 'distance': distance,
      if (intensity != null) 'intensity': intensity,
      if (notes != null) 'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// 訓練計畫模型
class WorkoutPlanModel {
  final String? id;
  final String coachId; // 教練 ID
  final String traineeId; // 學員 ID
  final String planName; // 計畫名稱
  final String? description; // 說明
  final DateTime startDate;
  final DateTime? endDate;
  final List<WorkoutPlanDay> days; // 每日訓練
  final String status; // active, completed, cancelled
  final DateTime createdAt;

  WorkoutPlanModel({
    this.id,
    required this.coachId,
    required this.traineeId,
    required this.planName,
    this.description,
    required this.startDate,
    this.endDate,
    required this.days,
    this.status = 'active',
    required this.createdAt,
  });

  factory WorkoutPlanModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return WorkoutPlanModel(
      id: docId,
      coachId: data['coachId'] ?? '',
      traineeId: data['traineeId'] ?? '',
      planName: data['planName'] ?? '',
      description: data['description'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      days: (data['days'] as List<dynamic>?)
              ?.map((day) => WorkoutPlanDay.fromMap(day as Map<String, dynamic>))
              .toList() ??
          [],
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'coachId': coachId,
      'traineeId': traineeId,
      'planName': planName,
      if (description != null) 'description': description,
      'startDate': Timestamp.fromDate(startDate),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'days': days.map((day) => day.toMap()).toList(),
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// 訓練計畫的每日項目
class WorkoutPlanDay {
  final String dayOfWeek; // monday, tuesday, etc.
  final List<PlannedExercise> exercises;

  WorkoutPlanDay({
    required this.dayOfWeek,
    required this.exercises,
  });

  factory WorkoutPlanDay.fromMap(Map<String, dynamic> data) {
    return WorkoutPlanDay(
      dayOfWeek: data['dayOfWeek'] ?? '',
      exercises: (data['exercises'] as List<dynamic>?)
              ?.map((ex) => PlannedExercise.fromMap(ex as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'exercises': exercises.map((ex) => ex.toMap()).toList(),
    };
  }
}

// 計畫中的運動項目
class PlannedExercise {
  final String name;
  final String type;
  final int? sets;
  final int? reps;
  final int? duration; // 分鐘
  final String? notes;

  PlannedExercise({
    required this.name,
    required this.type,
    this.sets,
    this.reps,
    this.duration,
    this.notes,
  });

  factory PlannedExercise.fromMap(Map<String, dynamic> data) {
    return PlannedExercise(
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      sets: data['sets'],
      reps: data['reps'],
      duration: data['duration'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (duration != null) 'duration': duration,
      if (notes != null) 'notes': notes,
    };
  }
}