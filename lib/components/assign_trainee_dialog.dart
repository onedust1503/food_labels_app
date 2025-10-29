// lib/components/assign_trainee_dialog.dart
// 🎯 訓練計畫分配學員對話框

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssignTraineeDialog extends StatefulWidget {
  final List<DocumentSnapshot> students;
  final Function(List<String> selectedIds) onAssign;
  final VoidCallback onSkip;

  const AssignTraineeDialog({
    super.key,
    required this.students,
    required this.onAssign,
    required this.onSkip,
  });

  @override
  State<AssignTraineeDialog> createState() => _AssignTraineeDialogState();
}

class _AssignTraineeDialogState extends State<AssignTraineeDialog> {
  final Set<String> _selectedIds = {};
  bool _selectAll = false;

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedIds.clear();
        _selectedIds.addAll(widget.students.map((s) => s.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.people, color: Colors.green),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('分配給學員'),
          ),
          if (widget.students.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(_selectAll ? '取消全選' : '全選'),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.students.isEmpty
            ? _buildEmptyState()
            : _buildStudentList(),
      ),
      actions: [
        TextButton(
          onPressed: widget.onSkip,
          child: const Text('稍後再說'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => widget.onAssign(_selectedIds.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Text(
            _selectedIds.isEmpty
                ? '確認分配'
                : '分配給 ${_selectedIds.length} 位學員',
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '沒有可分配的學員',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '請先配對學員後再創建訓練計畫',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.students.length,
      itemBuilder: (context, index) {
        final student = widget.students[index];
        final data = student.data() as Map<String, dynamic>;
        final name = data['displayName'] ?? '未命名';
        final email = data['email'] ?? '';
        final goal = data['goal'] ?? '';
        final isSelected = _selectedIds.contains(student.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 2 : 0,
          color: isSelected ? Colors.green.shade50 : null,
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedIds.add(student.id);
                } else {
                  _selectedIds.remove(student.id);
                }
              });
            },
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isSelected ? Colors.green : Colors.grey.shade300,
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (goal.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          goal,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            subtitle: email.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(left: 44, top: 4),
                    child: Text(
                      email,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : null,
            activeColor: Colors.green,
            checkColor: Colors.white,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      },
    );
  }
}