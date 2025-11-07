import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:Maya/utils/constants.dart';

class EditToDoDialog extends StatefulWidget {
  final Map<String, dynamic> todo;
  final Function(int, String, String, String, bool, String?) onUpdate;
  final Function(int) onDelete;

  const EditToDoDialog({
    super.key,
    required this.todo,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  _EditToDoDialogState createState() => _EditToDoDialogState();
}

class _EditToDoDialogState extends State<EditToDoDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String status;
  late DateTime? selectedDateTime;
  String? dateTimeError;
  String? priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.todo['description'] ?? '');
    status = widget.todo['status'] ?? 'pending';
    selectedDateTime = widget.todo['reminder_time'] != null
        ? DateTime.tryParse(widget.todo['reminder_time'])
        : null;
    priority = widget.todo['priority'] ?? 'medium';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isValidDateTime = selectedDateTime == null || !selectedDateTime!.isBefore(now);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit To-Do',
                      style: kTitleStyle.copyWith(
                        color: const Color(0xFF1F2937), // gray-800
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FeatherIcons.x, color: Color(0xFF6B7280)), // gray-500
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFBBF7D0).withOpacity(0.2), // green-200/20
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF86EFAC)), // green-300
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: kBodyStyle.copyWith(color: const Color(0xFF1F2937)), // gray-800
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFBBF7D0).withOpacity(0.2), // green-200/20
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF86EFAC)), // green-300
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: kBodyStyle.copyWith(color: const Color(0xFF1F2937)), // gray-800
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFBBF7D0).withOpacity(0.2), // green-200/20
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF86EFAC)), // green-300
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        initialValue: status,
                        items: ['Todo', 'in-progress', 'completed']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (val) => setState(() => status = val!),
                        dropdownColor: Colors.white.withOpacity(0.3),
                        style: kBodyStyle.copyWith(color: const Color(0xFF1F2937)), // gray-800
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFBBF7D0).withOpacity(0.2), // green-200/20
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF86EFAC)), // green-300
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        initialValue: priority,
                        items: ['low', 'medium', 'high']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (val) => setState(() => priority = val!),
                        dropdownColor: Colors.white.withOpacity(0.3),
                        style: kBodyStyle.copyWith(color: const Color(0xFF1F2937)), // gray-800
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Reminder Time',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFBBF7D0).withOpacity(0.2), // green-200/20
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Color(0xFF86EFAC)), // green-300
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                hintText: selectedDateTime == null
                                    ? 'Select date & time'
                                    : DateFormat('yyyy-MM-dd HH:mm').format(selectedDateTime!),
                                errorText: dateTimeError,
                              ),
                              onTap: () async {
                                final DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDateTime ?? now,
                                  firstDate: now,
                                  lastDate: DateTime(2100),
                                );
                                if (pickedDate != null) {
                                  final TimeOfDay? pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: selectedDateTime != null
                                        ? TimeOfDay.fromDateTime(selectedDateTime!)
                                        : TimeOfDay.fromDateTime(now),
                                  );
                                  if (pickedTime != null) {
                                    final selected = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                    setState(() {
                                      if (selected.isBefore(now)) {
                                        dateTimeError = 'Cannot select a past date/time';
                                        selectedDateTime = null;
                                      } else {
                                        dateTimeError = null;
                                        selectedDateTime = selected;
                                      }
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(FeatherIcons.calendar, color: Color(0xFF15803D)), // green-700
                            onPressed: () async {
                              final DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDateTime ?? now,
                                firstDate: now,
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                final TimeOfDay? pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: selectedDateTime != null
                                      ? TimeOfDay.fromDateTime(selectedDateTime!)
                                      : TimeOfDay.fromDateTime(now),
                                );
                                if (pickedTime != null) {
                                  final selected = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                  setState(() {
                                    if (selected.isBefore(now)) {
                                      dateTimeError = 'Cannot select a past date/time';
                                      selectedDateTime = null;
                                    } else {
                                      dateTimeError = null;
                                      selectedDateTime = selected;
                                    }
                                  });
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280), // gray-500
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValidDateTime ? const Color(0xFF15803D) : kTextHint, // green-700
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: kTextHint,
                      ),
                      onPressed: isValidDateTime
                          ? () {
                              try {
                                final id = widget.todo['ID'] is int
                                    ? widget.todo['ID']
                                    : int.tryParse(widget.todo['ID'].toString()) ?? -1;
                                if (id == -1) throw Exception('Invalid ID');
                                final reminderTimeStr = selectedDateTime != null
                                    ? DateFormat("yyyy-MM-dd'T'HH:mm:ssZ").format(selectedDateTime!.toUtc())
                                    : null;
                                widget.onUpdate(
                                  id,
                                  _titleController.text,
                                  _descriptionController.text,
                                  status,
                                  reminderTimeStr != null,
                                  reminderTimeStr,
                                );
                                Navigator.pop(context);
                              } catch (e) {
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(content: Text('Error updating to-do: $e')),
                                // );
                              }
                            }
                          : null,
                      child: const Text('Update', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFBE123C), // rose-700
                      ),
                      onPressed: () {
                        try {
                          final id = widget.todo['ID'] is int
                              ? widget.todo['ID']
                              : int.tryParse(widget.todo['ID'].toString()) ?? -1;
                          if (id == -1) throw Exception('Invalid ID');
                          widget.onDelete(id);
                          Navigator.pop(context);
                        } catch (e) {
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(content: Text('Error deleting to-do: $e')),
                          // );
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}