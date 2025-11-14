// lib/pages/coach_search_page.dart
// 🎨 全新設計的教練搜尋頁面 - 參考現代 UI 設計

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/pair_request_service.dart';
import '../widgets/pair_request_dialog.dart';
import '../theme/app_theme.dart';

class CoachSearchPage extends StatefulWidget {
  final bool isEmbedded;
  
  const CoachSearchPage({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<CoachSearchPage> createState() => _CoachSearchPageState();
}

class _CoachSearchPageState extends State<CoachSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final PairRequestService _pairRequestService = PairRequestService();
  
  List<DocumentSnapshot> _coaches = [];
  List<DocumentSnapshot> _filteredCoaches = [];
  List<String> _selectedSpecialties = [];
  bool _isLoading = true;
  bool _isSearching = false;
  
  Set<String> _pairedCoachIds = {};
  Set<String> _pendingCoachIds = {};
  
  final List<String> _specialtyOptions = [
    '重量訓練',
    '有氧運動',
    '瑜伽',
    '皮拉提斯',
    '功能性訓練',
    '營養指導',
    '康復訓練',
    '體重管理',
    '肌肉增長',
    '運動表現',
  ];

  @override
  void initState() {
    super.initState();
    _loadPairStatus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPairStatus() async {
    try {
      final currentUserId = _userService.currentUserId;
      if (currentUserId == null) return;

      final pairsSnapshot = await FirebaseFirestore.instance
          .collection('pairs')
          .where('traineeId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('pairRequests')
          .where('studentId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _pairedCoachIds = pairsSnapshot.docs
            .map((doc) => doc.data()['coachId'] as String)
            .toSet();
        _pendingCoachIds = requestsSnapshot.docs
            .map((doc) => doc.data()['coachId'] as String)
            .toSet();
      });
      
      await _loadRecommendedCoaches();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入配對狀態失敗: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecommendedCoaches() async {
    try {
      setState(() => _isLoading = true);
      
      final allCoachesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .get();
      
      final coaches = allCoachesSnapshot.docs;
      
      final availableCoaches = coaches.where((coach) {
        final coachId = coach.id;
        return !_pairedCoachIds.contains(coachId) && 
               !_pendingCoachIds.contains(coachId);
      }).toList();
      
      setState(() {
        _coaches = availableCoaches;
        _filteredCoaches = availableCoaches;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('載入教練列表失敗: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty && _selectedSpecialties.isEmpty) {
      setState(() {
        _filteredCoaches = _coaches;
      });
    } else {
      _performSearch();
    }
  }

  void _performSearch() async {
    setState(() => _isSearching = true);
    
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      List<DocumentSnapshot> results = _coaches;
      
      if (_searchController.text.isNotEmpty || _selectedSpecialties.isNotEmpty) {
        results = _coaches.where((coach) {
          final data = coach.data() as Map<String, dynamic>;
          
          bool matchesName = true;
          if (_searchController.text.isNotEmpty) {
            final searchTerm = _searchController.text.toLowerCase();
            final name = (data['displayName'] ?? '').toLowerCase();
            matchesName = name.contains(searchTerm);
          }
          
          bool matchesSpecialty = true;
          if (_selectedSpecialties.isNotEmpty) {
            final specialties = List<String>.from(data['specialties'] ?? []);
            matchesSpecialty = _selectedSpecialties.any((selected) =>
              specialties.any((specialty) =>
                specialty.toLowerCase().contains(selected.toLowerCase())
              )
            );
          }
          
          return matchesName && matchesSpecialty;
        }).toList();
      }
      
      setState(() {
        _filteredCoaches = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorSnackBar('搜索失敗：$e');
    }
  }

  void _showPairingDialog(DocumentSnapshot coachDoc) {
    showDialog(
      context: context,
      builder: (context) => PairRequestDialog(
        coachDoc: coachDoc,
        onSendRequest: (message) async {
          await _sendPairRequest(coachDoc.id, message);
        },
      ),
    );
  }

  Future<void> _sendPairRequest(String coachId, String message) async {
    try {
      await _pairRequestService.sendPairRequest(
        coachId: coachId,
        message: message,
      );
      
      if (mounted) {
        _pendingCoachIds.add(coachId);
        _loadRecommendedCoaches();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('配對請求已發送！等待教練回應'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('發送配對請求失敗：$e');
      rethrow;
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 關鍵修正：設定鍵盤行為
    final content = Scaffold(
      resizeToAvoidBottomInset: false, // ✅ 防止鍵盤推高整個頁面
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ 固定在頂部的搜尋區域
            _buildSearchHeader(),
            
            // ✅ 可滾動的教練列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCoaches.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadRecommendedCoaches,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSizes.paddingMedium),
                            itemCount: _filteredCoaches.length,
                            itemBuilder: (context, index) {
                              return _buildModernCoachCard(_filteredCoaches[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return content;
  }

  // ✅ 全新的搜尋頭部設計
  Widget _buildSearchHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          // 搜尋框
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索教練姓名...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: AppSizes.iconLarge,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppColors.textTertiary),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingMedium,
                    vertical: AppSizes.paddingMedium,
                  ),
                ),
              ),
            ),
          ),
          
          // 專業領域 Chips（橫向滾動）
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: AppSizes.paddingMedium,
                right: AppSizes.paddingMedium,
                bottom: AppSizes.paddingSmall,
              ),
              children: _specialtyOptions.map((specialty) {
                final isSelected = _selectedSpecialties.contains(specialty);
                return Padding(
                  padding: const EdgeInsets.only(right: AppSizes.gapSmall),
                  child: FilterChip(
                    label: Text(specialty),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSpecialties.add(specialty);
                        } else {
                          _selectedSpecialties.remove(specialty);
                        }
                      });
                      _performSearch();
                    },
                    selectedColor: AppColors.accent2.withOpacity(0.3),
                    backgroundColor: AppColors.background,
                    labelStyle: AppTextStyles.caption.copyWith(
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected 
                          ? AppColors.accent2 
                          : AppColors.accent2.withOpacity(0.3),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingMedium,
                      vertical: AppSizes.paddingSmall,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 全新的現代化教練卡片設計
  Widget _buildModernCoachCard(DocumentSnapshot coachDoc) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    final coachBio = coachData['bio'] ?? '';
    final experienceRaw = coachData['experience'];
    final String experience = experienceRaw is String 
        ? experienceRaw 
        : (experienceRaw is int ? '${experienceRaw}年教學經驗' : '');
    final specialties = List<String>.from(coachData['specialties'] ?? []);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.gapLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXXLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ 頂部：頭像區域（參考範例的大頭像設計）
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusXXLarge),
                topRight: Radius.circular(AppSizes.radiusXXLarge),
              ),
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.medium,
                ),
                child: Center(
                  child: Text(
                    coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C',
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.primary,
                      fontSize: 36,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // ✅ 內容區域
          Padding(
            padding: AppSizes.cardPaddingLarge,
            child: Column(
              children: [
                // 教練名稱
                Text(
                  coachName,
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.gapSmall),
                
                // 認證標籤
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingMedium,
                    vertical: AppSizes.paddingSmall,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient.scale(0.3),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        '認證教練',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 經驗
                if (experience.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.gapMedium),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_outline, 
                        size: AppSizes.iconSmall, 
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        experience,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // 簡介
                if (coachBio.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.gapMedium),
                  Text(
                    coachBio,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                // 專長標籤（參考範例的 tag 設計）
                if (specialties.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.gapMedium),
                  Wrap(
                    spacing: AppSizes.gapSmall,
                    runSpacing: AppSizes.gapSmall,
                    alignment: WrapAlignment.center,
                    children: specialties.take(3).map((specialty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingMedium,
                          vertical: AppSizes.paddingSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent1.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                        child: Text(
                          specialty,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                
                const SizedBox(height: AppSizes.gapLarge),
                
                // ✅ 按鈕（參考範例的單一大按鈕設計）
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _showPairingDialog(coachDoc);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add, size: AppSizes.iconMedium),
                        const SizedBox(width: AppSizes.gapSmall),
                        Text(
                          '發送配對請求',
                          style: AppTextStyles.button,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 查看詳情文字按鈕
                TextButton(
                  onPressed: () {
                    _showCoachDetailDialog(coachDoc);
                  },
                  child: Text(
                    '查看詳細資料',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
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
          Icon(
            Icons.search_off,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSizes.gapLarge),
          Text(
            _pairedCoachIds.isEmpty && _pendingCoachIds.isEmpty
                ? '找不到符合條件的教練'
                : '沒有更多可配對的教練',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.gapSmall),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _pairedCoachIds.isEmpty && _pendingCoachIds.isEmpty
                  ? '嘗試調整搜索條件或清除篩選'
                  : '您已配對或發送請求給所有符合條件的教練',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSizes.gapXLarge),
          if (_searchController.text.isNotEmpty || _selectedSpecialties.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedSpecialties.clear();
                  _filteredCoaches = _coaches;
                });
              },
              child: const Text('清除篩選'),
            ),
        ],
      ),
    );
  }

  void _showCoachDetailDialog(DocumentSnapshot coachDoc) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    final coachBio = coachData['bio'] ?? '暫無簡介';
    final experienceRaw = coachData['experience'];
    final String experience = experienceRaw is String 
        ? experienceRaw 
        : (experienceRaw is int ? '${experienceRaw}年教學經驗' : '');
    final specialties = List<String>.from(coachData['specialties'] ?? []);
    final certifications = List<String>.from(coachData['certifications'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXLarge),
        ),
        title: Text(coachName, style: AppTextStyles.h3),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (experience.isNotEmpty) ...[
                Text('經驗：', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(experience, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSizes.gapMedium),
              ],
              
              Text('簡介：', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(coachBio, style: AppTextStyles.bodyMedium),
              
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: AppSizes.gapMedium),
                Text('專長：', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSizes.gapSmall,
                  runSpacing: AppSizes.gapSmall,
                  children: specialties.map((s) => Chip(
                    label: Text(s, style: AppTextStyles.caption),
                    backgroundColor: AppColors.accent2.withOpacity(0.2),
                  )).toList(),
                ),
              ],
              
              if (certifications.isNotEmpty) ...[
                const SizedBox(height: AppSizes.gapMedium),
                Text('證照：', style: AppTextStyles.label),
                const SizedBox(height: 4),
                ...certifications.map((cert) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.verified, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(cert, style: AppTextStyles.bodySmall),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPairingDialog(coachDoc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('發送請求'),
          ),
        ],
      ),
    );
  }
}