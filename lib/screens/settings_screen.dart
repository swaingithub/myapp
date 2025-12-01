import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Stream<UserModel?> _userStream;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _userStream = _databaseService.getUserStream(authProvider.user!.uid);
    } else {
      _userStream = const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Use data from snapshot or fallback to a default model if null
          final userData = snapshot.data ??
              UserModel(
                uid: user.uid,
                displayName: user.displayName,
                email: user.email,
                phoneNumber: user.phoneNumber,
                photoUrl: user.photoURL,
                showOnlineStatus: true,
              );

          return ListView(
            children: [
              // Privacy Section
              _buildSectionHeader(context, 'Privacy'),
              SwitchListTile(
                title: const Text('Show Online Status'),
                subtitle: const Text(
                    'Allow others to see when you are online. If disabled, you also won\'t see others\' status.'),
                value: userData.showOnlineStatus,
                onChanged: (bool value) async {
                  try {
                    await _databaseService.updateShowOnlineStatus(
                        user.uid, value);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating status: $e')),
                      );
                    }
                  }
                },
                secondary: const Icon(Icons.visibility_rounded),
              ),

              const Divider(),

              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (bool value) {
                  themeProvider.toggleTheme();
                },
                secondary: const Icon(Icons.dark_mode_rounded),
              ),

              const Divider(),

              // Account Section
              _buildSectionHeader(context, 'Account'),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title:
                    const Text('Log Out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  // Handle logout
                  await authProvider.signOut();
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
