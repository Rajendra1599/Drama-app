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

      // Periodically ensure shadow root also receives the pass-through style
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
}
