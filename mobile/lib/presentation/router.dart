import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/verify_otp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/call_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return VerifyOtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            contact: extra['contact'],
            conversation: extra['conversation'],
            currentUser: extra['currentUser'],
          );
        },
      GoRoute(
        path: '/create-group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/call',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CallScreen(
            targetUserId: extra['targetUserId'],
            conversationId: extra['conversationId'],
            incomingOffer: extra['offer'],
          );
        },
      ),
    ],
  );
});
