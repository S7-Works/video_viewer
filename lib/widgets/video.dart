import 'dart:async';
import 'package:helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:video_viewer/utils/styles.dart';
import 'package:video_viewer/widgets/misc.dart';
import 'package:video_viewer/widgets/progress.dart';

class VideoReady extends StatefulWidget {
  VideoReady({
    Key key,
    this.controller,
    this.style,
    this.source,
    this.activedSource,
    this.looping,
    this.rewindAmount,
    this.forwardAmount,
    this.defaultAspectRatio,
    this.onChangeSource,
  }) : super(key: key);

  final String activedSource;
  final bool looping;
  final double defaultAspectRatio;
  final int rewindAmount, forwardAmount;
  final VideoViewerStyle style;
  final VideoPlayerController controller;
  final Map<String, VideoPlayerController> source;
  final void Function(VideoPlayerController, String) onChangeSource;

  @override
  VideoReadyState createState() => VideoReadyState();
}

class VideoReadyState extends State<VideoReady> {
  bool isPlaying = false,
      isBuffering = false,
      isFullScreen = false,
      _showButtons = false,
      _showSettings = false,
      _showThumbnail = true,
      _showForwardStatus = false,
      _showAMomentPlayAndPause = false,
      _progressBarTextShowPosition = false,
      _isGoingToCloseBufferingWidget = false;
  Timer _closeOverlayButtons, _timerPosition, _hidePlayAndPause;
  List<bool> _showAMomentRewindIcons = [false, false];
  int _lastPosition = 0, _forwardAmount = 0;
  VideoPlayerController _controller;
  double _draggingProgressPosition;
  bool _isDraggingProgress = false;
  Offset _horizontalDragStartOffset;
  String _activedSource;

  set fullScreen(bool value) => setState(() => isFullScreen = value);

  @override
  void initState() {
    _controller = widget.controller;
    _activedSource = widget.activedSource;
    _controller.addListener(_videoListener);
    _controller.setLooping(true);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _timerPosition?.cancel();
    _hidePlayAndPause?.cancel();
    _closeOverlayButtons?.cancel();
  }

  //----------------//
  //VIDEO CONTROLLER//
  //----------------//
  void _changeVideoSource(VideoPlayerController source, String activedSource,
      [bool initialize = true]) {
    double speed = _controller.value.playbackSpeed;
    Duration seekTo = _controller.value.position;
    setState(() {
      _showButtons = false;
      _showSettings = false;
      _activedSource = activedSource;
      if (initialize)
        source
            .initialize()
            .then((_) => _setSettingsController(source, speed, seekTo));
      else
        _setSettingsController(source, speed, seekTo);
    });
  }

  void _setSettingsController(
      VideoPlayerController source, double speed, Duration seekTo) {
    setState(() => _controller = source);
    _controller.addListener(_videoListener);
    _controller.setLooping(widget.looping);
    _controller.setPlaybackSpeed(speed);
    _controller.seekTo(seekTo);
    _controller.play();
    if (widget.onChangeSource != null)
      widget.onChangeSource(source, _activedSource);
  }

  void _videoListener() {
    if (mounted) {
      bool playing = _controller.value.isPlaying;
      if (playing != isPlaying) setState(() => isPlaying = playing);
      if (_showButtons) {
        if (isPlaying) {
          if (_timerPosition == null) _createBufferTimer();
          if (_closeOverlayButtons == null) _startCloseOverlayButtons();
        } else if (_isGoingToCloseBufferingWidget) _cancelCloseOverlayButtons();
      }
    }
  }

  //-----//
  //TIMER//
  //-----//
  void _startCloseOverlayButtons() {
    if (!_isGoingToCloseBufferingWidget) {
      setState(() {
        _isGoingToCloseBufferingWidget = true;
        _closeOverlayButtons = Timer(Duration(milliseconds: 3200), () {
          setState(() => _showButtons = false);
          _cancelCloseOverlayButtons();
        });
      });
    }
  }

  void _createBufferTimer() {
    setState(() {
      _timerPosition = Timer.periodic(Duration(milliseconds: 1000), (_) {
        int position = _controller.value.position.inMilliseconds;
        setState(() {
          if (isPlaying)
            isBuffering = _lastPosition != position ? false : true;
          else
            isBuffering = false;
          _lastPosition = position;
        });
      });
    });
  }

  void _cancelCloseOverlayButtons() {
    setState(() {
      _isGoingToCloseBufferingWidget = false;
      _closeOverlayButtons?.cancel();
      _closeOverlayButtons = null;
    });
  }

  void _onTapPlayAndPause() {
    setState(() {
      if (isPlaying)
        _controller.pause();
      else {
        _controller.play();
        _lastPosition = _lastPosition - 1;
        if (_showThumbnail) _showThumbnail = false;
      }
      if (!_showButtons) {
        _showAMomentPlayAndPause = true;
        _hidePlayAndPause?.cancel();
        _hidePlayAndPause = Timer(Duration(milliseconds: 800), () {
          setState(() => _showAMomentPlayAndPause = false);
        });
      }
    });
  }

  //------------------//
  //FORWARD AND REWIND//
  //------------------//
  void _controllerSeekTo(int amount) async {
    int seconds = _controller.value.position.inSeconds;
    await _controller.seekTo(Duration(seconds: seconds + amount));
    await _controller.play();
  }

  void _showRewindAndForward(int index, int amount) async {
    _controllerSeekTo(amount);
    setState(() {
      _forwardAmount = amount;
      _showForwardStatus = true;
      _showAMomentRewindIcons[index] = true;
    });
    Misc.delayed(400, () {
      setState(() {
        _showForwardStatus = false;
        _showAMomentRewindIcons[index] = false;
      });
    });
  }

  void _forwardDragStart(DragStartDetails details) {
    if (!_showSettings)
      setState(() {
        _horizontalDragStartOffset = details.globalPosition;
        _showForwardStatus = true;
      });
  }

  void _forwardDragEnd() {
    if (!_showSettings) {
      setState(() => _showForwardStatus = false);
      _controllerSeekTo(_forwardAmount);
    }
  }

  void _forwardDragUpdate(DragUpdateDetails details) {
    if (!_showSettings) {
      double diff = _horizontalDragStartOffset.dx - details.globalPosition.dx;
      double multiplicator = (diff.abs() / 50);
      int seconds = _controller.value.position.inSeconds;
      int amount = -((diff / 10).round() * multiplicator).round();
      setState(() {
        if (seconds + amount < _controller.value.duration.inSeconds &&
            seconds + amount > 0) _forwardAmount = amount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: _globalGesture(
        Stack(children: [
          VideoPlayer(_controller),
          if (_showThumbnail && widget.style.thumbnail != null)
            Container(child: widget.style.thumbnail),
          _rewindAndForward(),
          OpacityTransition(
            visible: _showButtons,
            child: _overlayButtons(),
          ),
          _settingsIconButton(Colors.transparent),
          Center(
            child: _playAndPause(
              Container(
                height: widget.style.playAndPauseStyle.circleSize * 2,
                width: widget.style.playAndPauseStyle.circleSize * 2,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          OpacityTransition(
            visible: isBuffering,
            child: widget.style.buffering,
          ),
          OpacityTransition(
            visible: _showForwardStatus,
            child: _forwardAmountAlert(),
          ),
          OpacityTransition(
            visible: _showAMomentPlayAndPause,
            child: _playAndPauseIconButtons(),
          ),
          SettingsMenu(
            source: widget.source,
            visible: _showSettings,
            controller: _controller,
            activedSource: _activedSource,
            changeSource: _changeVideoSource,
            changeState: () => setState(() => _showSettings = !_showSettings),
          ),
          _rewindAndForwardIconsIndicator(),
        ]),
      ),
    );
  }

  //--------//
  //GESTURES//
  //--------//
  Widget _playAndPause(Widget child) =>
      GestureDetector(child: child, onTap: _onTapPlayAndPause);

  Widget _globalGesture(Widget child) {
    return GestureDetector(
      child: child,
      onHorizontalDragStart: (DragStartDetails details) =>
          _forwardDragStart(details),
      onHorizontalDragUpdate: (DragUpdateDetails details) =>
          _forwardDragUpdate(details),
      onHorizontalDragEnd: (DragEndDetails details) => _forwardDragEnd(),
      onTap: () {
        if (!_showSettings) {
          setState(() {
            _showButtons = !_showButtons;
            if (_showButtons) _isGoingToCloseBufferingWidget = false;
          });
        }
      },
    );
  }

  Widget _rewindAndForward() {
    return _rewindAndForwardLayout(
      rewind: GestureDetector(
          onDoubleTap: () => _showRewindAndForward(0, -widget.rewindAmount)),
      forward: GestureDetector(
          onDoubleTap: () => _showRewindAndForward(1, widget.forwardAmount)),
    );
  }

  //-------//
  //WIDGETS//
  //-------//
  Widget _rewindAndForwardLayout({Widget rewind, Widget forward}) {
    return Row(children: [
      Expanded(child: rewind),
      SizedBox(width: GetContext.width(context) / 2),
      Expanded(child: forward),
    ]);
  }

  Widget _rewindAndForwardIconsIndicator() {
    return _rewindAndForwardLayout(
      rewind: OpacityTransition(
        visible: _showAMomentRewindIcons[0],
        child: Center(child: widget.style.rewind),
      ),
      forward: OpacityTransition(
        visible: _showAMomentRewindIcons[1],
        child: Center(child: widget.style.forward),
      ),
    );
  }

  Widget _playAndPauseIconButtons() {
    final style = widget.style.playAndPauseStyle;
    return Center(
      child: _playAndPause(!isPlaying ? style.playWidget : style.pauseWidget),
    );
  }

  Widget _forwardAmountAlert() {
    String text = secondsFormatter(_forwardAmount);
    final style = widget.style.forwardAndRewindStyle;
    return Align(
      alignment: style.alignment,
      child: Container(
        padding: style.padding,
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: style.borderRadius,
        ),
        child: Text(text, style: style.textStyle),
      ),
    );
  }

  //---------------//
  //OVERLAY BUTTONS//
  //---------------//
  Widget _overlayButtons() {
    return Stack(children: [
      Container(color: Colors.black.withOpacity(0.32)),
      _settingsIconButton(Colors.white),
      _bottomProgressBar(),
      widget.style.onPlayingHidePlayAndPause
          ? OpacityTransition(
              visible: !isPlaying, child: _playAndPauseIconButtons())
          : _playAndPauseIconButtons(),
    ]);
  }

  Widget _settingsIconButton(Color color) {
    return Align(
      alignment: Alignment.topRight,
      child: GestureDetector(
        onTap: () => setState(() => _showSettings = !_showSettings),
        child: Container(
          padding: Margin.all(10),
          color: Colors.transparent,
          child: Icon(Icons.settings, color: color),
        ),
      ),
    );
  }

  Widget _bottomProgressBar() {
    VideoProgressBarStyle style = widget.style.progressBarStyle;
    String position = "00:00", remaing = "-00:00", duration = "00:00";
    double padding = style.paddingBeetwen;

    if (_controller.value.initialized) {
      final value = _controller.value;
      final seconds = value.position.inSeconds;
      position = secondsFormatter(seconds);
      duration = secondsFormatter(value.duration.inSeconds);
      remaing = secondsFormatter(seconds - value.duration.inSeconds);
    }

    return Align(
      alignment: Alignment.bottomLeft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _rewindAndForward()),
        OpacityTransition(
          visible: _isDraggingProgress,
          child: Container(
            height: 20,
            width: 20,
            color: Colors.white,
            margin: Margin.left(_draggingProgressPosition - 10),
          ),
        ),
        Row(
          children: [
            Container(
              alignment: Alignment.center,
              margin: Margin.left(padding),
              color: Colors.transparent,
              child: Text(position, style: style.textStyle),
            ),
            Expanded(
              child: Padding(
                padding: Margin.horizontal(padding),
                child: VideoProgressBar(
                  _controller,
                  style: style,
                  isBuffering: isBuffering,
                  changePosition: (double position) {
                    if (position != null)
                      setState(() {
                        _draggingProgressPosition = position;
                        _isDraggingProgress = true;
                      });
                    else
                      setState(() => _isDraggingProgress = false);
                  },
                ),
              ),
            ),
            Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => setState(() => _progressBarTextShowPosition =
                    !_progressBarTextShowPosition),
                child: Text(
                  _progressBarTextShowPosition ? duration : remaing,
                  style: style.textStyle,
                ),
              ),
            ),
            Padding(
              padding: Margin.horizontal(padding > 5 ? padding - 5 : 0),
              child: GestureDetector(
                onTap: () {
                  if (!isFullScreen) {
                    PushRoute.page(
                      context,
                      FullScreenPage(
                        style: widget.style,
                        source: widget.source,
                        looping: widget.looping,
                        controller: _controller,
                        rewindAmount: widget.rewindAmount,
                        forwardAmount: widget.forwardAmount,
                        activedSource: _activedSource,
                        defaultAspectRatio: widget.defaultAspectRatio,
                        changeSource: (controller, activedSource) {
                          _changeVideoSource(controller, activedSource, false);
                        },
                      ),
                      withTransition: false,
                    );
                  } else {
                    Misc.setSystemOverlay(SystemOverlay.values);
                    Navigator.pop(context);
                  }
                },
                child: isFullScreen
                    ? widget.style.fullScreenExit
                    : widget.style.fullScreen,
              ),
            ),
          ],
        ),
        SizedBox(height: 5),
      ]),
    );
  }
}