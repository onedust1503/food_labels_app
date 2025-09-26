// lib/pages/coach_search_page.dart (修復版本)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../services/pairing_service.dart';
import '../widgets/pair_request_dialog.dart';
import 'chat_detail_page.dart';

class CoachSearchPage extends StatefulWidget {
  const CoachSearchPage({super.key});

  @override
  State<CoachSearchPage> createState() => _CoachSearchPageState();
}

class _CoachSearchPageState extends State<CoachSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final PairingService _pairingService = PairingService();
  
  List<DocumentSnapshot> _coaches = [];
  List<DocumentSnapshot> _filteredCoaches = [];
  List<String> _selectedSpecialties = [];
  bool _isLoading = true;
  bool _isSearching = false;
  
  // 配對狀態緩存
  Map<String, PairStatus> _pairStatusCache = {};
  
  // 專業領域選項
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
    _loadRecommendedCoaches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 載入推薦教練
  Future<void> _loadRecommendedCoaches() async {
    setState(() => _isLoading = true);
    
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .limit(20)
          .get();
      
      List<DocumentSnapshot> coaches = snapshot.docs;
      coaches.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = aData['displayName'] ?? '';
        final bName = bData['displayName'] ?? '';
        return aName.compareTo(bName);
      });
      
      setState(() {
        _coaches = coaches;
        _filteredCoaches = coaches;
        _isLoading = false;
      });

      // 載入配對狀態
      _loadPairStatuses();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('載入教練列表失敗：$e');
    }
  }

  // 載入配對狀態
  Future<void> _loadPairStatuses() async {
    final Map<String, PairStatus> statuses = {};
    
    for (final coach in _filteredCoaches) {
      try {
        final status = await _pairingService.getPairStatus(coach.id);
        statuses[coach.id] = status;
      } catch (e) {
        statuses[coach.id] = PairStatus.none;
      }
    }
    
    if (mounted) {
      setState(() {
        _pairStatusCache = statuses;
      });
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.trim().isEmpty && _selectedSpecialties.isEmpty) {
      setState(() {
        _filteredCoaches = _coaches;
      });
      _loadPairStatuses();
      return;
    }
    
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() => _isSearching = true);
    
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .limit(50)
          .get();
      
      List<DocumentSnapshot> results = snapshot.docs;
      final searchTerm = _searchController.text.toLowerCase().trim();
      
      if (searchTerm.isNotEmpty || _selectedSpecialties.isNotEmpty) {
        results = results.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          bool matchesName = true;
          if (searchTerm.isNotEmpty) {
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
        
        results.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = aData['displayName'] ?? '';
          final bName = bData['displayName'] ?? '';
          return aName.compareTo(bName);
        });
      }
      
      setState(() {
        _filteredCoaches = results;
        _isSearching = false;
      });

      // 載入新結果的配對狀態
      _loadPairStatuses();
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorSnackBar('搜索失敗：$e');
    }
  }

  // 智能聯繫教練方法（根據配對狀態決定行為）
  Future<void> _contactCoach(DocumentSnapshot coachDoc) async {
    try {
      final coachData = coachDoc.data() as Map<String, dynamic>;
      final coachId = coachDoc.id;
      final coachName = coachData['displayName'] ?? '教練';
      
      // 獲取配對狀態
      final status = _pairStatusCache[coachId] ?? await _pairingService.getPairStatus(coachId);
      
      switch (status) {
        case PairStatus.paired:
          // 已配對：直接開啟聊天
          await _openExistingChat(coachId, coachName);
          break;
          
        case PairStatus.requestPending:
          // 請求待處理：顯示狀態
          _showPendingRequestDialog(coachName);
          break;
          
        case PairStatus.rejected:
          // 被拒絕：顯示冷卻提示
          _showRejectedDialog();
          break;
          
        case PairStatus.none:
          // 未配對：顯示配對請求對話框
          _showPairRequestDialog(coachDoc);
          break;
      }
    } catch (e) {
      _showErrorSnackBar('操作失敗：$e');
    }
  }

  // 顯示配對請求對話框
  Future<void> _showPairRequestDialog(DocumentSnapshot coachDoc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PairRequestDialog(
        coachDoc: coachDoc,
        onSendRequest: (message) async {
          await _pairingService.sendPairRequest(
            toUserId: coachDoc.id,
            message: message,
          );
        },
      ),
    );

    if (result == true) {
      // 配對請求發送成功
      final coachData = coachDoc.data() as Map<String, dynamic>;
      final coachName = coachData['displayName'] ?? '教練';
      
      _showSuccessSnackBar('配對請求已發送給 $coachName！');
      
      // 更新配對狀態
      setState(() {
        _pairStatusCache[coachDoc.id] = PairStatus.requestPending;
      });
    }
  }

  // 顯示待處理請求對話框
  void _showPendingRequestDialog(String coachName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.pending_actions,
              color: Colors.orange[600],
            ),
            const SizedBox(width: 8),
            const Text('配對請求待處理'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您已向 $coachName 發送配對請求'),
            const SizedBox(height: 8),
            const Text(
              '請耐心等待教練回應。您也可以：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildSuggestionItem('🔍', '繼續尋找其他教練'),
            _buildSuggestionItem('⏰', '查看請求狀態'),
            _buildSuggestionItem('📝', '完善個人資料提高通過率'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  // 顯示被拒絕對話框
  void _showRejectedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.schedule,
              color: Colors.red[600],
            ),
            const SizedBox(width: 8),
            const Text('請稍後再試'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('您的配對請求暫時未被接受'),
            SizedBox(height: 12),
            Text(
              '建議：\n• 完善個人資料\n• 尋找其他合適的教練\n• 24小時後可重新嘗試',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // 增強的教練卡片（顯示配對狀態）
  Widget _buildCoachCard(DocumentSnapshot coachDoc) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    final coachBio = coachData['bio'] ?? '';
    final experience = coachData['experience'] ?? '';
    final specialties = List<String>.from(coachData['specialties'] ?? []);
    final certifications = List<String>.from(coachData['certifications'] ?? []);
    
    // 獲取配對狀態
    final pairStatus = _pairStatusCache[coachDoc.id] ?? PairStatus.none;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 教練資訊頭部
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                coachName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // 配對狀態標籤
                            _buildPairStatusBadge(pairStatus),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '認證教練',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (experience.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            experience,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              if (coachBio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  coachBio,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // 專業領域
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '專業領域：',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: specialties.take(3).map((specialty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        specialty,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              // 證照
              if (certifications.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.verified,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      certifications.first,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (certifications.length > 1)
                      Text(
                        ' +${certifications.length - 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
              
              const SizedBox(height: 16),
              
              // 智能聯繫按鈕（根據配對狀態變化）
              SizedBox(
                width: double.infinity,
                child: _buildContactButton(coachDoc, pairStatus),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 根據配對狀態顯示不同的標籤
  Widget _buildPairStatusBadge(PairStatus status) {
    switch (status) {
      case PairStatus.paired:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                '已配對',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
        
      case PairStatus.requestPending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pending_actions, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                '待回應',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
        
      case PairStatus.rejected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                '請稍候',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
        
      case PairStatus.none:
        return const SizedBox.shrink();
    }
  }

  // 根據配對狀態顯示不同的按鈕
  Widget _buildContactButton(DocumentSnapshot coachDoc, PairStatus status) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    
    switch (status) {
      case PairStatus.paired:
        return ElevatedButton.icon(
          onPressed: () => _contactCoach(coachDoc),
          icon: const Icon(Icons.chat),
          label: const Text('開始聊天'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        
      case PairStatus.requestPending:
        return OutlinedButton.icon(
          onPressed: () => _showPendingRequestDialog(coachName),
          icon: const Icon(Icons.pending_actions),
          label: const Text('請求處理中'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.orange),
            foregroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        
      case PairStatus.rejected:
        return OutlinedButton.icon(
          onPressed: () => _showRejectedDialog(),
          icon: const Icon(Icons.schedule),
          label: const Text('請稍後再試'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey),
            foregroundColor: Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        
      case PairStatus.none:
        return ElevatedButton.icon(
          onPressed: () => _contactCoach(coachDoc),
          icon: const Icon(Icons.person_add),
          label: const Text('發送配對請求'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  // 開啟現有聊天
  Future<void> _openExistingChat(String coachId, String coachName) async {
    try {
      final chatRoomId = await _chatService.createOrGetChatRoom(coachId);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatRoomId,
              chatName: coachName,
              lastMessage: '開始對話...',
              avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(coachName)}&background=22C55E&color=fff',
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('開啟聊天失敗：$e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 完成空白狀態的 UI
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '找不到符合條件的教練',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '嘗試調整搜索條件或清除篩選',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedSpecialties.clear();
                _filteredCoaches = _coaches;
              });
              _loadPairStatuses();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('清除篩選'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('尋找教練'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // 搜索區域
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索教練姓名...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 12),
                
                // 專業領域篩選
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        '專業領域：',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ..._specialtyOptions.map((specialty) {
                        final isSelected = _selectedSpecialties.contains(specialty);
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
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
                              _onSearchChanged();
                            },
                            selectedColor: Colors.green.withOpacity(0.2),
                            checkmarkColor: Colors.green,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 教練列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCoaches.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRecommendedCoaches,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCoaches.length,
                          itemBuilder: (context, index) {
                            return _buildCoachCard(_filteredCoaches[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}