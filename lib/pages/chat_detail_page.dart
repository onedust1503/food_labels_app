// lib/pages/chat_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import '../services/chat_service.dart';
import 'package:image_picker/image_picker.dart';

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
    required this.lastMessage,
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
  final ImagePicker _imagePicker = ImagePicker();  // ✅ 新增
  
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isComposing = false;
  bool _isUploading = false;  // ✅ 新增：上傳中狀態
  
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
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _initializeChat() {
    _messagesSubscription = _chatService.getMessagesStream(widget.chatId).listen(
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

  // ✅ 保持原有的發送文字訊息功能
  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() => _isComposing = false);
    _sendButtonController.reverse();

    try {
      await _chatService.sendMessage(
        chatRoomId: widget.chatId,
        text: text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送失敗：$e')),
        );
      }
    }
  }

  // ✅ 新增：選擇並發送圖片
  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final imageFile = File(pickedFile.path);
      await _chatService.sendImageMessage(
        chatRoomId: widget.chatId,
        imageFile: imageFile,
      );

      setState(() => _isUploading = false);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送圖片失敗：$e')),
        );
      }
    }
  }

  // ✅ 新增：顯示圖片來源選擇
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF6C63FF)),
                ),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF6C63FF)),
                ),
                title: const Text('從相簿選擇'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E4F3),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8E4F3), Color(0xFFD4CEE8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildChatContainer()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(widget.avatarUrl),
                      backgroundColor: Colors.grey[300],
                    ),
                    if (widget.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
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
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        widget.isOnline ? '線上' : '離線',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_horiz, size: 20),
              onPressed: () {},
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatContainer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessagesList(),
          ),
          // ✅ 新增：上傳進度指示器
          if (_isUploading) _buildUploadingIndicator(),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  // ✅ 新增：上傳中指示器
  Widget _buildUploadingIndicator() {
    return Container(
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
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('開始對話吧！', style: TextStyle(fontSize: 18, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLastMessage = index == _messages.length - 1;
        final showTimestamp = index == 0 ||
            _messages[index - 1].timestamp.difference(message.timestamp).inMinutes.abs() > 5;

        return Column(
          children: [
            if (showTimestamp) _buildTimestamp(message.timestamp),
            _buildMessageBubble(message, isLastMessage),
          ],
        );
      },
    );
  }

  Widget _buildTimestamp(DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        _formatTimestamp(timestamp),
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) return '${difference.inDays} 天前';
    if (difference.inHours > 0) return '${difference.inHours} 小時前';
    if (difference.inMinutes > 0) return '${difference.inMinutes} 分鐘前';
    return '剛剛';
  }

  // ✅ 更新：根據訊息類型顯示不同內容
  Widget _buildMessageBubble(ChatMessage message, bool isLastMessage) {
    final currentUserId = _chatService.currentUserId;
    final isMe = message.isMe(currentUserId ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(widget.avatarUrl),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: message.type == MessageType.image
                ? _buildImageMessage(message, isMe)
                : _buildTextMessage(message, isMe),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            if (isLastMessage)
              Icon(
                message.isRead ? Icons.done_all : Icons.done,
                size: 16,
                color: message.isRead ? const Color(0xFF6C63FF) : Colors.grey[400],
              ),
          ],
        ],
      ),
    );
  }

  // ✅ 原有的文字訊息氣泡
  Widget _buildTextMessage(ChatMessage message, bool isMe) {
    return Container(
      margin: EdgeInsets.only(left: isMe ? 60 : 0, right: isMe ? 0 : 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF6C63FF) : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
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
    );
  }

  // ✅ 新增：圖片訊息氣泡
  Widget _buildImageMessage(ChatMessage message, bool isMe) {
    return Container(
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
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          // ✅ 更新：點擊顯示圖片來源選擇
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
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: '輸入訊息...',
                  hintStyle: TextStyle(color: Color(0xFFB8B8B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: _sendButtonController, curve: Curves.easeOut),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF2D2D2D),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isComposing ? Icons.arrow_upward : Icons.mic,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _isComposing ? () => _handleSubmitted(_messageController.text) : () {},
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}