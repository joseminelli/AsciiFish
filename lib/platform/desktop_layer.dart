import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// "Camada de desktop": posiciona a janela logo acima do Progman (janela do desktop),
/// ou seja, abaixo de todos os apps e acima do papel de parede. Clicar no desktop não a esconde.
class DesktopLayer {
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  static final int Function(Pointer<Utf16>, Pointer<Utf16>) _findWindow =
      _user32.lookupFunction<
        IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
        int Function(Pointer<Utf16>, Pointer<Utf16>)
      >('FindWindowW');
  static final int Function(int, int, int, int, int, int, int) _setWindowPos =
      _user32.lookupFunction<
        Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
        int Function(int, int, int, int, int, int, int)
      >('SetWindowPos');

  static final int Function(int, int) _getWindow = _user32
      .lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>(
        'GetWindow',
      );

  static final int Function(int) _keyState = _user32
      .lookupFunction<Int16 Function(Int32), int Function(int)>(
        'GetAsyncKeyState',
      );

  static bool _down(int vk) => (_keyState(vk) & 0x8000) != 0;

  static bool leftButtonDown() => _down(0x01);

  static bool ctrlDown() =>
      _down(0x11) && !_down(0x12); // Ctrl sem Alt (AltGr = Ctrl+Alt)

  /// Atalho global Ctrl+Alt+F (funciona mesmo sem foco, por causa do click-through).
  static bool feedHotkeyDown() => _down(0x11) && _down(0x12) && _down(0x46);

  static const _swpFlags =
      0x0001 | 0x0002 | 0x0010; // NOSIZE | NOMOVE | NOACTIVATE

  static int _find(String className) {
    final name = className.toNativeUtf16();
    try {
      return _findWindow(name, nullptr);
    } finally {
      calloc.free(name);
    }
  }

  /// Retorna true se conseguiu posicionar a janela acima do desktop.
  static bool sendAboveDesktop() {
    final progman = _find('Progman');
    final me = _find('FLUTTER_RUNNER_WIN32_WINDOW');
    if (progman == 0 || me == 0) return false;
    return _setWindowPos(me, progman, 0, 0, 0, 0, _swpFlags) != 0;
  }

  /// Win+D joga o Progman para o topo da pilha. Ele normalmente é a última (ou quase) janela;
  /// se houver muitas abaixo dele, o desktop está sendo mostrado.
  static bool desktopRaised() {
    final progman = _find('Progman');
    if (progman == 0) return false;
    var h = progman;
    for (var i = 0; i < 30; i++) {
      h = _getWindow(h, 2); // GW_HWNDNEXT: janela logo abaixo
      if (h == 0) return false;
    }
    return true;
  }

  static final int Function() _getForegroundWindow = _user32
      .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');
  static final int Function(int, Pointer<Int32>) _getWindowRect = _user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Int32>),
        int Function(int, Pointer<Int32>)
      >('GetWindowRect');
  static final int Function(int, int) _monitorFromWindow = _user32
      .lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>(
        'MonitorFromWindow',
      );
  static final int Function(int, Pointer<Int32>) _getMonitorInfo = _user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Int32>),
        int Function(int, Pointer<Int32>)
      >('GetMonitorInfoW');
  static final int Function(int, Pointer<Utf16>, int) _getClassName = _user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Utf16>, Int32),
        int Function(int, Pointer<Utf16>, int)
      >('GetClassNameW');
  static final int Function(int, int) _showWindow = _user32
      .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
        'ShowWindow',
      );

  static String _className(int hwnd) {
    final buf = calloc<Uint16>(256).cast<Utf16>();
    try {
      final n = _getClassName(hwnd, buf, 256);
      return n > 0 ? buf.toDartString(length: n) : '';
    } finally {
      calloc.free(buf);
    }
  }

  /// True se a janela em primeiro plano (jogo, vídeo, app em tela cheia) cobre o monitor inteiro
  /// onde o widget está. Janelas maximizadas não contam (não cobrem a barra de tarefas).
  static bool fullscreenAppActive() {
    final me = _find('FLUTTER_RUNNER_WIN32_WINDOW');
    final fg = _getForegroundWindow();
    if (me == 0 || fg == 0 || fg == me) return false;
    final cls = _className(fg);
    if (const {
      'Progman',
      'WorkerW',
      'Shell_TrayWnd',
      'Shell_SecondaryTrayWnd',
    }.contains(cls)) {
      return false;
    }
    final mon = _monitorFromWindow(fg, 2); // MONITOR_DEFAULTTONEAREST
    if (mon == 0 || mon != _monitorFromWindow(me, 2)) return false;
    final rect = calloc<Int32>(4);
    final info = calloc<Int32>(10); // MONITORINFO: cbSize, rcMonitor, rcWork, flags
    try {
      info[0] = 40;
      if (_getWindowRect(fg, rect) == 0 || _getMonitorInfo(mon, info) == 0) {
        return false;
      }
      return rect[0] <= info[1] &&
          rect[1] <= info[2] &&
          rect[2] >= info[3] &&
          rect[3] >= info[4];
    } finally {
      calloc.free(rect);
      calloc.free(info);
    }
  }

  /// Esconde/mostra a janela sem ativá-la (SW_HIDE / SW_SHOWNOACTIVATE).
  static void setVisible(bool visible) {
    final me = _find('FLUTTER_RUNNER_WIN32_WINDOW');
    if (me != 0) _showWindow(me, visible ? 4 : 0);
  }

  /// Coloca a janela acima de tudo (sem ativar): usado enquanto o desktop está à mostra.
  static bool bringToTop() {
    final me = _find('FLUTTER_RUNNER_WIN32_WINDOW');
    if (me == 0) return false;
    return _setWindowPos(me, 0, 0, 0, 0, 0, _swpFlags) != 0; // HWND_TOP
  }
}
