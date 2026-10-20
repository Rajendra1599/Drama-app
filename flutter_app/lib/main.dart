import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'models/user_role.dart';
import 'providers/auth_provider.dart';
import 'providers/drama_provider.dart';
import 'services/local_storage_service.dart';
import 'services/web_video_interop.dart';
import 'services/rewarded_ad_manager.dart';

import 'widgets/story_top_bar.dart';
import 'widgets/story_bottom_nav.dart';
import 'widgets/autopay_dialog.dart';
import 'widgets/payment_verification_dialog.dart';
import 'widgets/policies_dialog.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/popular_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/drama_detail_screen.dart';
import 'screens/vertical_player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await LocalStorageService.init();
  } catch (e) {
    debugPrint('⚠️ [Init] LocalStorageService init error: $e');
  }

  try {
    await RewardedAdManager.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ [Init] RewardedAdManager init error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DramaProvider()),
      ],
      child: const StoryUpApp(),
    ),
  );
}

class StoryUpApp extends StatelessWidget {
  const StoryUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoryUp - MicroDrama OTT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      home: const MainNavigationWrapper(),
    );
  }
}

class MainNavigationWrapper extends StatelessWidget {
  const MainNavigationWrapper({super.key});

  int _getTabIndex(AppScreen screen) {
    switch (screen) {
      case AppScreen.home:
        return 0;
      case AppScreen.popular:
        return 1;
      case AppScreen.explore:
        return 2;
      case AppScreen.library:
        return 3;
      case AppScreen.profile:
      case AppScreen.creatorStudio:
      case AppScreen.adminPanel:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Gate 1: If user is not authenticated, show AuthScreen first
    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }

    final drama = Provider.of<DramaProvider>(context);
    final currentScreen = drama.currentScreen;

    final isPlayerActive = currentScreen == AppScreen.player;
    final showTopBar = currentScreen == AppScreen.home;
    final showBottomNav = !isPlayerActive && currentScreen != AppScreen.search;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (drama.isCommentsSheetOpen) {
          drama.setCommentsSheetOpen(false);
        } else if (drama.isEpisodesDrawerOpen) {
          drama.setEpisodesDrawerOpen(false);
        } else if (drama.isAutoPayDialogVisible) {
          drama.closeAutoPayDialog();
        } else if (drama.isPoliciesDialogVisible) {
          drama.closePoliciesDialog();
        } else {
          WebVideoInterop.pauseAllWebVideos();
          final handled = drama.navigateBack();
          if (!handled) {
            SystemNavigator.pop();
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.dramaBlack,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                if (showTopBar)
                  StoryTopBar(
                    onSearchClick: () => drama.navigateTo(AppScreen.search),
                    onRenewPlanClick: () => drama.openAutoPayDialog(),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      // Base Tab Views (Always in memory with state & banner images preserved)
                      IndexedStack(
                        index: _getTabIndex(currentScreen),
                        children: const [
                          HomeScreen(),
                          PopularScreen(),
                          ExploreScreen(),
                          LibraryScreen(),
                          ProfileScreen(),
                        ],
                      ),

                      // Search Overlay
                      if (currentScreen == AppScreen.search)
                        const Positioned.fill(child: SearchScreen()),

                      // Detail Screen Overlay
                      if (currentScreen == AppScreen.detail)
                        const Positioned.fill(child: DramaDetailScreen()),

                      // Fullscreen Vertical Player Overlay
                      if (isPlayerActive)
                        const Positioned.fill(child: VerticalPlayerScreen()),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: showBottomNav
                ? StoryBottomNav(
                    currentScreen: currentScreen,
                    onNavigate: (screen) => drama.navigateTo(screen),
                  )
                : null,
          ),

          // First entry terms acceptance modal
          if (!auth.hasAcceptedTerms)
            PoliciesDialog(
              isFirstEntry: true,
              onAccept: () => auth.acceptTerms(),
            )
          else if (drama.isPoliciesDialogVisible)
            PoliciesDialog(
              isFirstEntry: false,
              onAccept: () => drama.closePoliciesDialog(),
              onDismiss: () => drama.closePoliciesDialog(),
            ),

          // Global AutoPay VIP subscription modal
          if (drama.isAutoPayDialogVisible)
            const PaymentAutopayDialog(),

          // Global PhonePe verification modal
          if (drama.isPaymentVerificationDialogVisible)
            PaymentVerificationDialog(
              onCancel: () => drama.closePaymentVerificationDialog(),
            ),
        ],
      ),
    );
  }
}
