import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/models/phoenix/phoenix_models.dart';
import '../../../../core/services/phoenix/phoenix_market_service.dart';
import '../../../../core/services/phoenix/phoenix_websocket_service.dart';
import '../../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Timeframe options
// ---------------------------------------------------------------------------

const _timeframes = ['1m', '5m', '15m', '1h', '4h', '1D'];
const _tfToApi = {
  '1m': '1m',
  '5m': '5m',
  '15m': '15m',
  '1h': '1h',
  '4h': '4h',
  '1D': '1d',
};

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class CandleChartState {
  final List<PhoenixCandle> candles;
  final String timeframe;
  final bool isLoading;
  final String? error;

  const CandleChartState({
    this.candles = const [],
    this.timeframe = '15m',
    this.isLoading = false,
    this.error,
  });

  CandleChartState copyWith({
    List<PhoenixCandle>? candles,
    String? timeframe,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => CandleChartState(
    candles: candles ?? this.candles,
    timeframe: timeframe ?? this.timeframe,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class CandleChartNotifier extends Notifier<CandleChartState> {
  StreamSubscription<CandleMessage>? _candleSub;
  final String _symbol;

  CandleChartNotifier(this._symbol);

  @override
  CandleChartState build() {
    ref.onDispose(_dispose);
    Future.microtask(() => _load(_symbol, const CandleChartState().timeframe));
    return const CandleChartState(isLoading: true);
  }

  Future<void> _load(String symbol, String timeframe) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final svc = ref.read(phoenixMarketServiceProvider);
      final apiTf = _tfToApi[timeframe] ?? timeframe;
      final candles = await svc.fetchCandles(
        symbol: _toApiSymbol(symbol),
        timeframe: apiTf,
        limit: 120,
      );
      state = state.copyWith(candles: candles, isLoading: false);
      _subscribeCandleWs(symbol, timeframe);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load chart');
    }
  }

  void _subscribeCandleWs(String symbol, String timeframe) {
    _candleSub?.cancel();
    final ws = ref.read(phoenixWebSocketServiceProvider);
    ws.subscribeCandles(symbol, _tfToApi[timeframe] ?? timeframe);
    _candleSub = ws.candleStream
        .where(
          (m) =>
              m.symbol == symbol &&
              (m.timeframe == (_tfToApi[timeframe] ?? timeframe)),
        )
        .listen((m) {
          final current = List<PhoenixCandle>.from(state.candles);
          if (current.isNotEmpty && current.last.time == m.candle.time) {
            // Update the last (current) candle
            current[current.length - 1] = m.candle;
          } else {
            current.add(m.candle);
            if (current.length > 200) current.removeAt(0);
          }
          state = state.copyWith(candles: current);
        });
  }

  void selectTimeframe(String timeframe) {
    if (timeframe == state.timeframe) return;
    final ws = ref.read(phoenixWebSocketServiceProvider);
    ws.unsubscribeCandles(_symbol);
    state = state.copyWith(timeframe: timeframe, candles: []);
    _load(_symbol, timeframe);
  }

  void _dispose() {
    _candleSub?.cancel();
    final ws = ref.read(phoenixWebSocketServiceProvider);
    ws.unsubscribeCandles(_symbol);
  }

  String _toApiSymbol(String s) =>
      s.endsWith('-PERP') ? s.substring(0, s.length - 5) : s;
}

final candleChartProvider =
    NotifierProvider.family<CandleChartNotifier, CandleChartState, String>(
      (symbol) => CandleChartNotifier(symbol),
    );

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class PriceChartWidget extends ConsumerWidget {
  final String symbol;
  final double height;

  const PriceChartWidget({super.key, required this.symbol, this.height = 220});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(candleChartProvider(symbol));
    final notifier = ref.read(candleChartProvider(symbol).notifier);

    return Container(
      height: height.h,
      color: AppColors.backgroundDark,
      child: Column(
        children: [
          _TimeframeBar(
            selected: state.timeframe,
            onSelect: notifier.selectTimeframe,
          ),
          Expanded(
            child: Stack(
              children: [
                _TvChart(symbol: symbol),
                if (state.isLoading && state.candles.isEmpty)
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
                if (!state.isLoading &&
                    state.candles.isEmpty &&
                    state.error != null)
                  Center(
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeframe selector bar
// ---------------------------------------------------------------------------

class _TimeframeBar extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  const _TimeframeBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32.h,
      child: Row(
        children: _timeframes
            .map(
              (tf) => GestureDetector(
                onTap: () => onSelect(tf),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  alignment: Alignment.center,
                  child: Text(
                    tf,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: tf == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: tf == selected
                          ? AppColors.textPrimaryDark
                          : AppColors.textMutedDark,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TradingView Lightweight Charts WebView
// ---------------------------------------------------------------------------

class _TvChart extends ConsumerStatefulWidget {
  final String symbol;

  const _TvChart({required this.symbol});

  @override
  ConsumerState<_TvChart> createState() => _TvChartState();
}

class _TvChartState extends ConsumerState<_TvChart> {
  late final WebViewController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0B0F))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _isReady = true;
            final chartState = ref.read(candleChartProvider(widget.symbol));
            if (chartState.candles.isNotEmpty) {
              _initChart(chartState.candles);
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/html/chart.html');
  }

  void _initChart(List<PhoenixCandle> candles) {
    final data = candles
        .map(
          (c) => {
            'time': c.time,
            'open': c.open,
            'high': c.high,
            'low': c.low,
            'close': c.close,
            'volume': c.volume ?? 0.0,
          },
        )
        .toList();
    final b64 = base64Encode(utf8.encode(jsonEncode(data)));
    _controller.runJavaScript("initChart('$b64')");
  }

  void _updateLastCandle(PhoenixCandle c) {
    final data = {
      'time': c.time,
      'open': c.open,
      'high': c.high,
      'low': c.low,
      'close': c.close,
      'volume': c.volume ?? 0.0,
    };
    final b64 = base64Encode(utf8.encode(jsonEncode(data)));
    _controller.runJavaScript("updateCandle('$b64')");
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CandleChartState>(candleChartProvider(widget.symbol), (
      prev,
      next,
    ) {
      if (!_isReady) return;
      final prevCandles = prev?.candles ?? [];
      final candles = next.candles;
      if (candles.isEmpty) return;

      // Timeframe changed or initial load → full reinit
      if (next.timeframe != (prev?.timeframe ?? '') ||
          (prevCandles.isEmpty && candles.isNotEmpty)) {
        _initChart(candles);
        return;
      }

      // Candles list changed size significantly → full reinit
      if ((candles.length - prevCandles.length).abs() > 1) {
        _initChart(candles);
        return;
      }

      // Last candle updated (live tick)
      if (candles.isNotEmpty &&
          (prevCandles.isEmpty || candles.last != prevCandles.last)) {
        _updateLastCandle(candles.last);
      }
    });

    return WebViewWidget(controller: _controller);
  }
}
