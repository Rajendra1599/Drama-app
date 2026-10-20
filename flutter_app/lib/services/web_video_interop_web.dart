// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class WebVideoInterop {
  static bool _installed = false;

  /// Injects browser-level style rules so HTML5 video elements pass clicks
  /// through to Flutter's native gesture layer smoothly without event conflicts.
  static void setupVideoClickHandlers({VoidCallback? onToggle}) {
    if (!kIsWeb) return;
    if (_installed) return;
    _installed = true;

    try {
      final style = html.StyleElement();
      style.id = 'storyup-video-styles';
      style.text = '''
        flt-platform-view, flt-platform-view-slot, video {
          pointer-events: none !important;
          user-select: none !important;
          -webkit-user-select: none !important;
        }
      ''';
      html.document.head?.append(style);

      void injectShadowStyle() {
        final gp = html.document.querySelector('flt-glass-pane');
        if (gp != null && gp.shadowRoot != null) {
          if (gp.shadowRoot!.querySelector('#storyup-video-shadow-styles') == null) {
            final shadowStyle = html.StyleElement();
            shadowStyle.id = 'storyup-video-shadow-styles';
            shadowStyle.text = '''
              flt-platform-view, flt-platform-view-slot, video {
                pointer-events: none !important;
                user-select: none !important;
              }
            ''';
            gp.shadowRoot!.append(shadowStyle);
          }
        }
      }

      injectShadowStyle();
      Timer.periodic(const Duration(seconds: 1), (_) => injectShadowStyle());
    } catch (_) {}
  }

  /// Configures HTML5 video elements for fast auto-buffering & zero startup latency
  static void optimizeWebVideos() {
    if (!kIsWeb) return;
    try {
      void configure(dynamic root) {
        if (root == null) return;
        if (root is html.VideoElement) {
          root.preload = 'auto';
          root.setAttribute('playsinline', 'true');
          root.setAttribute('webkit-playsinline', 'true');
        }
        if (root is html.Element && root.shadowRoot != null) {
          configure(root.shadowRoot);
        }
        final children = root.childNodes;
        if (children != null) {
          for (int i = 0; i < children.length; i++) {
            configure(children[i]);
          }
        }
      }
      configure(html.document.body);
    } catch (_) {}
  }

  static final Set<String> _preloadedUrls = {};

  /// Preloads upcoming episode video chunks in browser HTTP cache for instant playback
  static void preloadVideo(String rawUrl) {
    if (!kIsWeb) return;
    final url = rawUrl.trim();
    if (url.isEmpty || _preloadedUrls.contains(url)) return;
    _preloadedUrls.add(url);
    try {
      final link = html.LinkElement()
        ..rel = 'prefetch'
        ..as = 'video'
        ..href = url;
      html.document.head?.append(link);
    } catch (_) {}
  }

  /// Deeply inspects and pauses/mutes playback on all HTML5 video and audio
  /// elements across light DOM and nested Shadow DOMs.
  /// Crucially preserves the src attribute so Flutter's cached PageView neighbor
  /// textures remain intact and playable when swiped back to.
  static void _deepMuteAndHalt(dynamic node) {
    if (node == null) return;
    try {
      if (node is html.VideoElement) {
        node.pause();
        node.volume = 0.0;
        node.muted = true;
      } else if (node is html.AudioElement) {
        node.pause();
        node.volume = 0.0;
        node.muted = true;
      }

      if (node is html.Element) {
        if (node.shadowRoot != null) {
          _deepMuteAndHalt(node.shadowRoot);
        }
      }

      final children = node.childNodes;
      if (children != null) {
        for (int i = 0; i < children.length; i++) {
          _deepMuteAndHalt(children[i]);
        }
      }
    } catch (_) {}
  }

  /// Pauses and mutes HTML5 video elements when navigating away from the player screen.
  static void pauseAllWebVideos() {
    if (!kIsWeb) return;
    try {
      _deepMuteAndHalt(html.document.body);
      _deepMuteAndHalt(html.document.documentElement);

      // Sweep flt-glass-pane explicitly
      final gp = html.document.querySelector('flt-glass-pane');
      if (gp != null) {
        _deepMuteAndHalt(gp);
        if (gp.shadowRoot != null) {
          _deepMuteAndHalt(gp.shadowRoot);
        }
      }

      // Query selector fallbacks
      final directVideos = html.document.querySelectorAll('video');
      for (final v in directVideos) {
        if (v is html.VideoElement) {
          v.pause();
          v.volume = 0.0;
          v.muted = true;
        }
      }
    } catch (_) {}
  }
}
