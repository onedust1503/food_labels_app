// lib/models/workout_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ========== 原有模型（保持不變）==========

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
  final String coachId;
  final String traineeId;
  final String planName;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final List<WorkoutPlanDay> days;
  final String status;
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

class WorkoutPlanDay {
  final String dayOfWeek;
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

class PlannedExercise {
  final String name;
  final String type;
  final int? sets;
  final int? reps;
  final int? duration;
  final String? notes;
  final String? primaryMuscleGroup; // 主要肌群（例如：胸部、腿部）
  final List<String>? targetMuscles; // 目標肌肉（例如：[下背部, 腿後肌]）

  PlannedExercise({
    required this.name,
    required this.type,
    this.sets,
    this.reps,
    this.duration,
    this.notes,
    this.primaryMuscleGroup,
    this.targetMuscles,
  });

  factory PlannedExercise.fromMap(Map<String, dynamic> data) {
    return PlannedExercise(
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      sets: data['sets'],
      reps: data['reps'],
      duration: data['duration'],
      notes: data['notes'],
      primaryMuscleGroup: data['primaryMuscleGroup'],
      targetMuscles: data['targetMuscles'] != null
          ? List<String>.from(data['targetMuscles'])
          : null,
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
      if (primaryMuscleGroup != null) 'primaryMuscleGroup': primaryMuscleGroup,
      if (targetMuscles != null) 'targetMuscles': targetMuscles,
    };
  }
}

// ========== 新增模型（狀態機，用於實時訓練）==========

/// 組數狀態
enum WorkoutSetStatus {
  pending,    // 等待開始
  active,     // 執行中
  completed,  // 已完成
  skipped,    // 已略過
  failed,     // 失敗
  resting     // 休息中
}

/// 訓練會話模型（workoutSessions 集合）
class WorkoutSessionModel {
  final String id;
  final String userId;
  final String source; // 'self' 或 'coach'
  final String? planId;
  final String? planDayId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int totalActiveSec; // 不含休息的活動時間
  final int totalRestSec; // 休息總秒數
  final double? calories;
  final int? sessionRpe; // 整體 RPE (1-10)
  final Map<String, dynamic>? meta;

  WorkoutSessionModel({
    required this.id,
    required this.userId,
    required this.source,
    this.planId,
    this.planDayId,
    required this.startedAt,
    this.endedAt,
    this.totalActiveSec = 0,
    this.totalRestSec = 0,
    this.calories,
    this.sessionRpe,
    this.meta,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'source': source,
        'planId': planId,
        'planDayId': planDayId,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'totalActiveSec': totalActiveSec,
        'totalRestSec': totalRestSec,
        'calories': calories,
        'sessionRpe': sessionRpe,
        'meta': meta,
        'createdAt': DateTime.now(),
      };

  factory WorkoutSessionModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return WorkoutSessionModel(
      id: docId,
      userId: data['userId'] ?? '',
      source: data['source'] ?? 'self',
      planId: data['planId'],
      planDayId: data['planDayId'],
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      endedAt: data['endedAt'] != null ? (data['endedAt'] as Timestamp).toDate() : null,
      totalActiveSec: data['totalActiveSec'] ?? 0,
      totalRestSec: data['totalRestSec'] ?? 0,
      calories: data['calories']?.toDouble(),
      sessionRpe: data['sessionRpe'],
      meta: data['meta'],
    );
  }
}

/// 單組進度
class SetProgress {
  final int index;
  final WorkoutSetStatus status;
  final int? targetReps;
  final int? actualReps;
  final double? weight;
  final int? targetDurationSec;
  final int? actualDurationSec;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? restPlannedSec;
  final int? restTakenSec;
  final double? rpe; // 主觀感受 (1-10)
  final String? note;

  const SetProgress({
    required this.index,
    this.status = WorkoutSetStatus.pending,
    this.targetReps,
    this.actualReps,
    this.weight,
    this.targetDurationSec,
    this.actualDurationSec,
    this.startedAt,
    this.completedAt,
    this.restPlannedSec,
    this.restTakenSec,
    this.rpe,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'status': status.name,
        'targetReps': targetReps,
        'actualReps': actualReps,
        'weight': weight,
        'targetDurationSec': targetDurationSec,
        'actualDurationSec': actualDurationSec,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'restPlannedSec': restPlannedSec,
        'restTakenSec': restTakenSec,
        'rpe': rpe,
        'note': note,
      };

  factory SetProgress.fromMap(Map<String, dynamic> data) {
    return SetProgress(
      index: data['index'] ?? 0,
      status: WorkoutSetStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => WorkoutSetStatus.pending,
      ),
      targetReps: data['targetReps'],
      actualReps: data['actualReps'],
      weight: data['weight']?.toDouble(),
      targetDurationSec: data['targetDurationSec'],
      actualDurationSec: data['actualDurationSec'],
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      restPlannedSec: data['restPlannedSec'],
      restTakenSec: data['restTakenSec'],
      rpe: data['rpe']?.toDouble(),
      note: data['note'],
    );
  }
}

/// 動作進度
class ExerciseProgress {
  final String exerciseId;
  final String exerciseName;
  final String type; // 'reps' | 'duration'
  final int plannedSets;
  final int? plannedReps;
  final int? plannedDurationSec;
  final int restSec; // 每組之間的休息秒數
  final List<SetProgress> sets;
  final int currentSetIndex;

  const ExerciseProgress({
    required this.exerciseId,
    required this.exerciseName,
    required this.type,
    required this.plannedSets,
    this.plannedReps,
    this.plannedDurationSec,
    this.restSec = 90,
    required this.sets,
    this.currentSetIndex = 0,
  });

  /// 判斷動作是否完成
  bool get isCompleted => sets.every((s) =>
      s.status == WorkoutSetStatus.completed ||
      s.status == WorkoutSetStatus.skipped ||
      s.status == WorkoutSetStatus.failed);

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'type': type,
        'plannedSets': plannedSets,
        'plannedReps': plannedReps,
        'plannedDurationSec': plannedDurationSec,
        'restSec': restSec,
        'currentSetIndex': currentSetIndex,
        'sets': sets.map((e) => e.toMap()).toList(),
      };

  factory ExerciseProgress.fromMap(Map<String, dynamic> data) {
    return ExerciseProgress(
      exerciseId: data['exerciseId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      type: data['type'] ?? 'reps',
      plannedSets: data['plannedSets'] ?? 1,
      plannedReps: data['plannedReps'],
      plannedDurationSec: data['plannedDurationSec'],
      restSec: data['restSec'] ?? 90,
      sets: (data['sets'] as List<dynamic>?)
              ?.map((s) => SetProgress.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      currentSetIndex: data['currentSetIndex'] ?? 0,
    );
  }
}