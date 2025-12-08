import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/subtask.dart';
import '../../data/localization.dart';

/// A bottom sheet for editing subtasks
class SubTaskEditorSheet extends ConsumerStatefulWidget {
  final List<SubTask> initialSubTasks;
  final Duration totalDuration;
  final Function(List<SubTask>) onSave;
  final bool showStartButton; 
  final VoidCallback? onStart;

  const SubTaskEditorSheet({
    super.key,
    required this.initialSubTasks,
    required this.totalDuration,
    required this.onSave,
    this.showStartButton = false,
    this.onStart,
  });

  @override
  ConsumerState<SubTaskEditorSheet> createState() => _SubTaskEditorSheetState();
}

class _SubTaskEditorSheetState extends ConsumerState<SubTaskEditorSheet> {
  late List<_EditableSubTask> _subTasks;
  final _uuid = const Uuid();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _subTasks = widget.initialSubTasks.map((st) => _EditableSubTask(
      id: st.id,
      titleController: TextEditingController(text: st.title),
      durationMinutes: st.estimatedDuration.inMinutes,
    )).toList();
  }
  
  @override
  void dispose() {
    for (var st in _subTasks) {
      st.titleController.dispose();
      st.focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  int get _totalMinutes => _subTasks.fold(0, (sum, st) => sum + st.durationMinutes);
  int get _targetMinutes => widget.totalDuration.inMinutes;
  int get _remainingMinutes => _targetMinutes - _totalMinutes;

  String t(String key) => AppStrings.get(key, ref.read(localeProvider));

  @override
  Widget build(BuildContext context) {
    final isValid = _totalMinutes == _targetMinutes && _subTasks.isNotEmpty;
    // Calculate keyboard padding
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset), // Adjust for keyboard
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  t('edit_steps'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Time indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isValid ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalMinutes / $_targetMinutes ${t('minutes')}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Remaining time hint
          if (_remainingMinutes != 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                _remainingMinutes > 0 
                    ? '${t('remaining')}: $_remainingMinutes ${t('minutes')}'
                    : '${t('exceeded')}: ${-_remainingMinutes} ${t('minutes')}',
                style: TextStyle(
                  fontSize: 12,
                  color: _remainingMinutes > 0 ? Colors.blue : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          
          const Divider(height: 16),
          
          // Subtask list + Add Button
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: _subTasks.length + 1, // +1 for Add Button
              itemBuilder: (context, index) {
                if (index == _subTasks.length) {
                  return _buildAddButton();
                }
                return _buildSubTaskItem(index);
              },
            ),
          ),
          
          // Bottom Action Buttons
          if (bottomInset == 0) // Hide buttons when keyboard is open to save space
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(t('cancel'), style: const TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isValid ? _onSave : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.showStartButton ? Colors.green : Colors.black,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        widget.showStartButton ? t('start_now') : t('save'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Simple Done button when keyboard is visible
            Padding(
               padding: const EdgeInsets.all(8.0),
               child: Align(
                 alignment: Alignment.centerRight,
                 child: TextButton(
                   onPressed: () => FocusScope.of(context).unfocus(),
                   child: const Text("Done"),
                 ),
               ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubTaskItem(int index) {
    final st = _subTasks[index];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(st.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) {
                setState(() {
                  _subTasks.removeAt(index);
                });
              },
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              icon: Icons.delete_outline,
              label: 'Delete',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Index Badge
                Container(
                  width: 24, height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Title (Inline Edit)
                Expanded(
                  child: TextField(
                    controller: st.titleController,
                    focusNode: st.focusNode,
                    decoration: InputDecoration(
                      hintText: t('step_title'),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                       // Optional: move focus to next or close keyboard
                    },
                  ),
                ),
                
                // Duration (Click to edit)
                GestureDetector(
                  onTap: () => _showDurationPicker(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${st.durationMinutes} ${t('minutes')}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAddButton() {
    // Always enable add button
    // If minutes exceeded, just default to 1 min or something small
    
    return GestureDetector(
      onTap: _addSubTask,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
             color: Colors.black.withOpacity(0.1),
             style: BorderStyle.solid
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add, 
            color: Colors.black,
            size: 24
          ),
        ),
      ),
    );
  }

  void _addSubTask() {
    // Determine default duration: remaining time or 5 mins
    int defaultDuration = _remainingMinutes > 0 ? _remainingMinutes : 5;
    if (defaultDuration <= 0) defaultDuration = 5;

    final newSubTask = _EditableSubTask(
      id: _uuid.v4(),
      titleController: TextEditingController(),
      durationMinutes: defaultDuration,
    );

    setState(() {
      _subTasks.add(newSubTask);
    });
    
    // Auto focus the new field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        newSubTask.focusNode.requestFocus();
      }
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Picker to edit duration
  void _showDurationPicker(int index) {
    // Calculate max possible duration for this task
    int othersTotal = 0;
    for (int i = 0; i < _subTasks.length; i++) {
      if (i != index) othersTotal += _subTasks[i].durationMinutes;
    }
    final maxAvailable = _targetMinutes - othersTotal; 
    final current = _subTasks[index].durationMinutes;
    final limit = _targetMinutes; 
    
    int selectedValue = current;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('cancel')),
                  ),
                  Column(
                    children: [
                      Text('${t('step')} ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (maxAvailable > 0)
                        Text(
                          'Max recommended: $maxAvailable ${t('minutes')}', 
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600)
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _subTasks[index].durationMinutes = selectedValue;
                      });
                    },
                    child: Text(t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListWheelScrollView.useDelegate(
                itemExtent: 40,
                physics: const FixedExtentScrollPhysics(),
                controller: FixedExtentScrollController(initialItem: current - 1),
                onSelectedItemChanged: (index) {
                  selectedValue = index + 1;
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: limit, // Allow selecting up to full duration
                  builder: (context, index) {
                    final value = index + 1;
                    return Center(
                      child: Text(
                        '$value ${t('minutes')}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: value == current ? FontWeight.bold : FontWeight.normal,
                          color: value > maxAvailable && maxAvailable > 0 ? Colors.orange : Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSave() {
    final result = _subTasks.map((st) => SubTask(
      id: st.id,
      title: st.titleController.text.trim().isNotEmpty 
          ? st.titleController.text.trim() 
          : '${t('step')} ${_subTasks.indexOf(st) + 1}',
      estimatedDuration: Duration(minutes: st.durationMinutes),
    )).toList();
    
    // Close the sheet first
    Navigator.pop(context);
    
    // Then trigger callbacks
    widget.onSave(result);
    
    if (widget.showStartButton && widget.onStart != null) {
      widget.onStart!();
    }
  }
}

class _EditableSubTask {
  final String id;
  final TextEditingController titleController;
  final FocusNode focusNode = FocusNode();
  int durationMinutes;

  _EditableSubTask({
    required this.id,
    required this.titleController,
    required this.durationMinutes,
  });
}
