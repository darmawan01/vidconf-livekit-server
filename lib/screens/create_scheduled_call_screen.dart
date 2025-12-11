import 'package:flutter/material.dart';
import '../models/scheduled_call.dart';
import '../models/contact.dart';
import '../services/scheduled_service.dart';
import '../services/contact_service.dart';
import '../services/livekit_service.dart';

class CreateScheduledCallScreen extends StatefulWidget {
  const CreateScheduledCallScreen({super.key});

  @override
  State<CreateScheduledCallScreen> createState() => _CreateScheduledCallScreenState();
}

class _CreateScheduledCallScreenState extends State<CreateScheduledCallScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '0');
  final _maxDurationController = TextEditingController(text: '0');
  final _scheduledService = ScheduledService();
  final _contactService = ContactService();

  CallType _callType = CallType.video;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime = TimeOfDay.now();
  RecurrenceType _recurrenceType = RecurrenceType.none;
  bool _isLoading = false;
  List<Contact> _contacts = [];
  final Set<int> _selectedContacts = {};
  bool _isLoadingContacts = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  Future<void> _createScheduledCall() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final scheduledAt = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

      final recurrence = _recurrenceType != RecurrenceType.none
          ? RecurrencePattern(type: _recurrenceType)
          : null;

      final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 0;
      final maxDurationSeconds = int.tryParse(_maxDurationController.text) ?? 0;

      final selectedUsernames = _contacts
          .where((c) => _selectedContacts.contains(c.contactId))
          .map((c) => c.username)
          .toList();

      await _scheduledService.createScheduledCall(
        callType: _callType,
        scheduledAt: scheduledAt,
        timezone: 'UTC',
        invitees: selectedUsernames,
        recurrence: recurrence,
        title: _titleController.text,
        description: _descriptionController.text,
        maxParticipants: maxParticipants,
        maxDurationSeconds: maxDurationSeconds,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled call created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoadingContacts = true;
    });

    try {
      final contacts = await _contactService.getContacts();
      setState(() {
        _contacts = contacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load contacts: $e')),
        );
      }
    }
  }

  void _toggleContact(int contactId) {
    setState(() {
      if (_selectedContacts.contains(contactId)) {
        _selectedContacts.remove(contactId);
      } else {
        _selectedContacts.add(contactId);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxParticipantsController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Call'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CallType>(
              value: _callType,
              decoration: const InputDecoration(
                labelText: 'Call Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: CallType.video, child: Text('Video')),
                DropdownMenuItem(value: CallType.voice, child: Text('Voice')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _callType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date'),
              subtitle: Text('${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(_scheduledTime.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: _selectTime,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurrenceType>(
              value: _recurrenceType,
              decoration: const InputDecoration(
                labelText: 'Recurrence',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: RecurrenceType.none, child: Text('None')),
                DropdownMenuItem(value: RecurrenceType.daily, child: Text('Daily')),
                DropdownMenuItem(value: RecurrenceType.weekly, child: Text('Weekly')),
                DropdownMenuItem(value: RecurrenceType.monthly, child: Text('Monthly')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _recurrenceType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Invite Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isLoadingContacts)
              const Center(child: CircularProgressIndicator())
            else if (_contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No contacts available. Add contacts to invite them.'),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    final isSelected = _selectedContacts.contains(contact.contactId);
                    return CheckboxListTile(
                      title: Text(contact.username),
                      value: isSelected,
                      onChanged: (value) => _toggleContact(contact.contactId),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxParticipantsController,
              decoration: const InputDecoration(
                labelText: 'Max Participants (0 = unlimited)',
                border: OutlineInputBorder(),
                helperText: 'Enter 0 for unlimited participants',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final num = int.tryParse(value);
                  if (num == null || num < 0) {
                    return 'Please enter a valid number (0 or greater)';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxDurationController,
              decoration: const InputDecoration(
                labelText: 'Max Duration (seconds, 0 = unlimited)',
                border: OutlineInputBorder(),
                helperText: 'Enter 0 for unlimited duration',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final num = int.tryParse(value);
                  if (num == null || num < 0) {
                    return 'Please enter a valid number (0 or greater)';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _createScheduledCall,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Schedule Call'),
            ),
          ],
        ),
      ),
        ),
    );
  }
}

