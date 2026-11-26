// Copyright (c) 2026 flysky
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 用 Win32 API 做「全局全屏」：去掉窗口边框、铺满主屏并置顶，
/// 退出时恢复原来的窗口尺寸、样式和层级。
///
/// 与 media_kit 的「软件内全屏」不同：这里不重建 Video，所以弹幕层、
/// 控制栏按钮等全部保留。
final class _Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

class _SavedWindow {
  const _SavedWindow(this.left, this.top, this.width, this.height, this.style);

  final int left;
  final int top;
  final int width;
  final int height;
  final int style;
}

typedef _GetRectNative = Int32 Function(IntPtr hwnd, Pointer<_Rect> rect);
typedef _GetRectDart = int Function(int hwnd, Pointer<_Rect> rect);
typedef _SetPosNative = Int32 Function(
    IntPtr hwnd, IntPtr after, Int32 x, Int32 y, Int32 cx, Int32 cy, Uint32 flags);
typedef _SetPosDart = int Function(
    int hwnd, int after, int x, int y, int cx, int cy, int flags);
typedef _HwndFnNative = IntPtr Function();
typedef _HwndFnDart = int Function();
typedef _MallocNative = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);
typedef _FreeNative = Void Function(Pointer<Void> ptr);
typedef _FreeDart = void Function(Pointer<Void> ptr);
typedef _MetricsNative = Int32 Function(Int32 index);
typedef _MetricsDart = int Function(int index);
typedef _ShowNative = Int32 Function(IntPtr hwnd, Int32 cmd);
typedef _ShowDart = int Function(int hwnd, int cmd);
typedef _GetLongNative = IntPtr Function(IntPtr hwnd, Int32 index);
typedef _GetLongDart = int Function(int hwnd, int index);
typedef _SetLongNative = IntPtr Function(IntPtr hwnd, Int32 index, IntPtr value);
typedef _SetLongDart = int Function(int hwnd, int index, int value);

class GlobalFullscreen {
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  static final DynamicLibrary _crt = DynamicLibrary.open('msvcrt.dll');

  static final _HwndFnDart _getActiveWindow =
      _user32.lookupFunction<_HwndFnNative, _HwndFnDart>('GetActiveWindow');
  static final _HwndFnDart _getForegroundWindow =
      _user32.lookupFunction<_HwndFnNative, _HwndFnDart>('GetForegroundWindow');
  static final _GetRectDart _getWindowRect =
      _user32.lookupFunction<_GetRectNative, _GetRectDart>('GetWindowRect');
  static final _SetPosDart _setWindowPos =
      _user32.lookupFunction<_SetPosNative, _SetPosDart>('SetWindowPos');
  static final _MetricsDart _getSystemMetrics =
      _user32.lookupFunction<_MetricsNative, _MetricsDart>('GetSystemMetrics');
  static final _ShowDart _showWindow =
      _user32.lookupFunction<_ShowNative, _ShowDart>('ShowWindow');
  static final _MallocDart _malloc =
      _crt.lookupFunction<_MallocNative, _MallocDart>('malloc');
  static final _FreeDart _free =
      _crt.lookupFunction<_FreeNative, _FreeDart>('free');

  static final _GetLongDart _getWindowLong = _initGetLong();
  static final _SetLongDart _setWindowLong = _initSetLong();

  static _GetLongDart _initGetLong() {
    // 64 位用 GetWindowLongPtrW；32 位回退到 GetWindowLongW。
    try {
      return _user32.lookupFunction<_GetLongNative, _GetLongDart>(
          'GetWindowLongPtrW');
    } catch (_) {
      final get32 = _user32.lookupFunction<Int32 Function(IntPtr, Int32),
          int Function(int, int)>('GetWindowLongW');
      return (h, i) => get32(h, i);
    }
  }

  static _SetLongDart _initSetLong() {
    try {
      return _user32.lookupFunction<_SetLongNative, _SetLongDart>(
          'SetWindowLongPtrW');
    } catch (_) {
      final set32 = _user32.lookupFunction<Int32 Function(IntPtr, Int32, Int32),
          int Function(int, int, int)>('SetWindowLongW');
      return (h, i, v) => set32(h, i, v);
    }
  }

  static const int _gwlStyle = -16;
  static const int _wsCaption = 0x00C00000;
  static const int _wsThickFrame = 0x00040000;
  static const int _wsSysMenu = 0x00080000;
  static const int _wsMaximizeBox = 0x00010000;
  static const int _wsMinimizeBox = 0x00020000;
  static const int _swpNoActivate = 0x0010;
  static const int _swpFrameChanged = 0x0020;
  static const int _hwndTopmost = -1;
  static const int _hwndNotTopmost = -2;
  static const int _swRestore = 9;

  static _SavedWindow? _saved;

  /// 供 UI 监听全屏状态变化以刷新按钮图标。
  static final ValueNotifier<bool> stateNotifier = ValueNotifier<bool>(false);

  static int _hwnd() {
    var handle = _getActiveWindow();
    if (handle == 0) handle = _getForegroundWindow();
    return handle;
  }

  /// 进入全局全屏。返回是否成功。
  static bool enter() {
    if (!Platform.isWindows) return false;
    final handle = _hwnd();
    if (handle == 0) return false;
    final buffer = _malloc(sizeOf<_Rect>());
    if (buffer.address == 0) return false;
    try {
      final rect = buffer.cast<_Rect>();
      if (_getWindowRect(handle, rect) == 0) return false;
      final source = rect.ref;
      final style = _getWindowLong(handle, _gwlStyle);
      _saved = _SavedWindow(
        source.left,
        source.top,
        source.right - source.left,
        source.bottom - source.top,
        style,
      );
      // 去掉标题栏与可调边框，铺满主屏并置顶。
      final borderless = style &
          ~(_wsCaption |
              _wsThickFrame |
              _wsSysMenu |
              _wsMaximizeBox |
              _wsMinimizeBox);
      _setWindowLong(handle, _gwlStyle, borderless);
      final width = _getSystemMetrics(0);
      final height = _getSystemMetrics(1);
      _setWindowPos(
        handle,
        _hwndTopmost,
        0,
        0,
        width,
        height,
        _swpFrameChanged | _swpNoActivate,
      );
      stateNotifier.value = true;
      return true;
    } catch (_) {
      return false;
    } finally {
      _free(buffer);
    }
  }

  /// 退出全局全屏，恢复原窗口。
  static void exit() {
    if (!Platform.isWindows) return;
    final saved = _saved;
    final handle = _hwnd();
    if (saved == null || handle == 0) return;
    try {
      _setWindowLong(handle, _gwlStyle, saved.style);
      _showWindow(handle, _swRestore);
      _setWindowPos(
        handle,
        _hwndNotTopmost,
        saved.left,
        saved.top,
        saved.width,
        saved.height,
        _swpFrameChanged | _swpNoActivate,
      );
    } catch (_) {
      // 忽略恢复失败
    }
    _saved = null;
    stateNotifier.value = false;
  }

  static bool toggle() {
    if (active) {
      exit();
      return false;
    }
    return enter();
  }

  static bool get active => _saved != null;
}
