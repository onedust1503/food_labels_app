import 'package:flutter/material.dart';
import 'dart:async';
import '../services/chat_service.dart';

class ChatServiceTestPage extends StatefulWidget {
  const ChatServiceTestPage({super.key});

  @override
  State<ChatServiceTestPage> createState() => _ChatServiceTestPageState();
}

class _ChatServiceTestPageState extends State<ChatServiceTestPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _otherUserIdController = TextEditingController();
  
  String? _currentChatRoomId;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  @override
  void dispose() {
    _messageController.dispose();
    _otherUserIdController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatService 測試'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 創建聊天室區域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. 創建或獲取聊天室', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otherUserIdController,
                    decoration: const InputDecoration(
                      labelText: '輸入對方用戶 ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _createOrGetChatRoom,
                    child: const Text('創建/獲取聊天室'),
                  ),
                  if (_currentChatRoomId != null) ...[
                    const SizedBox(height: 8),
                    Text('聊天室 ID: $_currentChatRoomId', style: const TextStyle(color: Colors.green)),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 消息列表
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('2. 消息列表', style: TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton(
                          onPressed: _currentChatRoomId != null ? _loadMessages : null,
                          child: const Text('載入消息'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _messages.isEmpty
                              ? const Center(child: Text('暫無消息'))
                              : ListView.builder(
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    final isMe = message.isMe(_chatService.currentUserId ?? '');
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMe ? Colors.blue[100] : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                isMe ? '我' : '對方',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe ? Colors.blue : Colors.green,
                                                ),
                                              ),
                                              Text(
                                                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(message.text),
                                          if (!isMe) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              message.isRead ? '已讀' : '未讀',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: message.isRead ? Colors.green : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 發送消息區域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('3. 發送消息', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            labelText: '輸入消息',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _currentChatRoomId != null ? _sendMessage : null,
                        child: const Text('發送'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 創建或獲取聊天室
  Future<void> _createOrGetChatRoom() async {
    if (_otherUserIdController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請輸入對方用戶 ID')),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      final chatRoomId = await _chatService.createOrGetChatRoom(_otherUserIdController.text.trim());
      
      if (mounted) {
        setState(() {
          _currentChatRoomId = chatRoomId;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('聊天室創建成功：$chatRoomId')),
        );
        
        // 自動載入消息
        _loadMessages();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('創建聊天室失敗：$e')),
        );
      }
    }
  }

  // 載入消息
  void _loadMessages() {
    if (_currentChatRoomId == null) return;

    // 取消之前的訂閱
    _messagesSubscription?.cancel();

    setState(() => _isLoading = true);
    
    // 監聽消息流
    _messagesSubscription = _chatService.getMessagesStream(_currentChatRoomId!).listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('載入消息失敗：$error')),
          );
        }
      },
    );
  }

  // 發送消息
  Future<void> _sendMessage() async {
    if (_currentChatRoomId == null || _messageController.text.trim().isEmpty) {
      return;
    }

    try {
      await _chatService.sendMessage(
        chatRoomId: _currentChatRoomId!,
        text: _messageController.text.trim(),
      );
      
      _messageController.clear();
      
      // 消息會通過流自動更新，不需要手動重載
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發送消息失敗：$e')),
        );
      }
    }
  }
}