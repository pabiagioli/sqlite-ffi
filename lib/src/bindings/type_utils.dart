import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;
import 'package:ffi/ffi.dart';

extension StringExtensions on String {
  Pointer<Int8> toInt8({Allocator? arena}) {
    return this.toNativeUtf8(allocator: arena ?? malloc).cast<Int8>();
  }
}

extension PointerExtensions<T extends NativeType> on Pointer<T> {

  bool isNull() => this.address == nullptr.address;

  String toDartString() {
    if (T == Int8 || T == Uint8) {
      return this.cast<ffi.Utf8>().toDartString();
    }
    throw UnsupportedError('${T} unsupported');
  }

  Uint8List copyRange(int length) {
    final list = Uint8List(length);
    list.setAll(0, cast<Uint8>().asTypedList(length));
    return list;
  }

  void free() => ffi.malloc.free(this);
}

extension BlobExtensions on Uint8List {
  Pointer<Uint8> toNativeBlob({Allocator? arena, int additionalLength = 0}) {
    final allocator = arena ?? ffi.malloc;
    final ptr = allocator.allocate<Uint8>(length + additionalLength);
    final data = Uint8List(length + additionalLength)..setAll(0, this);
    ptr.asTypedList(length + additionalLength).setAll(0, data);

    return ptr;
  }
}

/// Loads a null-pointer with a specified type.
///
/// The [nullptr] getter from `dart:ffi` can be slow due to being a
/// `Pointer<Null>` on which the VM has to perform runtime type checks. See also
/// https://github.com/dart-lang/sdk/issues/39488
@pragma('vm:prefer-inline')
Pointer<T> nullPtr<T extends NativeType>() => nullptr.cast<T>();

Pointer<Void> _freeImpl(Pointer<Void> ptr) {
  ptr.free();
  return nullPtr();
}

/// Pointer to a function that frees memory we allocated.
///
/// This corresponds to `void(*)(void*)` arguments found in sqlite.
final Pointer<NativeFunction<Pointer<Void> Function(Pointer<Void>)>>
freeFunctionPtr = Pointer.fromFunction(_freeImpl);

typedef sqlite3_exec_callback = Int32 Function(
    Pointer<Void>,
    Int32,
    Pointer<Pointer<Int8>>,
    Pointer<Pointer<Int8>>,
    );
