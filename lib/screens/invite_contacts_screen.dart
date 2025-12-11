import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:vidconf/config/app_config.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import '../services/invitation_service.dart';
import '../services/livekit_service.dart';
import '../services/auth_service.dart';
import '../widgets/call_type_selector.dart';
import '../widgets/modern_button.dart';
import 'outgoing_call_screen.dart';

class InviteContactsScreen extends StatefulWidget {
  final List<Contact>? preselectedContacts;

  const InviteContactsScreen({super.key, this.preselectedContacts});

  @override
  State<InviteContactsScreen> createState() => _InviteContactsScreenState();
}

class _InviteContactsScreenState extends State<InviteContactsScreen> {
  final ContactService _contactService = ContactService();
  final InvitationService _invitationService = InvitationService();
  final AuthService _authService = AuthService();
  List<Contact> _contacts = [];
  Set<int> _selectedContacts = {};
  CallType _selectedCallType = CallType.video;
  bool _isLoading = false;
  bool _isCreatingCall = false;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadContacts();
    if (widget.preselectedContacts != null) {
      _selectedContacts = widget.preselectedContacts!
          .map((c) => c.contactId)
          .toSet();
    }
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUsername = user?.username ?? '';
    });
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await _contactService.getContacts();
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load contacts: $e')));
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

  Future<void> _createCall() async {
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    setState(() {
      _isCreatingCall = true;
    });

    try {
      final selectedUsernames = _contacts
          .where((c) => _selectedContacts.contains(c.contactId))
          .map((c) => c.username)
          .toList();

      final result = await _invitationService.createCallAndInvite(
        _selectedCallType,
        selectedUsernames,
      );

      if (!mounted) return;

      final liveKitService = context.read<LiveKitService>();
      await liveKitService.connect(
        AppConfig().liveKitUrl,
        result.token,
        _selectedCallType,
      );

      if (mounted) {
        final firstContact = _contacts.firstWhere(
          (c) => selectedUsernames.contains(c.username),
          orElse: () => _contacts.first,
        );
        
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OutgoingCallScreen(
                  contactName: firstContact.username,
                  callType: _selectedCallType,
                  roomName: result.roomName,
                  userName: _currentUsername ?? '',
                  callId: result.callId,
                ),
              ),
            );
      }
    } catch (e) {
      setState(() {
        _isCreatingCall = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create call: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite to Call'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CallTypeSelector(
              selectedType: _selectedCallType,
              onTypeChanged: (type) {
                setState(() {
                  _selectedCallType = type;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Selected: ${_selectedContacts.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_selectedContacts.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedContacts.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.contacts,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No contacts available',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go to Contacts'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected = _selectedContacts.contains(
                        contact.contactId,
                      );
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(contact.username[0].toUpperCase()),
                        ),
                        title: Text(contact.username),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleContact(contact.contactId),
                        ),
                      ).animate().fadeIn(delay: (index * 30).ms);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ModernButton(
              text: 'Start Call',
              onPressed: _selectedContacts.isEmpty || _isCreatingCall
                  ? null
                  : _createCall,
              isLoading: _isCreatingCall,
              icon: Icons.video_call,
              width: double.infinity,
            ),
          ),
        ],
      ),
        ),
    );
  }
}
