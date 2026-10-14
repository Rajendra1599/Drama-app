import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../models/drama_series.dart';
import '../models/episode.dart';
import '../models/user_subscription.dart';
import '../models/payment_transaction.dart';
import '../models/watch_history.dart';
import '../models/drama_review.dart';
import '../models/episode_comment.dart';
import '../models/content_report.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import '../services/local_storage_service.dart';

class DramaProvider extends ChangeNotifier {
  // Navigation
  AppScreen _currentScreen = AppScreen.home;
  final List<AppScreen> _screenStack = [AppScreen.home];

  AppScreen get currentScreen => _currentScreen;

  // Selections
  String? _selectedSeriesId;
  String? _selectedEpisodeId;
  int _activeEpisodeNumber = 1;

  String? get selectedSeriesId => _selectedSeriesId;
  String? get selectedEpisodeId => _selectedEpisodeId;
  int get activeEpisodeNumber => _activeEpisodeNumber;

  // Catalog & Feeds
  List<DramaSeries> _allSeries = [];
  DramaSeries? _featuredSeries;
  List<DramaSeries> _trendingDramas = [];
  List<DramaSeries> _popularDramas = [];
  List<DramaSeries> _newReleases = [];
  final Map<String, List<Episode>> _seriesEpisodes = {};

  List<DramaSeries> get allSeries => _allSeries;
  DramaSeries? get featuredSeries => _featuredSeries;
  List<DramaSeries> get trendingDramas => _trendingDramas;
  List<DramaSeries> get popularDramas => _popularDramas;
  List<DramaSeries> get newReleases => _newReleases;

  DramaSeries? get selectedSeries {
    if (_selectedSeriesId == null) return null;
    try {
      return _allSeries.firstWhere((s) => s.id == _selectedSeriesId);
    } catch (e) {
      return _allSeries.isNotEmpty ? _allSeries.first : null;
    }
  }

  List<Episode> get currentEpisodes {
    if (_selectedSeriesId == null) return [];
    return _seriesEpisodes[_selectedSeriesId] ?? [];
  }

  List<Episode> getEpisodesForSeries(String seriesId) {
    return _seriesEpisodes[seriesId] ?? [];
  }

  Episode? get currentEpisode {
    final list = currentEpisodes;
    if (list.isEmpty) return null;
    try {
      return list.firstWhere((e) => e.episodeNumber == _activeEpisodeNumber);
    } catch (e) {
      return list.first;
    }
  }

  // Search
  String _searchQuery = '';
  List<DramaSeries> _searchResults = [];
  List<String> _searchHistory = [
    'Drama',
    'Romance',
    'Thriller',
    'Revenge',
    'Action'
  ];
  Timer? _searchDebounceTimer;

  String get searchQuery => _searchQuery;
  List<DramaSeries> get searchResults => _searchResults;
  List<String> get searchHistory => _searchHistory;

  // Watchlist & History
  List<String> _watchlistIds = [];
  List<WatchHistory> _watchHistory = [];

  List<String> get watchlistIds => _watchlistIds;
  List<WatchHistory> get watchHistory => _watchHistory;

  // VIP Subscription & Transactions
  UserSubscription? _userSubscription;
  final List<PaymentTransaction> _transactions = [];
  SubscriptionPlan _selectedAutoPayPlan = PaymentService.trialPlan;
  UpiAppTarget _selectedUpiTarget = UpiAppTarget.phonePe;

  UserSubscription? get userSubscription => _userSubscription;
  List<PaymentTransaction> get transactions => _transactions;
  SubscriptionPlan get selectedAutoPayPlan => _selectedAutoPayPlan;
  UpiAppTarget get selectedUpiTarget => _selectedUpiTarget;

  bool get isVipActive {
    if (_userSubscription == null) return false;
    return _userSubscription!.isVipActive;
  }

  /// Whether an episode is blocked by payment paywall
  bool isEpisodePaywallLocked(int episodeNumber) {
    if (isVipActive) return false;
    return episodeNumber > 5;
  }

  // Dialog & Sheet states
  bool _isAutoPayDialogVisible = false;
  bool _isPaymentVerificationDialogVisible = false;
  bool _isPoliciesDialogVisible = false;
  bool _isCommentsSheetOpen = false;
  bool _isEpisodesDrawerOpen = false;

  String? _activePaymentTransactionId;
  bool _isPaymentVerifying = false;
  String? _paymentErrorMessage;

  bool get isAutoPayDialogVisible => _isAutoPayDialogVisible;
  bool get isPaymentVerificationDialogVisible =>
      _isPaymentVerificationDialogVisible;
  bool get isPoliciesDialogVisible => _isPoliciesDialogVisible;
  bool get isCommentsSheetOpen => _isCommentsSheetOpen;
  bool get isEpisodesDrawerOpen => _isEpisodesDrawerOpen;

  String? get activePaymentTransactionId => _activePaymentTransactionId;
  bool get isPaymentVerifying => _isPaymentVerifying;
  String? get paymentErrorMessage => _paymentErrorMessage;

  // Player controls
  bool _isPlaying = true;
  double _playbackSpeed = 1.0;
  bool _isControlsLocked = false;

  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  bool get isControlsLocked => _isControlsLocked;

  // Comments, Reviews & Reports
  final Map<String, List<EpisodeComment>> _comments = {};
  final Map<String, List<DramaReview>> _reviews = {};
  List<ContentReport> _pendingReports = [];
  final CreatorStats _creatorStats = CreatorStats();

  List<ContentReport> get pendingReports => _pendingReports;
  CreatorStats get creatorStats => _creatorStats;

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  DramaProvider() {
    _initCatalog();
    _loadLocalUserData();
  }

  Future<void> _initCatalog() async {
    _allSeries = await ApiService.fetchCatalog();
    if (_allSeries.isNotEmpty) {
      _featuredSeries = _allSeries.firstWhere((s) => s.isFeatured,
          orElse: () => _allSeries.first);
      _trendingDramas = List.from(_allSeries)
        ..sort((a, b) => b.totalViews.compareTo(a.totalViews));
      _popularDramas = List.from(_allSeries)
        ..sort((a, b) => b.totalViews.compareTo(a.totalViews));
      _newReleases = List.from(_allSeries)
        ..sort((a, b) => b.releaseDateEpoch.compareTo(a.releaseDateEpoch));
      _selectedSeriesId = _featuredSeries?.id ?? _allSeries.first.id;

      // Fetch real uploaded episodes for all published series
      for (final s in _allSeries) {
        loadEpisodesForSeries(s.id);
      }
    } else {
      _selectedSeriesId = null;
      _featuredSeries = null;
      _trendingDramas = [];
      _popularDramas = [];
      _newReleases = [];
    }
    notifyListeners();
  }

  Future<void> loadEpisodesForSeries(String seriesId) async {
    final list = await ApiService.fetchEpisodesForSeries(seriesId);
    if (list.isNotEmpty) {
      _seriesEpisodes[seriesId] = list;
    } else if (!_seriesEpisodes.containsKey(seriesId) || _seriesEpisodes[seriesId]!.isEmpty) {
      _seriesEpisodes[seriesId] = ApiService.getEpisodesForSeries(seriesId, 10);
    }
    notifyListeners();
  }

  Future<void> refreshCatalog() async {
    await _initCatalog();
  }

  Future<void> syncSubscription() async {
    final sub = await ApiService.fetchSubscription('user_demo_101');
    if (sub != null) {
      _userSubscription = sub;
      notifyListeners();
    }
  }

  void _loadLocalUserData() {
    _watchlistIds = LocalStorageService.getWatchlist();
    _watchHistory = LocalStorageService.getWatchHistory();

    _pendingReports = [];
    syncSubscription();
    notifyListeners();
  }


  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void navigateTo(AppScreen screen) {
    if (_currentScreen == screen) return;
    _currentScreen = screen;
    _screenStack.add(screen);
    notifyListeners();
  }

  bool navigateBack() {
    if (_screenStack.length > 1) {
      _screenStack.removeLast();
      _currentScreen = _screenStack.last;
      notifyListeners();
      return true;
    }
    return false;
  }

  void openDramaDetail(String seriesId) {
    startOrResumeSeries(seriesId, episodeNumber: 1);
  }

  void startOrResumeSeries(String seriesId, {int episodeNumber = 1}) {
    _selectedSeriesId = seriesId;
    _activeEpisodeNumber = episodeNumber;
    _selectedEpisodeId = 'ep_${seriesId}_$episodeNumber';
    _isPlaying = true;
    if (!_seriesEpisodes.containsKey(seriesId) || _seriesEpisodes[seriesId]!.isEmpty) {
      _seriesEpisodes[seriesId] = ApiService.getEpisodesForSeries(seriesId, 10);
    }
    loadEpisodesForSeries(seriesId);
    navigateTo(AppScreen.player);
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void setSearchQuery(String query) {
    _searchQuery = query;
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      _searchResults = await ApiService.searchCatalog(query);
      if (query.trim().isNotEmpty && !_searchHistory.contains(query.trim())) {
        _searchHistory.insert(0, query.trim());
        if (_searchHistory.length > 8) _searchHistory.removeLast();
      }
      notifyListeners();
    });

    notifyListeners();
  }

  void clearSearchHistory() {
    _searchHistory = [];
    notifyListeners();
  }

  // ===========================================================================
  // WATCHLIST & WATCH HISTORY
  // ===========================================================================

  bool isInWatchlist(String seriesId) => _watchlistIds.contains(seriesId);

  void toggleWatchlist(String seriesId) {
    if (_watchlistIds.contains(seriesId)) {
      _watchlistIds.remove(seriesId);
    } else {
      _watchlistIds.add(seriesId);
    }
    LocalStorageService.setWatchlist(_watchlistIds);
    notifyListeners();
  }

  void recordWatchProgress({
    required String seriesId,
    required String episodeId,
    required int progressSeconds,
    required int totalSeconds,
  }) {
    final existingIdx = _watchHistory
        .indexWhere((h) => h.seriesId == seriesId && h.episodeId == episodeId);
    final isCompleted = progressSeconds >= (totalSeconds * 0.9);

    final item = WatchHistory(
      id: '${seriesId}_$episodeId',
      userId: 'user_demo_101',
      seriesId: seriesId,
      episodeId: episodeId,
      progressSeconds: progressSeconds,
      totalSeconds: totalSeconds,
      isCompleted: isCompleted,
      lastWatchedAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (existingIdx >= 0) {
      _watchHistory[existingIdx] = item;
    } else {
      _watchHistory.insert(0, item);
    }

    LocalStorageService.saveWatchHistory(_watchHistory);
    notifyListeners();
  }

  void clearWatchHistory() {
    _watchHistory = [];
    LocalStorageService.saveWatchHistory([]);
    notifyListeners();
  }

  // ===========================================================================
  // VIP MEMBERSHIP & PHONEPE PAYMENTS
  // ===========================================================================

  void openAutoPayDialog({SubscriptionPlan? plan}) {
    if (plan != null) _selectedAutoPayPlan = plan;
    _isAutoPayDialogVisible = true;
    notifyListeners();
  }

  void closeAutoPayDialog() {
    _isAutoPayDialogVisible = false;
    notifyListeners();
  }

  void setSelectedUpiTarget(UpiAppTarget target) {
    _selectedUpiTarget = target;
    notifyListeners();
  }

  Future<void> initiatePhonePePayment({UpiAppTarget? target}) async {
    closeAutoPayDialog();
    _paymentErrorMessage = null;
    _isPaymentVerifying = false;

    final result = await PaymentService.launchUpiAutoPay(
      userId: 'user_demo_101',
      plan: _selectedAutoPayPlan,
      target: target ?? _selectedUpiTarget,
    );

    // If modal already verified and completed payment automatically
    if (result['verified'] == true && result['subscription'] != null) {
      final sub = result['subscription'] as UserSubscription;
      _userSubscription = sub;
      _transactions.insert(
        0,
        PaymentTransaction(
          id: result['transactionId']?.toString() ?? 'MD_RZP_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'user_demo_101',
          planName: _selectedAutoPayPlan.name,
          amount: _selectedAutoPayPlan.initialPriceInr,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _isPaymentVerificationDialogVisible = false;
      _isPaymentVerifying = false;
      _activePaymentTransactionId = null;
      notifyListeners();
      return;
    }

    _activePaymentTransactionId = result['transactionId']?.toString();
    _isPaymentVerificationDialogVisible = true;
    notifyListeners();
  }


  Future<bool> verifyAndCompletePayment({String? utrNumber}) async {
    if (_activePaymentTransactionId == null) return false;
    _isPaymentVerifying = true;
    _paymentErrorMessage = null;
    notifyListeners();

    try {
      final sub = await PaymentService.completeVerification(
        transactionId: _activePaymentTransactionId!,
        userId: 'user_demo_101',
        bankRefId: utrNumber,
      );

      if (sub != null && sub.isVipActive) {
        _userSubscription = sub;
        _transactions.insert(
          0,
          PaymentTransaction(
            id: _activePaymentTransactionId!,
            userId: 'user_demo_101',
            planName: _selectedAutoPayPlan.name,
            amount: _selectedAutoPayPlan.initialPriceInr,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        _isPaymentVerificationDialogVisible = false;
        _isPaymentVerifying = false;
        _activePaymentTransactionId = null;
        notifyListeners();
        return true;
      } else {
        _paymentErrorMessage = 'Payment was not confirmed. Please ensure ₹1 payment was completed in your UPI app.';
      }
    } catch (e) {
      _paymentErrorMessage = 'Verification error. Please retry or cancel.';
    }

    _isPaymentVerifying = false;
    notifyListeners();
    return false;
  }

  Future<void> cancelPhonePePayment() async {
    if (_activePaymentTransactionId != null) {
      final txnId = _activePaymentTransactionId!;
      _activePaymentTransactionId = null;
      await ApiService.cancelPayment(txnId);
    }
    _isPaymentVerifying = false;
    _paymentErrorMessage = null;
    _isPaymentVerificationDialogVisible = false;
    notifyListeners();
  }

  void closePaymentVerificationDialog() {
    cancelPhonePePayment();
  }

  Future<void> cancelVipSubscription() async {
    await ApiService.cancelSubscription('user_demo_101');
    _userSubscription = UserSubscription(
      userId: 'user_demo_101',
      planId: 'free_tier',
      planName: 'Free Membership Tier',
      status: 'CANCELLED',
      validUntilEpoch: 0,
      activatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }


  Future<void> activate24HourTrial() async {
    final sub = await ApiService.activateTrial('user_demo_101');
    if (sub != null) {
      _userSubscription = sub;
      notifyListeners();
    }
  }

  // ===========================================================================
  // PLAYER CONTROLS
  // ===========================================================================

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    notifyListeners();
  }

  void toggleControlsLock() {
    _isControlsLocked = !_isControlsLocked;
    notifyListeners();
  }

  // Like System
  final Set<String> _likedEpisodeIds = {};
  final Set<String> _likedSeriesIds = {};

  bool isEpisodeLiked(String episodeId) => _likedEpisodeIds.contains(episodeId);
  bool isSeriesLiked(String seriesId) => _likedSeriesIds.contains(seriesId);

  Future<void> toggleLikeSeries(String seriesId) async {
    final alreadyLiked = _likedSeriesIds.contains(seriesId);
    if (alreadyLiked) {
      _likedSeriesIds.remove(seriesId);
    } else {
      _likedSeriesIds.add(seriesId);
    }

    final idx = _allSeries.indexWhere((s) => s.id == seriesId);
    if (idx >= 0) {
      final s = _allSeries[idx];
      final newLikes =
          (s.totalLikes + (alreadyLiked ? -1 : 1)).clamp(0, 9999999);
      _allSeries[idx] = s.copyWith(totalLikes: newLikes);
    }
    notifyListeners();

    try {
      await ApiService.likeSeries(seriesId, delta: alreadyLiked ? -1 : 1);
    } catch (_) {}
  }

  Future<void> toggleLikeEpisode(String seriesId, String episodeId) async {
    final alreadyLiked = _likedEpisodeIds.contains(episodeId);
    if (alreadyLiked) {
      _likedEpisodeIds.remove(episodeId);
    } else {
      _likedEpisodeIds.add(episodeId);
    }

    final list = _seriesEpisodes[seriesId];
    if (list != null) {
      final idx = list.indexWhere((e) => e.id == episodeId);
      if (idx >= 0) {
        final ep = list[idx];
        final newLikes = (ep.likes + (alreadyLiked ? -1 : 1)).clamp(0, 9999999);
        list[idx] = Episode(
          id: ep.id,
          seriesId: ep.seriesId,
          seasonId: ep.seasonId,
          episodeNumber: ep.episodeNumber,
          title: ep.title,
          description: ep.description,
          videoUrl: ep.videoUrl,
          thumbnailUrl: ep.thumbnailUrl,
          durationSeconds: ep.durationSeconds,
          fileSizeMb: ep.fileSizeMb,
          resolution: ep.resolution,
          aspectRatio: ep.aspectRatio,
          status: ep.status,
          monetizationType: ep.monetizationType,
          views: ep.views,
          likes: newLikes,
          completionCount: ep.completionCount,
          releaseAt: ep.releaseAt,
          isVipLocked: ep.isVipLocked,
        );
      }
    }
    notifyListeners();

    try {
      await ApiService.likeEpisode(episodeId, delta: alreadyLiked ? -1 : 1);
    } catch (_) {}
  }

  void setCommentsSheetOpen(bool open) {
    _isCommentsSheetOpen = open;
    notifyListeners();
  }

  void setEpisodesDrawerOpen(bool open) {
    _isEpisodesDrawerOpen = open;
    notifyListeners();
  }

  void nextEpisode() {
    final episodes = currentEpisodes;
    if (_activeEpisodeNumber < episodes.length) {
      startOrResumeSeries(_selectedSeriesId!,
          episodeNumber: _activeEpisodeNumber + 1);
    }
  }

  void previousEpisode() {
    if (_activeEpisodeNumber > 1) {
      startOrResumeSeries(_selectedSeriesId!,
          episodeNumber: _activeEpisodeNumber - 1);
    }
  }

  // ===========================================================================
  // COMMENTS, REVIEWS & MODERATION
  // ===========================================================================

  List<EpisodeComment> getCommentsForEpisode(String episodeId) {
    return _comments[episodeId] ?? [];
  }

  void addComment(String episodeId, String text) {
    if (text.trim().isEmpty) return;
    final list = List<EpisodeComment>.from(getCommentsForEpisode(episodeId));
    list.insert(
      0,
      EpisodeComment(
        id: 'comm_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user_demo_101',
        userName: 'You',
        episodeId: episodeId,
        seriesId: _selectedSeriesId ?? '',
        text: text.trim(),
        likes: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _comments[episodeId] = list;
    notifyListeners();
  }

  void likeComment(String episodeId, String commentId) {
    final list = getCommentsForEpisode(episodeId);
    final c = list.firstWhere((item) => item.id == commentId,
        orElse: () => list.first);
    c.isLikedByUser = !c.isLikedByUser;
    c.likes += c.isLikedByUser ? 1 : -1;
    notifyListeners();
  }

  List<DramaReview> getReviewsForSeries(String seriesId) {
    return _reviews[seriesId] ?? [];
  }

  void addReview(String seriesId, int rating, String text) {
    final list = List<DramaReview>.from(getReviewsForSeries(seriesId));
    list.insert(
      0,
      DramaReview(
        id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user_demo_101',
        userName: 'You',
        seriesId: seriesId,
        rating: rating,
        reviewText: text.trim(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _reviews[seriesId] = list;
    notifyListeners();
  }

  void submitReport({
    required String contentType,
    required String contentId,
    required String contentTitle,
    required String reason,
    required String description,
  }) {
    _pendingReports.insert(
      0,
      ContentReport(
        id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
        reporterId: 'user_demo_101',
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
        reason: reason,
        description: description,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    notifyListeners();
  }

  void updateReportStatus(String reportId, String status) {
    final idx = _pendingReports.indexWhere((r) => r.id == reportId);
    if (idx >= 0) {
      _pendingReports[idx].status = status;
      notifyListeners();
    }
  }

  void addSeries(DramaSeries series) {
    _allSeries.insert(0, series);
    notifyListeners();
  }

  Future<bool> deleteSeries(String seriesId) async {
    _allSeries.removeWhere((s) => s.id == seriesId);
    _seriesEpisodes.remove(seriesId);
    notifyListeners();
    return await ApiService.deleteSeries(seriesId);
  }

  Future<bool> deleteEpisode(String seriesId, String episodeId) async {
    if (_seriesEpisodes.containsKey(seriesId)) {
      _seriesEpisodes[seriesId]!.removeWhere((e) => e.id == episodeId);
    }
    final seriesIdx = _allSeries.indexWhere((s) => s.id == seriesId);
    if (seriesIdx >= 0) {
      final current = _allSeries[seriesIdx];
      final newCount =
          (_seriesEpisodes[seriesId]?.length ?? (current.totalEpisodes - 1))
              .clamp(0, 9999);
      _allSeries[seriesIdx] = current.copyWith(totalEpisodes: newCount);
    }
    notifyListeners();
    return await ApiService.deleteEpisode(episodeId);
  }

  void openPoliciesDialog() {
    _isPoliciesDialogVisible = true;
    notifyListeners();
  }

  void closePoliciesDialog() {
    _isPoliciesDialogVisible = false;
    notifyListeners();
  }
}
