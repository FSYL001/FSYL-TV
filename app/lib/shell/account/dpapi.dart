import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows DPAPI wrapper used for the account token (SPEC §7).
///
/// Data is encrypted for the current Windows user; the ciphertext is stored in
/// data\account\token.bin and cannot be read by another account or machine.
class Dpapi {
  Dpapi._();

  static const int _uiForbidden = 0x1;

  static Uint8List protect(Uint8List data) {
    final input = calloc<CRYPT_INTEGER_BLOB>();
    final output = calloc<CRYPT_INTEGER_BLOB>();
    final buffer = calloc<Uint8>(data.isEmpty ? 1 : data.length);
    try {
      buffer.asTypedList(data.length).setAll(0, data);
      input.ref
        ..cbData = data.length
        ..pbData = buffer;
      final ok = CryptProtectData(
        input,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _uiForbidden,
        output,
      );
      if (ok == 0) {
        throw StateError('CryptProtectData failed');
      }
      final result = Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
      LocalFree(output.ref.pbData.cast());
      return result;
    } finally {
      calloc.free(input);
      calloc.free(output);
      calloc.free(buffer);
    }
  }

  static Uint8List unprotect(Uint8List data) {
    final input = calloc<CRYPT_INTEGER_BLOB>();
    final output = calloc<CRYPT_INTEGER_BLOB>();
    final buffer = calloc<Uint8>(data.isEmpty ? 1 : data.length);
    try {
      buffer.asTypedList(data.length).setAll(0, data);
      input.ref
        ..cbData = data.length
        ..pbData = buffer;
      final ok = CryptUnprotectData(
        input,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _uiForbidden,
        output,
      );
      if (ok == 0) {
        throw StateError('CryptUnprotectData failed');
      }
      final result = Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
      LocalFree(output.ref.pbData.cast());
      return result;
    } finally {
      calloc.free(input);
      calloc.free(output);
      calloc.free(buffer);
    }
  }
}
