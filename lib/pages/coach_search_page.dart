import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/pair_request_service.dart'; // 新增
import '../widgets/pair_request_dialog.dart'; // 新增

class CoachSearchPage extends StatefulWidget {
  const CoachSearchPage({super.key});

  @override
  State<CoachSearchPage> createState() => _CoachSearchPageState();
}

class _CoachSearchPageState extends State<CoachSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final PairRequestService _pairRequestService = PairRequestService(); // 新增
  
  List<DocumentSnapshot> _coaches = [];
  List<DocumentSnapshot> _filteredCoaches = [];
  List<String> _selectedSpecialties = [];
  bool _isLoading = true;
  bool _isSearching = false;
  
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
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('載入教練列表失敗：$e');
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.trim().isEmpty && _selectedSpecialties.isEmpty) {
      setState(() {
        _filteredCoaches = _coaches;
      });
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
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorSnackBar('搜索失敗：$e');
    }
  }

  // 修改：顯示配對請求對話框（使用 PairRequestDialog）
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

  // 新增：發送配對請求方法
  Future<void> _sendPairRequest(String coachId, String message) async {
    try {
      await _pairRequestService.sendPairRequest(
        coachId: coachId,
        message: message,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配對請求已發送！等待教練回應'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('發送配對請求失敗：$e');
      rethrow;
    }
  }

  // 修改：聯繫教練（先檢查配對狀態）
  Future<void> _contactCoach(DocumentSnapshot coachDoc) async {
    try {
      final coachId = coachDoc.id;
      
      // 檢查配對狀態
      final pairStatus = await _pairRequestService.checkPairStatus(
        coachId, 
        _userService.currentUserId!,
      );
      
      if (pairStatus == PairRequestStatus.accepted) {
        // 已配對，顯示提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('您已經與此教練配對，可以在聊天頁面聯繫'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else if (pairStatus == PairRequestStatus.pending) {
        // 有待處理的請求
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('配對請求已發送，請等待教練回應'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // 未配對，顯示配對對話框
        _showPairingDialog(coachDoc);
      }
    } catch (e) {
      _showErrorSnackBar('操作失敗：$e');
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _contactCoach(coachDoc),
                  icon: const Icon(Icons.send),
                  label: const Text('發送配對請求'),
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