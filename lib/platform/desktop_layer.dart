import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// "Camada de desktop": posiciona a janela logo acima do Progman (janela do desktop),
/// ou seja, abaixo de todos os apps e acima do papel de parede. Clicar no desktop não a esconde.
class DesktopLayer {
  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  static final int Function(Pointer<Utf16>, Pointer<Utf16>) _findWindow = _user32
      .lookupFunction<IntPtr Function(Pointer<Utf16>, Pointer<Utf16>), int Function(Pointer<Utf16>, Pointer<Utf16>)>(
          'FindWindowW');
  static final int Function(int, int, int, int, int, int, int) _setWindowPos = _user32.lookupFunction<
      Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
      int Function(int, int, int, int, int, int, int)>('SetWindowPos');

  static final int Function(int, int) _getWindow =
      _user32.lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>('GetWindow');

  static const _swpFlags = 0x0001 | 0x0002 | 0x0010; // NOSIZE | NOMOVE | NOACTIVATE

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

  /// Coloca a janela acima de tudo (sem ativar): usado enquanto o desktop está à mostra.
  static bool bringToTop() {
    final me = _find('FLUTTER_RUNNER_WIN32_WINDOW');
    if (me == 0) return false;
    return _setWindowPos(me, 0, 0, 0, 0, 0, _swpFlags) != 0; // HWND_TOP
  }
}
