#!/usr/bin/env python3
import atexit
import fcntl
import os
import pty
import re
import select
import signal
import sys
import termios
import tty
from collections import deque


ANSI_RE = re.compile(
    r"""
    \x1b\][^\x07\x1b]*(?:\x07|\x1b\\) |
    \x1bP.*?(?:\x1b\\) |
    \x1b\[[0-?]*[ -/]*[@-~] |
    \x1b[@-Z\\-_]
    """,
    re.VERBOSE | re.DOTALL,
)

ACTIVE_MARKERS = (
    "esc to interrupt",
    "to interrupt)",
)

CONFIRM_MARKERS = (
    "do you want me",
    "approve",
    "approval",
    "allow?",
    "proceed?",
    "[y/n]",
    "[y/n",
    "[y/n]",
    "[y/n",
    "[y/N]",
    "[Y/n]",
)


def strip_ansi(data: bytes) -> str:
    text = data.decode("utf-8", errors="ignore")
    return ANSI_RE.sub("", text)


def rewrite_active_input(data: bytes, queued_input_len: int) -> tuple[bytes, int]:
    rewritten = bytearray()
    index = 0

    while index < len(data):
        byte = data[index]
        next_byte = data[index + 1] if index + 1 < len(data) else None

        # Swallow bare Escape presses while Codex is active so queued follow-ups
        # can be edited but not interrupted or cleared accidentally.
        if byte == 0x1B and next_byte not in (ord("["), ord("O")):
            index += 1
            continue

        if byte == 0x1B and next_byte == ord("["):
            rewritten.extend((byte, next_byte))
            index += 2
            while index < len(data):
                seq_byte = data[index]
                rewritten.append(seq_byte)
                index += 1
                if 0x40 <= seq_byte <= 0x7E:
                    break
            continue

        if byte == 0x1B and next_byte == ord("O"):
            rewritten.extend((byte, next_byte))
            index += 2
            if index < len(data):
                rewritten.append(data[index])
                index += 1
            continue

        if byte in (0x0D, 0x0A):
            if queued_input_len > 0:
                rewritten.append(0x09)
                queued_input_len = 0
            else:
                rewritten.append(byte)
        else:
            rewritten.append(byte)
            if byte == 0x09:
                queued_input_len = 0
            elif byte in (0x7F, 0x08):
                queued_input_len = max(0, queued_input_len - 1)
            elif byte == 0x15:
                queued_input_len = 0
            elif byte >= 0x20:
                queued_input_len += 1

        index += 1

    return bytes(rewritten), queued_input_len


def main() -> int:
    argv = sys.argv[1:]
    if not argv:
        print("usage: codex-enter-steer.py <codex-binary> [args...]", file=sys.stderr)
        return 2

    child_pid, master_fd = pty.fork()
    if child_pid == 0:
        os.execvp(argv[0], argv)

    recent = deque(maxlen=8192)
    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    old_tty = None
    queued_input_len = 0
    was_active = False

    def sync_winsize() -> None:
        if not os.isatty(stdin_fd):
            return
        try:
            packed = fcntl.ioctl(stdin_fd, termios.TIOCGWINSZ, b"\0" * 8)
            fcntl.ioctl(master_fd, termios.TIOCSWINSZ, packed)
        except OSError:
            pass

    def cleanup() -> None:
        nonlocal old_tty
        if old_tty is not None:
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)
            old_tty = None
        try:
            os.close(master_fd)
        except OSError:
            pass

    def forward_signal(signum, _frame) -> None:
        if signum == signal.SIGWINCH:
            sync_winsize()
        try:
            os.kill(child_pid, signum)
        except ProcessLookupError:
            pass

    atexit.register(cleanup)
    for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGWINCH):
        signal.signal(signum, forward_signal)

    if os.isatty(stdin_fd):
        old_tty = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)
        sync_winsize()

    while True:
        try:
            ready, _, _ = select.select([master_fd, stdin_fd], [], [])
        except InterruptedError:
            continue

        if master_fd in ready:
            try:
                data = os.read(master_fd, 65536)
            except OSError:
                break
            if not data:
                break
            os.write(stdout_fd, data)
            cleaned = strip_ansi(data).lower()
            if cleaned:
                recent.extend(cleaned)
                recent_text = "".join(recent)
                active_now = any(marker in recent_text for marker in ACTIVE_MARKERS)
                confirm_now = any(marker.lower() in recent_text for marker in CONFIRM_MARKERS)
                if not active_now:
                    queued_input_len = 0
                if confirm_now:
                    queued_input_len = 0
                was_active = active_now

        if stdin_fd in ready:
            try:
                data = os.read(stdin_fd, 1024)
            except OSError:
                data = b""
            if not data:
                try:
                    os.close(master_fd)
                except OSError:
                    pass
                break

            recent_text = "".join(recent)
            active = any(marker in recent_text for marker in ACTIVE_MARKERS)
            confirm_prompt = any(marker.lower() in recent_text for marker in CONFIRM_MARKERS)
            if not active:
                queued_input_len = 0
            elif not was_active:
                queued_input_len = 0

            if active and not confirm_prompt:
                if data == b"\x1b":
                    try:
                        extra_ready, _, _ = select.select([stdin_fd], [], [], 0.03)
                    except InterruptedError:
                        extra_ready = []
                    if extra_ready:
                        try:
                            data += os.read(stdin_fd, 1024)
                        except OSError:
                            pass

                data, queued_input_len = rewrite_active_input(data, queued_input_len)

            try:
                os.write(master_fd, data)
            except OSError:
                break

    _, status = os.waitpid(child_pid, 0)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
