// lib/pages/nutrition/ocr_test_page.dart
import 'package:flutter/material.dart';
import 'ocr_scan_page.dart';

/// OCR 功能測試頁面
/// 用於快速測試掃描功能是否正常
class OcrTestPage extends StatelessWidget {
  const OcrTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR 測試'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.science,
                size: 100,
                color: Colors.blue[300],
              ),
              const SizedBox(height: 32),
              const Text(
                'OCR 功能測試',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '點擊下方按鈕測試營養標籤掃描功能',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OcrScanPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.document_scanner),
                  label: const Text(
                    '開始掃描測試',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[700]),
                        const SizedBox(width: 8),
                        const Text(
                          '測試提示',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('1. 首次使用需等待 30-50 秒啟動'),
                    const Text('2. 請拍攝清楚的營養標籤'),
                    const Text('3. 確保光線充足且無反光'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}