import 'dart:async';
import 'dart:convert';

import '../storage/token_storage.dart';
import 'realtime_event_envelope.dart';

/// Connection lifecycle states for the Flutter WebSocket/STOMP realtime layer.
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Pluggable STOMP transport adapter contract to decouple STOMP protocol framing
/// from application logic and allow deterministic testing.
abstract class StompTransportAdapter {
  Future<void> connect({
    required String url,
    required Map<String, String> connectHeaders,
    required void Function(String destination, String body) onFrameReceived,
    required void Function(Object error) onTransportError,
  });

  Future<void> subscribe(String destination);
  Future<void> unsubscribe(String destination);
  Future<void> send(String destination, String body, {Map<String, String>? headers});
  Future<void> disconnect();
}

/// In-memory simulated STOMP transport adapter for local development and testing.
class SimulatedStompTransportAdapter implements StompTransportAdapter {
  void Function(String destination, String body)? _onFrameReceived;
  final Set<String> _subscriptions = <String>{};
  final List<Map<String, String>> sentFrames = <Map<String, String>>[];
  Map<String, String> lastConnectHeaders = const {};
  bool isConnected = false;

  @override
  Future<void> connect({
    required String url,
    required Map<String, String> connectHeaders,
    required void Function(String destination, String body) onFrameReceived,
    required void Function(Object error) onTransportError,
  }) async {
    lastConnectHeaders = Map<String, String>.unmodifiable(connectHeaders);
    _onFrameReceived = onFrameReceived;
    isConnected = true;
  }

  @override
  Future<void> subscribe(String destination) async {
    _subscriptions.add(destination);
  }

  @override
  Future<void> unsubscribe(String destination) async {
    _subscriptions.remove(destination);
  }

  @override
  Future<void> send(
    String destination,
    String body, {
    Map<String, String>? headers,
  }) async {
    sentFrames.add({
      'destination': destination,
      'body': body,
    });
  }

  @override
  Future<void> disconnect() async {
    isConnected = false;
    _subscriptions.clear();
  }

  Set<String> get activeSubscriptions => Set<String>.unmodifiable(_subscriptions);

  /// Simulates an incoming STOMP MESSAGE frame from the backend broker.
  void simulateServerMessage(String destination, String rawJsonBody) {
    if (isConnected && _subscriptions.contains(destination)) {
      _onFrameReceived?.call(destination, rawJsonBody);
    }
  }
}

/// Reusable Flutter STOMP/WebSocket Communication Service (Phase 1C Foundation).
///
/// Integrates with [TokenStorage] for authenticated STOMP connections, manages
/// subscriptions, deserializes [RealtimeEventEnvelope] payloads safely, and
/// provides connection/reconnection state management.
class StompRealtimeClient {
  final String wsUrl;
  final TokenStorage tokenStorage;
  final StompTransportAdapter _transport;
  final Duration reconnectDelay;

  final StreamController<RealtimeConnectionState> _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();
  final StreamController<RealtimeEventEnvelope<Map<String, dynamic>>> _eventController =
      StreamController<RealtimeEventEnvelope<Map<String, dynamic>>>.broadcast();

  final Map<String, StreamController<RealtimeEventEnvelope<Map<String, dynamic>>>>
      _topicControllers = {};

  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;

  StompRealtimeClient({
    required this.wsUrl,
    required this.tokenStorage,
    StompTransportAdapter? transport,
    this.reconnectDelay = const Duration(seconds: 3),
  }) : _transport = transport ?? SimulatedStompTransportAdapter();

  RealtimeConnectionState get connectionState => _state;
  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<RealtimeEventEnvelope<Map<String, dynamic>>> get eventStream =>
      _eventController.stream;

  bool get isConnected => _state == RealtimeConnectionState.connected;

  void _setState(RealtimeConnectionState nextState) {
    _state = nextState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(nextState);
    }
  }

  /// Establishes an authenticated STOMP over WebSocket connection using the stored JWT.
  Future<bool> connect() async {
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _setState(RealtimeConnectionState.connecting);

    final accessToken = await tokenStorage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      _setState(RealtimeConnectionState.error);
      return false;
    }

    try {
      await _transport.connect(
        url: wsUrl,
        connectHeaders: {
          'Authorization': 'Bearer $accessToken',
          'accept-version': '1.2',
        },
        onFrameReceived: _handleIncomingFrame,
        onTransportError: (_) => _handleUnexpectedDisconnect(),
      );

      _setState(RealtimeConnectionState.connected);

      // Re-subscribe any existing topic controllers upon reconnect
      for (final destination in _topicControllers.keys) {
        await _transport.subscribe(destination);
      }

      return true;
    } catch (_) {
      _setState(RealtimeConnectionState.error);
      return false;
    }
  }

  /// Subscribes to a STOMP destination (e.g., `/topic/user/{userId}/events`)
  /// and returns a stream of safely deserialized [RealtimeEventEnvelope] objects.
  Future<Stream<RealtimeEventEnvelope<Map<String, dynamic>>>> subscribe(
    String destination,
  ) async {
    final controller = _topicControllers.putIfAbsent(
      destination,
      () => StreamController<RealtimeEventEnvelope<Map<String, dynamic>>>.broadcast(),
    );

    if (isConnected) {
      await _transport.subscribe(destination);
    }

    return controller.stream;
  }

  /// Unsubscribes from a STOMP destination.
  Future<void> unsubscribe(String destination) async {
    if (isConnected) {
      await _transport.unsubscribe(destination);
    }
    final controller = _topicControllers.remove(destination);
    await controller?.close();
  }

  /// Publishes a JSON payload to a STOMP application destination (e.g., `/app/telemetry.simulate`).
  Future<void> send(String destination, Map<String, dynamic> payload) async {
    if (!isConnected) {
      throw StateError('Cannot send STOMP frame while disconnected');
    }
    await _transport.send(destination, jsonEncode(payload));
  }

  /// Cleanly disconnects from the STOMP broker and cancels pending reconnect timers.
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _transport.disconnect();
    _setState(RealtimeConnectionState.disconnected);
  }

  /// Triggers the reconnect flow if the connection drops unexpectedly.
  void simulateConnectionDrop() {
    _handleUnexpectedDisconnect();
  }

  void _handleUnexpectedDisconnect() {
    if (_manualDisconnect) {
      return;
    }
    _setState(RealtimeConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      if (!_manualDisconnect) {
        connect();
      }
    });
  }

  void _handleIncomingFrame(String destination, String rawBody) {
    final envelope = RealtimeEventEnvelope.tryParseRawJson(rawBody);
    if (envelope == null) {
      // Safely ignore malformed or non-envelope frames without crashing the client
      return;
    }

    if (!_eventController.isClosed) {
      _eventController.add(envelope);
    }

    final topicController = _topicControllers[destination];
    if (topicController != null && !topicController.isClosed) {
      topicController.add(envelope);
    }
  }

  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    for (final controller in _topicControllers.values) {
      controller.close();
    }
    _topicControllers.clear();
    _connectionStateController.close();
    _eventController.close();
  }
}
