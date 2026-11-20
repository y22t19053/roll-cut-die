"""Windows QA only: watch foreground ownership without taking focus or sending keys.
Start this before the operator clicks the game; then Alt+Tab once. No window titles,
foreign PIDs or participant data are recorded. Pair stdout with a sealed QA stream.
"""
import argparse
import ctypes
import json
import time
from ctypes import wintypes


def observe(sample, emit, timeout, clock=time.monotonic, sleep=time.sleep):
    start = clock()
    seen_game = False
    last = object()
    while clock() - start < timeout:
        state = sample()  # None = no foreground handle / owner not available
        if state != last:
            emit({'elapsed_ms': round((clock()-start)*1000), 'game_foreground': state})
            last = state
        if state is True:
            seen_game = True
        elif state is False and seen_game:
            return 'OBSERVED_GAME_TO_OTHER'
        sleep(.025)
    return 'NO_CONFIRMED_LOSS' if seen_game else 'GAME_NEVER_CONFIRMED_FOREGROUND'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('game_pid', type=int)
    ap.add_argument('--seconds', type=int, default=30)
    args = ap.parse_args()
    if args.game_pid <= 0 or not 1 <= args.seconds <= 180:
        ap.error('expected a positive game PID and 1..180 seconds')
    user = ctypes.WinDLL('user32')
    user.GetForegroundWindow.argtypes = []
    user.GetForegroundWindow.restype = wintypes.HWND
    owner = user.GetWindowThreadProcessId
    owner.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    owner.restype = wintypes.DWORD
    def sample():
        window = user.GetForegroundWindow()
        pid = wintypes.DWORD()
        if not window or not owner(window, ctypes.byref(pid)) or not pid.value:
            return None
        return pid.value == args.game_pid
    verdict = observe(sample, lambda row: print(json.dumps(row), flush=True), args.seconds)
    print(verdict)
    return 0 if verdict == 'OBSERVED_GAME_TO_OTHER' else 2


if __name__ == '__main__':
    raise SystemExit(main())
