import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows Job Object: JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
///
/// The app creates one job and assigns the MoonTV sidecar to it. If the main
/// process is killed (even with TerminateProcess), Windows closes the job handle
/// and terminates the child tree, so no orphan node.exe remains.
final class _JobBasicLimitInformation extends Struct {
  @Int64() external int perProcessUserTimeLimit;
  @Int64() external int perJobUserTimeLimit;
  @Uint32() external int limitFlags;
  @UintPtr() external int minimumWorkingSetSize;
  @UintPtr() external int maximumWorkingSetSize;
  @Uint32() external int activeProcessLimit;
  @UintPtr() external int affinity;
  @Uint32() external int priorityClass;
  @Uint32() external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64() external int readOperationCount;
  @Uint64() external int writeOperationCount;
  @Uint64() external int otherOperationCount;
  @Uint64() external int readTransferCount;
  @Uint64() external int writeTransferCount;
  @Uint64() external int otherTransferCount;
}

final class _JobExtendedLimitInformation extends Struct {
  external _JobBasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;
  @UintPtr() external int processMemoryLimit;
  @UintPtr() external int jobMemoryLimit;
  @UintPtr() external int peakProcessMemoryUsed;
  @UintPtr() external int peakJobMemoryUsed;
}

class JobObject {
  JobObject._();

  static final JobObject instance = JobObject._();

  static const int _jobObjectExtendedLimitInformation = 9;
  static const int _jobObjectLimitKillOnJobClose = 0x2000;
  static const int _processSetQuota = 0x0100;
  static const int _processTerminate = 0x0001;

  int? _job;
  bool _failed = false;

  /// Assign [pid] to the kill-on-close job. Safe to call repeatedly.
  bool assign(int pid) {
    if (_failed) return false;
    try {
      _job ??= _createJob();
      final job = _job;
      if (job == null) {
        _failed = true;
        return false;
      }
      final handle = OpenProcess(
        _processSetQuota | _processTerminate,
        0,
        pid,
      );
      if (handle == 0) return false;
      final ok = AssignProcessToJobObject(job, handle) != 0;
      CloseHandle(handle);
      return ok;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  int? _createJob() {
    final job = CreateJobObject(nullptr, nullptr);
    if (job == 0) return null;
    final info = calloc<_JobExtendedLimitInformation>();
    try {
      info.ref.basicLimitInformation.limitFlags =
          _jobObjectLimitKillOnJobClose;
      final ok = SetInformationJobObject(
        job,
        _jobObjectExtendedLimitInformation,
        info.cast(),
        sizeOf<_JobExtendedLimitInformation>(),
      );
      if (ok == 0) {
        CloseHandle(job);
        return null;
      }
      return job;
    } finally {
      calloc.free(info);
    }
  }
}
