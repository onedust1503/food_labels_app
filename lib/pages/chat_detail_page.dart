// lib/pages/chat_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/chat_service.dart';
import '../components/workout_share_card_widget.dart';  // 包含 WorkoutShareCardWidget, WorkoutReplyQuote, ReplyMessageBubble

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String lastMessage;
  final String avatarUrl;
  final bool isOnline;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatName,
    this.lastMessage = '開始對話...',
    required this.avatarUrl,
    this.isOnline = false,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isComposing = false;
  bool _isUploading = false;
  
  // 🆕 修改：使用 ReplyData 替代 Map
  ReplyData? _replyToData;
  bool _isReplyingToHelp = false;
  
  late AnimationController _sendButtonController;

  @override
  void initState() {
    super.initState();
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    _chatService.getMessagesStream(widget.chatId).listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          _scrollToBottom();
          _chatService.markChatRoomAsRead(widget.chatId);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('載入消息失敗：$error')),
          );
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 🆕 修改：支援傳入回覆資料
  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    final replyData = _replyToData;  // 保存回覆引用
    
    _messageController.clear();
    setState(() {
      _isComposing = false;
      _replyToData = null;  // 清除回覆引用
      _isReplyingToHelp = false;
    });
    _sendButtonController.reverse();

    try {
      // 🆕 傳入回覆資料
      await _chatService.sendMessage(
        chatRoomId: widget.chatId,
        text: text.trim(),
        replyTo: replyData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送失敗：$e')),
        );
      }
    }
  }

  // ========== 圖片相關 ==========

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF6C63FF)),
                title: const Text('從相簿選擇'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF6C63FF)),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      await _chatService.sendImageMessage(
        chatRoomId: widget.chatId,
        imageFile: File(image.path),
      );

      if (mounted) {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送圖片失敗：$e')),
        );
      }
    }
  }

  void _showImagePreview(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImagePreviewPage(imageUrl: imageUrl),
      ),
    );
  }

  // ========== 訊息操作 ==========

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已複製訊息'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 🆕 修改：添加回覆選項
  void _showMessageOptions(ChatMessage message) {
    final currentUserId = _chatService.currentUserId;
    final isMe = message.isMe(currentUserId ?? '');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🆕 回覆功能
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFF6C63FF)),
                title: const Text('回覆'),
                onTap: () {
                  Navigator.pop(context);
                  _setReplyToMessage(message);
                },
              ),
              if (message.type == MessageType.text)
                ListTile(
                  leading: const Icon(Icons.copy, color: Color(0xFF6C63FF)),
                  title: const Text('複製訊息'),
                  onTap: () {
                    Navigator.pop(context);
                    _copyMessage(message.text);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 🔥 訓練分享卡片詳情 ==========

  void _showWorkoutDetails(Map<String, dynamic>? workoutData) {
    if (workoutData == null) return;
    
    final isPlan = workoutData['source'] == 'plan';
    final themeColor = isPlan ? Colors.orange : Colors.blue;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示條
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 標題列
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workoutData['workoutName'] ?? '訓練記錄',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isPlan && workoutData['planName'] != null)
                          Text(
                            workoutData['planName'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // 內容區域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 狀態標籤
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        workoutData['statusLabel'] ?? (isPlan ? '計畫訓練' : '自主訓練'),
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 訓練數據
                    _buildDetailSectionWithIcon(Icons.bar_chart, '訓練數據', [
                      _buildDetailRowWithIcon(Icons.timer_outlined, '時長', '${workoutData['durationMinutes'] ?? 0} 分鐘'),
                      _buildDetailRowWithIcon(Icons.local_fire_department_outlined, '消耗', '${(workoutData['caloriesBurned'] as num?)?.toStringAsFixed(0) ?? 0} 卡路里'),
                      _buildDetailRowWithIcon(Icons.fitness_center, '動作', '${workoutData['exerciseCount'] ?? 0} 個'),
                      _buildDetailRowWithIcon(Icons.repeat, '總組數', '${workoutData['totalSets'] ?? 0} 組'),
                    ]),
                    
                    // 訓練亮點
                    if (workoutData['highlights'] != null) ...[
                      const SizedBox(height: 20),
                      _buildDetailSectionWithIcon(Icons.emoji_events_outlined, '訓練亮點', [
                        if (workoutData['highlights']['maxWeight'] != null)
                          _buildDetailRow(
                            '最大重量',
                            '${workoutData['highlights']['maxWeight']} kg（${workoutData['highlights']['maxWeightExercise'] ?? ''}）',
                          ),
                        if (workoutData['highlights']['totalVolume'] != null)
                          _buildDetailRow(
                            '總訓練量',
                            '${((workoutData['highlights']['totalVolume'] as num) / 1000).toStringAsFixed(1)} 噸',
                          ),
                      ]),
                    ],
                    
                    // 訓練感受
                    if (workoutData['feedback'] != null) ...[
                      const SizedBox(height: 20),
                      _buildDetailSectionWithIcon(Icons.sentiment_satisfied_alt_outlined, '訓練感受', [
                        if (workoutData['feedback']['rpe'] != null)
                          _buildDetailRow('RPE', '${workoutData['feedback']['rpe']}/10'),
                        if (workoutData['feedback']['mood'] != null)
                          _buildDetailRow('心情', _getMoodLabel(workoutData['feedback']['mood'])),
                        if (workoutData['feedback']['fatigueLevel'] != null)
                          _buildDetailRow('疲勞度', _getFatigueLabel(workoutData['feedback']['fatigueLevel'])),
                        if (workoutData['feedback']['note'] != null && 
                            (workoutData['feedback']['note'] as String).isNotEmpty)
                          _buildDetailRow('備註', workoutData['feedback']['note']),
                      ]),
                    ],
                    
                    // 需要協助區塊
                    if (workoutData['feedback'] != null && 
                        workoutData['feedback']['needHelp'] == true) ...[
                      const SizedBox(height: 20),
                      _buildHelpSection(workoutData['feedback']),
                    ],
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // 帶 icon 的區塊標題
  Widget _buildDetailSectionWithIcon(IconData icon, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 帶 icon 的資料列
  Widget _buildDetailRowWithIcon(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMoodLabel(String mood) {
    switch (mood) {
      case 'great': return '超棒';
      case 'good': return '不錯';
      case 'okay': return '普通';
      case 'tired': return '有點累';
      case 'bad': return '很累';
      default: return mood;
    }
  }

  String _getFatigueLabel(String level) {
    switch (level) {
      case 'low': return '精力充沛';
      case 'medium': return '適度疲勞';
      case 'high': return '比較累';
      case 'exhausted': return '非常疲憊';
      default: return level;
    }
  }

  // 需要協助區塊（專業風格）
  Widget _buildHelpSection(Map<String, dynamic> feedback) {
    final helpMessage = feedback['helpMessage'] as String?;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '學生需要協助',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '待處理',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (helpMessage != null && helpMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.message_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '求助訊息',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    helpMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.red[700]),
                const SizedBox(width: 6),
                Text(
                  '學生標記需要協助，請主動關心',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // 快速回覆按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // 自動填入回覆訊息
                _messageController.text = '我看到你需要協助，有什麼我可以幫忙的嗎？';
                _messageController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _messageController.text.length),
                );
              },
              icon: const Icon(Icons.reply, size: 18),
              label: const Text('快速回覆'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== UI 構建 ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessageList(),
          ),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '正在上傳圖片...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D2D2D)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.avatarUrl.isNotEmpty
                    ? NetworkImage(widget.avatarUrl)
                    : null,
                backgroundColor: const Color(0xFFF5F3FF),
                child: widget.avatarUrl.isEmpty
                    ? Text(
                        widget.chatName.isNotEmpty ? widget.chatName[0] : '?',
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (widget.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                if (widget.isOnline)
                  Text(
                    '在線',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '開始對話',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '發送第一條訊息吧！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.isMe(_chatService.currentUserId ?? '');
        
        return GestureDetector(
          onLongPress: () => _showMessageOptions(message),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildMessageContent(message, isMe),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 16,
                        color: message.isRead ? const Color(0xFF6C63FF) : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '剛剛';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分鐘前';
    } else if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageMessage(message, isMe);
      case MessageType.workoutShare:
        return _buildWorkoutShareMessage(message, isMe);
      case MessageType.system:
        return _buildSystemMessage(message);
      case MessageType.text:
      default:
        return _buildTextMessage(message, isMe);
    }
  }

  // 🆕 修改：文字訊息支援顯示回覆引用
  Widget _buildTextMessage(ChatMessage message, bool isMe) {
    final hasReply = message.replyTo != null;
    
    // 🔍 DEBUG: 檢查回覆資料
    debugPrint('📩 訊息: "${message.text}" | hasReply: $hasReply | replyTo: ${message.replyTo?.previewText}');
    
    return Container(
      margin: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 🆕 回覆引用區塊
          if (hasReply)
            _buildMessageReplyQuote(message.replyTo!, isMe),
          // 訊息內容
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF6C63FF) : const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(hasReply ? 4 : 20),
                topRight: Radius.circular(hasReply ? 4 : 20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF2D2D2D),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 構建訊息中的回覆引用
  Widget _buildMessageReplyQuote(ReplyData replyData, bool isMe) {
    final isWorkout = replyData.messageType == 'workout_share';
    final isImage = replyData.messageType == 'image';
    final needsHelp = replyData.workoutData?['feedback']?['needHelp'] == true;
    
    Color themeColor;
    if (needsHelp) {
      themeColor = Colors.red;
    } else if (isWorkout) {
      themeColor = const Color(0xFFFF9800);
    } else {
      themeColor = Colors.grey[600]!;
    }
    
    IconData leadingIcon;
    if (isWorkout) {
      leadingIcon = Icons.fitness_center;
    } else if (isImage) {
      leadingIcon = Icons.image;
    } else {
      leadingIcon = Icons.chat_bubble_outline;
    }
    
    // 根據是否為自己的訊息和是否需要協助，決定背景和文字顏色
    final Color bgColor;
    final Color textColor;
    final Color senderColor;
    
    if (needsHelp) {
      // 需要協助：淺紅色背景，深色文字
      bgColor = Colors.red[50]!;
      textColor = Colors.grey[800]!;
      senderColor = Colors.red;
    } else if (isMe) {
      // 🆕 自己的訊息：淺紫色背景（與訊息氣泡搭配）
      bgColor = const Color(0xFF5A52D5);  // 比訊息氣泡深一點
      textColor = Colors.white;
      senderColor = Colors.white.withOpacity(0.8);
    } else {
      // 對方的訊息：淺灰色背景
      bgColor = Colors.grey[200]!;
      textColor = Colors.grey[700]!;
      senderColor = themeColor;
    }
    
    // 🆕 使用 ConstrainedBox 確保引用區塊有最小寬度
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 240),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          border: Border(
            left: BorderSide(
              color: needsHelp ? Colors.red : (isMe ? Colors.white.withOpacity(0.5) : themeColor),
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(leadingIcon, size: 14, color: isMe ? Colors.white.withOpacity(0.8) : themeColor),
            const SizedBox(width: 6),
            Expanded(  // 🆕 改用 Expanded 確保文字區域正確展開
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 發送者名稱
                  if (replyData.senderName != null)
                    Text(
                      replyData.senderName!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: senderColor,
                      ),
                    ),
                  // 預覽文字（訓練名稱或訊息內容）
                  Text(
                    replyData.previewText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 🆕 需要協助標籤（獨立顯示）
                  if (needsHelp) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.support_agent, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            '需要協助',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(ChatMessage message, bool isMe) {
    return GestureDetector(
      onTap: () => _showImagePreview(message.imageUrl!),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        margin: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF6C63FF) : const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          child: message.imageUrl != null
              ? Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.grey[400], size: 40),
                          const SizedBox(height: 8),
                          Text('圖片載入失敗', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  },
                )
              : Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image, size: 40),
                ),
        ),
      ),
    );
  }

  // 訓練分享卡片訊息
  Widget _buildWorkoutShareMessage(ChatMessage message, bool isMe) {
    return Container(
      margin: EdgeInsets.only(left: isMe ? 40 : 0, right: isMe ? 0 : 40),
      child: WorkoutShareCardWidget(
        workoutData: message.workoutData ?? {},
        isMe: isMe,
        onTap: () => _showWorkoutDetails(message.workoutData),
        onReply: isMe ? null : () => _setReplyToWorkout(message.workoutData),
      ),
    );
  }
  
  // 🆕 修改：使用 ReplyData 設定回覆引用
  void _setReplyToWorkout(Map<String, dynamic>? workoutData) {
    if (workoutData == null) return;
    
    HapticFeedback.lightImpact();
    
    final needsHelp = workoutData['feedback']?['needHelp'] == true;
    
    setState(() {
      _replyToData = _chatService.createReplyDataFromWorkout(
        workoutData,
        senderName: widget.chatName,
      );
      _isReplyingToHelp = needsHelp;
    });
    
    // 預填回覆訊息（如果需要協助）
    if (needsHelp && _messageController.text.isEmpty) {
      _messageController.text = '我看到你需要協助，';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
      setState(() => _isComposing = true);
      _sendButtonController.forward();
    }
  }
  
  // 🆕 設定回覆普通訊息
  void _setReplyToMessage(ChatMessage message) {
    HapticFeedback.lightImpact();
    
    final currentUserId = _chatService.currentUserId;
    final isMe = message.senderId == currentUserId;
    
    setState(() {
      _replyToData = _chatService.createReplyDataFromMessage(
        message,
        senderName: isMe ? '你' : widget.chatName,
      );
      _isReplyingToHelp = false;
    });
  }
  
  // 取消回覆引用
  void _cancelReply() {
    setState(() {
      _replyToData = null;
      _isReplyingToHelp = false;
    });
  }

  // 系統訊息
  Widget _buildSystemMessage(ChatMessage message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  // 🆕 修改：輸入框支援回覆引用顯示
  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🆕 回覆引用區塊（使用新的 ReplyData）
          if (_replyToData != null)
            _buildReplyQuoteInComposer(),
          // 輸入區
          Padding(
            padding: EdgeInsets.only(
              top: _replyToData != null ? 8 : 0,
            ),
            child: Row(
              children: [
                // 圖片按鈕
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.image, size: 20),
                    color: const Color(0xFF6C63FF),
                    onPressed: _isUploading ? null : _showImageSourceOptions,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                // 輸入框
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _replyToData != null ? '回覆訊息...' : '輸入訊息...',
                        hintStyle: const TextStyle(color: Color(0xFFB8B8B8)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (text) {
                        setState(() => _isComposing = text.trim().isNotEmpty);
                        if (_isComposing) {
                          _sendButtonController.forward();
                        } else {
                          _sendButtonController.reverse();
                        }
                      },
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 發送按鈕
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(parent: _sendButtonController, curve: Curves.easeOut),
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isReplyingToHelp
                          ? Colors.red
                          : const Color(0xFF2D2D2D),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _replyToData != null ? Icons.reply : Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _isComposing ? () => _handleSubmitted(_messageController.text) : null,
                      padding: EdgeInsets.zero,
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

  // 🆕 構建輸入框上方的回覆引用
  Widget _buildReplyQuoteInComposer() {
    if (_replyToData == null) return const SizedBox.shrink();
    
    final isWorkout = _replyToData!.messageType == 'workout_share';
    final isImage = _replyToData!.messageType == 'image';
    final themeColor = _isReplyingToHelp 
        ? Colors.red 
        : (isWorkout ? const Color(0xFFFF9800) : const Color(0xFF6C63FF));
    
    IconData leadingIcon;
    if (isWorkout) {
      leadingIcon = Icons.fitness_center;
    } else if (isImage) {
      leadingIcon = Icons.image;
    } else {
      leadingIcon = Icons.reply;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isReplyingToHelp ? Colors.red[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: themeColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(leadingIcon, size: 16, color: themeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '回覆 ${_replyToData!.senderName ?? ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: themeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToData!.previewText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isReplyingToHelp)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.support_agent, size: 12, color: Colors.red[700]),
                        const SizedBox(width: 4),
                        Text(
                          '需要協助',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }
}

// 圖片預覽頁面
class _ImagePreviewPage extends StatelessWidget {
  final String imageUrl;

  const _ImagePreviewPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 60),
                    SizedBox(height: 16),
                    Text(
                      '圖片載入失敗',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}