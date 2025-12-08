import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';

import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Awesome Notifications
  await AwesomeNotifications().initialize(
    null, // icon: null means use the default app icon
    [
      NotificationChannel(
        channelGroupKey: 'basic_channel_group',
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Notification channel for basic tests',
        defaultColor: const Color(0xFF9D50DD),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
      )
    ],
    channelGroups: [
      NotificationChannelGroup(
        channelGroupKey: 'basic_channel_group',
        channelGroupName: 'Basic group',
      )
    ],
    debug: true,
  );

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await NotificationService().init(); // Initialize Notifications
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserOnline(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setUserOnline(false);
    }
  }

  Future<void> _setUserOnline(bool isOnline) async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _databaseService.updateUserPresence(user.uid, isOnline);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define a modern color scheme
    // Define a modern, advanced color scheme
    // "Deep Indigo" - a premium, tech-forward palette
    const Color primarySeed = Color(0xFF4F46E5); // Indigo 600
    const Color secondarySeed = Color(0xFF0EA5E9); // Sky 500
    
    // Light Theme Colors
    const Color lightBackground = Color(0xFFF3F4F6); // Cool Gray 100
    const Color lightSurface = Colors.white;
    
    // Dark Theme Colors
    const Color darkBackground = Color(0xFF0F172A); // Slate 900
    const Color darkSurface = Color(0xFF1E293B); // Slate 800

    // Define a common TextTheme with Poppins
    final TextTheme appTextTheme = TextTheme(
      displayLarge: GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      displayMedium: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, height: 1.5),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, height: 1.5),
      labelLarge: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );

    // Light Theme
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeed,
        primary: primarySeed,
        secondary: secondarySeed,
        surface: lightSurface,
        background: lightBackground,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: appTextTheme.apply(displayColor: Colors.black87, bodyColor: Colors.black87),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySeed,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primarySeed.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primarySeed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        labelStyle: GoogleFonts.poppins(color: Colors.black54),
        hintStyle: GoogleFonts.poppins(color: Colors.black38),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
    );

    // Dark Theme
    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeed,
        primary: primarySeed,
        secondary: secondarySeed,
        surface: darkSurface,
        background: darkBackground,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: appTextTheme.apply(
        bodyColor: Colors.white.withOpacity(0.87),
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primarySeed,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C3545), // Slightly lighter than surface
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primarySeed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        hintStyle: GoogleFonts.poppins(color: Colors.white38),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Sanchar Messaging App',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
