// lib/widgets/ocr_engine_selector.dart
// OCR 引擎選擇器 Widget

import 'package:flutter/material.dart';
import '../services/ocr_service.dart';

class OcrEngineSelector extends StatefulWidget {
  final Function(OcrEngine)? onEngineChanged;
  
  const OcrEngineSelector({super.key, this.onEngineChanged});

  @override
  State<OcrEngineSelector> createState() => _OcrEngineSelectorState();
}

class _OcrEngineSelectorState extends State<OcrEngineSelector> {
  OcrEngine _currentEngine = OcrEngine.google;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentEngine();
  }

  Future<void> _loadCurrentEngine() async {
    final engine = await OcrService.getCurrentEngine();
    setState(() {
      _currentEngine = engine;
      _isLoading = false;
    });
  }

  Future<void> _setEngine(OcrEngine engine) async {
    setState(() => _isLoading = true);
    await OcrService.setEngine(engine);
    setState(() {
      _currentEngine = engine;
      _isLoading = false;
    });
    widget.onEngineChanged?.call(engine);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.document_scanner, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text(
                'OCR 辨識引擎',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // YOLO 選項
          _buildEngineOption(
            engine: OcrEngine.yolo,
            title: '🤖 AI 辨識 (YOLO)',
            subtitle: '使用自訓練深度學習模型',
            description: '• 專為營養標籤優化\n• 首次較慢 (需暖機)\n• 適合展示技術成果',
            color: const Color(0xFF8B5CF6),
          ),
          
          const SizedBox(height: 12),
          
          // Google 選項
          _buildEngineOption(
            engine: OcrEngine.google,
            title: '☁️ 雲端辨識 (Google)',
            subtitle: 'Google Cloud Vision API',
            description: '• 辨識速度快 (1-3秒)\n• 準確度高\n• 每月1000次免費',
            color: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineOption({
    required OcrEngine engine,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
  }) {
    final isSelected = _currentEngine == engine;
    
    return GestureDetector(
      onTap: () => _setEngine(engine),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Check icon
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

/// 簡單版選擇器 (用於掃描頁面)
class OcrEngineQuickSelector extends StatefulWidget {
  final Function(OcrEngine)? onEngineChanged;
  
  const OcrEngineQuickSelector({super.key, this.onEngineChanged});

  @override
  State<OcrEngineQuickSelector> createState() => _OcrEngineQuickSelectorState();
}

class _OcrEngineQuickSelectorState extends State<OcrEngineQuickSelector> {
  OcrEngine _currentEngine = OcrEngine.google;

  @override
  void initState() {
    super.initState();
    _loadEngine();
  }

  Future<void> _loadEngine() async {
    final engine = await OcrService.getCurrentEngine();
    setState(() => _currentEngine = engine);
  }

  Future<void> _toggleEngine() async {
    final newEngine = _currentEngine == OcrEngine.yolo 
        ? OcrEngine.google 
        : OcrEngine.yolo;
    
    await OcrService.setEngine(newEngine);
    setState(() => _currentEngine = newEngine);
    widget.onEngineChanged?.call(newEngine);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleEngine,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _currentEngine == OcrEngine.yolo 
              ? const Color(0xFF8B5CF6).withOpacity(0.1)
              : const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _currentEngine == OcrEngine.yolo 
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF10B981),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentEngine == OcrEngine.yolo 
                  ? Icons.smart_toy 
                  : Icons.cloud,
              size: 16,
              color: _currentEngine == OcrEngine.yolo 
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF10B981),
            ),
            const SizedBox(width: 6),
            Text(
              _currentEngine == OcrEngine.yolo ? 'YOLO' : 'Google',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _currentEngine == OcrEngine.yolo 
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.swap_horiz,
              size: 14,
              color: Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }
}