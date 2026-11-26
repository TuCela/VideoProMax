// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:ffi';
import 'dart:io';

/// 用 Win32 API 做"画中画"：把窗口缩小并置顶，退出时还原
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

/// 普通 Dart 对象，用来保存窗口原始位置（Struct 不能直接 new）
class _SavedRect {
  const _SavedRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;
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

class PipWindow {
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
  static final _MallocDart _malloc =
      _crt.lookupFunction<_MallocNative, _MallocDart>('malloc');
  static final _FreeDart _free =
      _crt.lookupFunction<_FreeNative, _FreeDart>('free');

  static _SavedRect? _saved;

  static int _hwnd() {
    var handle = _getActiveWindow();
    if (handle == 0) handle = _getForegroundWindow();
    return handle;
  }

  /// 进入画中画：缩小窗口并置顶
  static bool enter({int width = 520, int height = 300}) {
    if (!Platform.isWindows) return false;
    final handle = _hwnd();
    if (handle == 0) return false;
    final buffer = _malloc(sizeOf<_Rect>());
    if (buffer.address == 0) return false;
    try {
      final rect = buffer.cast<_Rect>();
      if (_getWindowRect(handle, rect) == 0) return false;
      final source = rect.ref;
      _saved = _SavedRect(
        source.left,
        source.top,
        source.right,
        source.bottom,
      );
      const swpNoActivate = 0x0010;
      const hwndTopmost = -1;
      _setWindowPos(handle, hwndTopmost, source.left, source.top, width, height,
          swpNoActivate);
      return true;
    } finally {
      _free(buffer);
    }
  }

  /// 退出画中画：还原窗口位置、大小并取消置顶
  static void exit() {
    if (!Platform.isWindows) return;
    final saved = _saved;
    final handle = _hwnd();
    if (saved == null || handle == 0) return;
    const swpNoActivate = 0x0010;
    const hwndNotTopmost = -2;
    _setWindowPos(
      handle,
      hwndNotTopmost,
      saved.left,
      saved.top,
      saved.right - saved.left,
      saved.bottom - saved.top,
      swpNoActivate,
    );
    _saved = null;
  }

  static bool get active => _saved != null;
}
