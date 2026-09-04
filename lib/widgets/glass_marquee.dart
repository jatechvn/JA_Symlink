part of 'glass_widgets.dart';

class AsymmetricMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseStart;
  final Duration pauseEnd;
  final Duration returnDuration;
  final int speedPerCharMs;

  const AsymmetricMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseStart = const Duration(milliseconds: 1500),
    this.pauseEnd = const Duration(milliseconds: 1500),
    this.returnDuration = const Duration(milliseconds: 800),
    this.speedPerCharMs = 60,
  });

  @override
  State<AsymmetricMarqueeText> createState() => _AsymmetricMarqueeTextState();
}

class _AsymmetricMarqueeTextState extends State<AsymmetricMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _isDisposed = false;
  int _cycleId = 0;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void didUpdateWidget(covariant AsymmetricMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _cycleId++;
      _delayTimer?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
    }
  }

  Future<bool> _cancellableDelay(Duration duration, int currentCycle) {
    final completer = Completer<bool>();
    _delayTimer?.cancel();
    _delayTimer = Timer(duration, () {
      if (!_isDisposed && mounted && currentCycle == _cycleId) {
        completer.complete(true);
      } else {
        completer.complete(false);
      }
    });
    return completer.future;
  }

  Future<void> _startScrolling() async {
    if (_isDisposed || !mounted || !_scrollController.hasClients) return;
    final currentCycle = _cycleId;

    final canStart = await _cancellableDelay(widget.pauseStart, currentCycle);
    if (!canStart ||
        _isDisposed ||
        !mounted ||
        currentCycle != _cycleId ||
        !_scrollController.hasClients) {
      return;
    }

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) return; // Zero CPU when text fits

    while (!_isDisposed && mounted && currentCycle == _cycleId) {
      final duration = Duration(
        milliseconds: math.max(600, widget.text.length * widget.speedPerCharMs),
      );
      if (!_scrollController.hasClients) return;
      await _scrollController.animateTo(
        maxScrollExtent,
        duration: duration,
        curve: Curves.linear,
      );
      if (_isDisposed || !mounted || currentCycle != _cycleId) return;

      final canProceedEnd = await _cancellableDelay(
        widget.pauseEnd,
        currentCycle,
      );
      if (!canProceedEnd ||
          _isDisposed ||
          !mounted ||
          currentCycle != _cycleId ||
          !_scrollController.hasClients) {
        return;
      }

      await _scrollController.animateTo(
        0,
        duration: widget.returnDuration,
        curve: Curves.easeOut,
      );
      if (_isDisposed || !mounted || currentCycle != _cycleId) return;

      final canProceedStart = await _cancellableDelay(
        widget.pauseStart,
        currentCycle,
      );
      if (!canProceedStart ||
          _isDisposed ||
          !mounted ||
          currentCycle != _cycleId ||
          !_scrollController.hasClients) {
        return;
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cycleId++;
    _delayTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

typedef MarqueeText = AsymmetricMarqueeText;
typedef BounceMarqueeText = AsymmetricMarqueeText;
