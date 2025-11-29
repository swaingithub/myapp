import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  late UserModel _user;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadNickname();
    _fetchUserDetails();
  }

  void _fetchUserDetails() async {
    final user = await _databaseService.getUser(widget.user.uid);
    if (user != null && mounted) {
      setState(() {
        _user = user;
      });
    }
  }

  void _loadNickname() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user!.uid;

    _databaseService
        .getContactNicknameStream(currentUserId, widget.user.uid)
        .listen((nickname) {
      if (mounted) {
        setState(() {
          _nicknameController.text = nickname ?? _user.displayName ?? '';
        });
      }
    });
  }

  Future<void> _saveNickname() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user!.uid;

      await _databaseService.saveContactNickname(
        currentUserId,
        widget.user.uid,
        _nicknameController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nickname saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving nickname: $e')),
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = _user.email ?? _user.phoneNumber ?? 'Unknown';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Info'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              onPressed: _isLoading ? null : _saveNickname,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Hero(
                tag: 'profile_${_user.uid}',
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  backgroundImage: _user.photoUrl != null
                      ? NetworkImage(_user.photoUrl!)
                      : null,
                  child: _user.photoUrl == null
                      ? Text(
                          initial,
                          style: GoogleFonts.poppins(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildInfoTile(
              context,
              icon: Icons.person_outline_rounded,
              title: 'Name',
              content: _isEditing
                  ? TextField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter a friendly name',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                      autofocus: true,
                    )
                  : Text(
                      _nicknameController.text.isNotEmpty
                          ? _nicknameController.text
                          : (_user.displayName ?? 'No name set'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                    ),
            ),
            const SizedBox(height: 16),
            _buildInfoTile(
              context,
              icon: Icons.phone_outlined,
              title: 'Phone',
              content: Text(
                _user.phoneNumber ?? 'Not available',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoTile(
              context,
              icon: Icons.email_outlined,
              title: 'Email',
              content: Text(
                _user.email ?? 'Not available',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoTile(
              context,
              icon: Icons.info_outline_rounded,
              title: 'About',
              content: const Text(
                'Hey there! I am using Sanchar.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context,
      {required IconData icon,
      required String title,
      required Widget content}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
