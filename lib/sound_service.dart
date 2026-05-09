import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Generates and plays simple synthesised tones for in-app feedback.
/// No asset files required — tones are built at runtime.
class SoundService {
  static bool _enabled = true;

  static bool get enabled => _enabled;
  static set enabled(bool v) => _enabled = v;

  // Pre-cached WAV bytes (generated once, reused every call).
  static Uint8List? _sentBytes;
  static Uint8List? _receivedBytes;
  static Uint8List? _notifBytes;

  static void init() {
    // Pre-generate all tones once on startup so first play is instant.
    _sentBytes     = _makeTone(frequency: 1100, durationMs: 90,  decayRate: 25);
    _receivedBytes = _makeTone(frequency: 780,  durationMs: 220, decayRate: 8);
    _notifBytes    = _makeTone(frequency: 660,  durationMs: 280, decayRate: 6);
  }

  /// Soft "whoosh" when the user sends a message.
  static Future<void> playMessageSent() =>
      _play(_sentBytes ??= _makeTone(frequency: 1100, durationMs: 90, decayRate: 25));

  /// Gentle ding when a message from another user arrives.
  static Future<void> playMessageReceived() =>
      _play(_receivedBytes ??= _makeTone(frequency: 780, durationMs: 220, decayRate: 8));

  /// Soft bell for a new in-app notification.
  static Future<void> playNotification() =>
      _play(_notifBytes ??= _makeTone(frequency: 660, durationMs: 280, decayRate: 6));

  // ---------------------------------------------------------------------------

  static Future<void> _play(Uint8List wav) async {
    if (!_enabled) return;
    final player = AudioPlayer();
    try {
      if (kIsWeb) {
        // Web needs a data-URL because BytesSource is not supported there.
        final b64 = base64Encode(wav);
        await player.play(UrlSource('data:audio/wav;base64,$b64'));
      } else {
        await player.play(BytesSource(wav));
      }
    } catch (_) {
      // Never crash the app for a sound failure.
    } finally {
      // Dispose after playback completes (≈ tone duration + small buffer).
      Future.delayed(const Duration(milliseconds: 800), player.dispose);
    }
  }

  /// Builds a mono 16-bit PCM WAV file for a sine wave with exponential decay.
  ///
  /// [frequency]  – pitch in Hz
  /// [durationMs] – length of the tone in milliseconds
  /// [decayRate]  – higher = faster fade-out (try 5–30)
  static Uint8List _makeTone({
    required double frequency,
    required int durationMs,
    required double decayRate,
    double amplitude = 0.38,
  }) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();

    // PCM samples
    final pcm = ByteData(numSamples * 2); // 16-bit = 2 bytes/sample
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = math.exp(-decayRate * t);
      final value = (amplitude * 32767 * envelope * math.sin(2 * math.pi * frequency * t))
          .round()
          .clamp(-32767, 32767);
      pcm.setInt16(i * 2, value, Endian.little);
    }
    final pcmBytes = pcm.buffer.asUint8List();

    // WAV container (44-byte header + PCM data)
    final hdr = ByteData(44);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        hdr.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    str(0,  'RIFF');
    hdr.setUint32(4,  36 + pcmBytes.length, Endian.little); // file size - 8
    str(8,  'WAVE');
    str(12, 'fmt ');
    hdr.setUint32(16, 16, Endian.little);           // fmt chunk size
    hdr.setUint16(20, 1,  Endian.little);           // PCM = 1
    hdr.setUint16(22, 1,  Endian.little);           // mono
    hdr.setUint32(24, sampleRate, Endian.little);
    hdr.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    hdr.setUint16(32, 2,  Endian.little);           // block align
    hdr.setUint16(34, 16, Endian.little);           // bits/sample
    str(36, 'data');
    hdr.setUint32(40, pcmBytes.length, Endian.little);

    final out = Uint8List(44 + pcmBytes.length);
    out.setAll(0,  hdr.buffer.asUint8List());
    out.setAll(44, pcmBytes);
    return out;
  }
}
