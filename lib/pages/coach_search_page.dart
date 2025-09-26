import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import 'chat_detail_page.dart';

class CoachSearchPage extends StatefulWidget {
  const CoachSearchPage({super.key});

  @override
  State<CoachSearchPage> createState() => _CoachSearchPageState();
}

class _CoachSearchPageState extends State<CoachSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  
  List<DocumentSnapshot> _coaches = [];
  List<DocumentSnapshot> _filteredCoaches = [];
  List<String> _selectedSpecialties = [];
  bool _isLoading = true;
  bool _isSearching = false;
  
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

  // 修正：載入推薦教練（移除複雜查詢）
  Future<void> _loadRecommendedCoaches() async {
    setState(() => _isLoading = true);
    
    try {
      // 使用簡單查詢，避免索引問題
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .limit(20)
          .get(); // 移除所有 .orderBy() 條件
      
      // 在客戶端排序
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
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('載入教練列表失敗：$e');
    }
  }

  // 搜索變化監聽
  void _onSearchChanged() {
    if (_searchController.text.trim().isEmpty && _selectedSpecialties.isEmpty) {
      setState(() {
        _filteredCoaches = _coaches;
      });
      return;
    }
    
    _performSearch();
  }

  // 修正：執行搜索（移除複雜查詢）
  Future<void> _performSearch() async {
    setState(() => _isSearching = true);
    
    try {
      // 使用基礎查詢
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'coach')
          .limit(50) // 增加限制以便客戶端過濾
          .get();
      
      List<DocumentSnapshot> results = snapshot.docs;
      final searchTerm = _searchController.text.toLowerCase().trim();
      
      // 客戶端過濾
      if (searchTerm.isNotEmpty || _selectedSpecialties.isNotEmpty) {
        results = results.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // 姓名搜索
          bool matchesName = true;
          if (searchTerm.isNotEmpty) {
            final name = (data['displayName'] ?? '').toLowerCase();
            matchesName = name.contains(searchTerm);
          }
          
          // 專業領域搜索
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
        
        // 客戶端排序
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
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorSnackBar('搜索失敗：$e');
    }
  }

  // 聯繫教練
  Future<void> _contactCoach(DocumentSnapshot coachDoc) async {
    try {
      final coachData = coachDoc.data() as Map<String, dynamic>;
      final coachId = coachDoc.id;
      final coachName = coachData['displayName'] ?? '教練';
      
      // 檢查是否已經配對
      final isPaired = await _userService.isCoachStudentPaired(
        coachId, 
        _userService.currentUserId!,
      );
      
      if (isPaired) {
        // 已配對，直接開啟聊天
        _openExistingChat(coachId, coachName);
      } else {
        // 顯示配對確認對話框
        _showPairingDialog(coachDoc);
      }
    } catch (e) {
      _showErrorSnackBar('操作失敗：$e');
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

  // 顯示配對確認對話框
  void _showPairingDialog(DocumentSnapshot coachDoc) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    final coachBio = coachData['bio'] ?? '';
    final specialties = List<String>.from(coachData['specialties'] ?? []);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  coachName.isNotEmpty ? coachName[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coachName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '專業健身教練',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coachBio.isNotEmpty) ...[
              const Text(
                '關於教練：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                coachBio,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            if (specialties.isNotEmpty) ...[
              const Text(
                '專業領域：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: specialties.take(4).map((specialty) {
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
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            
            const Text(
              '與此教練配對後，您將可以：\n• 獲得個人化訓練指導\n• 即時聊天諮詢\n• 追蹤訓練進度',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performPairing(coachDoc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('開始配對'),
          ),
        ],
      ),
    );
  }

  // 執行配對
  Future<void> _performPairing(DocumentSnapshot coachDoc) async {
    try {
      final coachData = coachDoc.data() as Map<String, dynamic>;
      final coachId = coachDoc.id;
      final coachName = coachData['displayName'] ?? '教練';
      
      // 創建配對關係
      await _userService.createCoachStudentPair(
        coachId, 
        _userService.currentUserId!,
      );
      
      // 創建聊天室
      final chatRoomId = await _chatService.createOrGetChatRoom(coachId);
      
      // 發送歡迎訊息
      await _chatService.sendMessage(
        chatRoomId: chatRoomId,
        text: '您好！我想與您配對學習健身，請多指教！',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功與 $coachName 配對！'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 開啟聊天頁面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: chatRoomId,
              chatName: coachName,
              lastMessage: '您好！我想與您配對學習健身，請多指教！',
              avatarUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(coachName)}&background=22C55E&color=fff',
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('配對失敗：$e');
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredCoaches.length,
                        itemBuilder: (context, index) {
                          return _buildCoachCard(_filteredCoaches[index]);
                        },
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
            },
            child: const Text('清除篩選'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(DocumentSnapshot coachDoc) {
    final coachData = coachDoc.data() as Map<String, dynamic>;
    final coachName = coachData['displayName'] ?? '教練';
    final coachBio = coachData['bio'] ?? '';
    final experience = coachData['experience'] ?? '';
    final specialties = List<String>.from(coachData['specialties'] ?? []);
    final certifications = List<String>.from(coachData['certifications'] ?? []);
    
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
                        Text(
                          coachName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
              
              // 聯繫按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _contactCoach(coachDoc),
                  icon: const Icon(Icons.chat),
                  label: const Text('聯繫教練'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}