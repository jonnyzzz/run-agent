#!/usr/bin/env -S uv run python
"""Live agent monitor.

Usage:
  uv run python monitor-agents.py

Options:
  --runs-dir PATH         Path to runs directory (default: ./runs)
  --poll-interval SECS    Poll interval for log updates (default: 0.5)
  --summary-interval SECS Summary refresh interval (default: 10)
  --from-start            Stream logs from start (default: tail only)
  --no-summary            Disable periodic summary blocks
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path
from typing import Dict, Tuple
from collections import deque
import shutil


def is_pid_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def format_age(seconds: float) -> str:
    if seconds < 60:
        return f"{int(seconds)}s"
    if seconds < 3600:
        return f"{int(seconds // 60)}m"
    return f"{int(seconds // 3600)}h"


def read_new_lines(path: Path, offset: int) -> Tuple[int, list[str]]:
    try:
        with path.open("r", encoding="utf-8", errors="replace") as f:
            f.seek(offset)
            data = f.read()
            if not data:
                return offset, []
            new_offset = f.tell()
            lines = data.splitlines()
            return new_offset, lines
    except FileNotFoundError:
        return offset, []


def scan_runs(runs_dir: Path) -> Dict[str, dict]:
    runs: Dict[str, dict] = {}
    for run_dir in sorted(runs_dir.glob("run_*")):
        if not run_dir.is_dir():
            continue
        run_id = run_dir.name
        # New standard files
        stdout_log = run_dir / "agent-stdout.txt"
        stderr_log = run_dir / "agent-stderr.txt"
        logs = []
        if stdout_log.exists():
            logs.append(stdout_log)
        if stderr_log.exists():
            logs.append(stderr_log)
        # Backward compatibility
        logs.extend(sorted(run_dir.glob("agent-logs/*.log")))
        pid_files = []
        pid_txt = run_dir / "pid.txt"
        if pid_txt.exists():
            pid_files.append(pid_txt)
        pid_files.extend(sorted(run_dir.glob("*.pid")))
        runs[run_id] = {
            "dir": run_dir,
            "logs": logs,
            "pid_files": pid_files,
        }
    return runs


def main() -> int:
    parser = argparse.ArgumentParser(description="Monitor agent logs and statuses.")
    default_runs = os.environ.get("RUNS_DIR", str(Path(__file__).resolve().parent / "runs"))
    parser.add_argument("--runs-dir", default=default_runs, help=f"runs directory (default: {default_runs})")
    parser.add_argument("--poll-interval", type=float, default=0.5, help="poll interval seconds (default: 0.5)")
    parser.add_argument("--summary-interval", type=float, default=10.0, help="summary interval seconds (default: 10)")
    parser.add_argument("--summary-lines", type=int, default=4, help="max summary lines (default: 4)")
    parser.add_argument("--tail-lines", type=int, default=0, help="override log lines to show (default: auto fit)")
    parser.add_argument("--from-start", action="store_true", help="stream logs from start")
    parser.add_argument("--no-summary", action="store_true", help="disable periodic summary")
    args = parser.parse_args()

    runs_dir = Path(args.runs_dir).resolve()
    if not runs_dir.exists():
        print(f"runs dir not found: {runs_dir}", file=sys.stderr)
        return 2

    offsets: Dict[Path, int] = {}
    last_line: Dict[str, str] = {}
    last_line_time: Dict[str, float] = {}
    status_cache: Dict[str, str] = {}
    log_buffer: deque[Tuple[str, str]] = deque(maxlen=5000)

    is_tty = sys.stdout.isatty()
    if is_tty:
        C_RESET = "\033[0m"
        C_BOLD = "\033[1m"
        C_RUN = "\033[32m"   # green
        C_FIN = "\033[36m"   # cyan
        C_UNK = "\033[33m"   # yellow
        COLOR_PALETTE = [
            "\033[31m",  # red
            "\033[32m",  # green
            "\033[33m",  # yellow
            "\033[34m",  # blue
            "\033[35m",  # magenta
            "\033[36m",  # cyan
            "\033[91m",  # bright red
            "\033[92m",  # bright green
            "\033[93m",  # bright yellow
            "\033[94m",  # bright blue
            "\033[95m",  # bright magenta
            "\033[96m",  # bright cyan
        ]
    else:
        C_RESET = C_BOLD = C_RUN = C_FIN = C_UNK = ""
        COLOR_PALETTE = [""]
    run_color_cache: Dict[str, str] = {}

    def color_for_run(run_id: str) -> str:
        if not is_tty:
            return ""
        if run_id in run_color_cache:
            return run_color_cache[run_id]
        idx = sum(ord(ch) for ch in run_id) % len(COLOR_PALETTE)
        run_color_cache[run_id] = COLOR_PALETTE[idx]
        return run_color_cache[run_id]

    def format_run_id(run_id: str) -> str:
        color = color_for_run(run_id)
        return f"{color}{run_id}{C_RESET}" if color else run_id

    def format_log_line(run_id: str, line: str) -> str:
        prefix = f"[{format_run_id(run_id)}]"
        return f"{prefix} {line}"

    last_summary = 0.0
    while True:
        runs = scan_runs(runs_dir)
        any_new_lines = False

        # Cache task titles from prompt.md
        for run_id, info in runs.items():
            prompt_path = info["dir"] / "prompt.md"
            if "task_title" not in info:
                title = ""
                try:
                    with prompt_path.open("r", encoding="utf-8", errors="replace") as f:
                        for _ in range(200):
                            line = f.readline()
                            if not line:
                                break
                            line = line.strip()
                            if line.startswith("# Task:"):
                                title = line.replace("# Task:", "").strip()
                                break
                            if line.startswith("Task:"):
                                title = line.replace("Task:", "").strip()
                                break
                except FileNotFoundError:
                    title = ""
                info["task_title"] = title

        # Track new log files
        for run_id, info in runs.items():
            for log_path in info["logs"]:
                if log_path not in offsets:
                    try:
                        size = log_path.stat().st_size
                    except FileNotFoundError:
                        size = 0
                    offsets[log_path] = 0 if args.from_start else size

        # Stream log updates (append to buffer)
        for run_id, info in runs.items():
            for log_path in info["logs"]:
                offset = offsets.get(log_path, 0)
                new_offset, lines = read_new_lines(log_path, offset)
                offsets[log_path] = new_offset
                if not lines:
                    continue
                for line in lines:
                    if not line:
                        continue
                    log_buffer.append((run_id, line))
                    any_new_lines = True
                    last_line[run_id] = line
                    last_line_time[run_id] = time.time()

        # Update status changes
        for run_id, info in runs.items():
            status = "unknown"
            if info["pid_files"]:
                running = False
                for pf in info["pid_files"]:
                    try:
                        pid = int(pf.read_text().strip())
                    except Exception:
                        continue
                    if is_pid_running(pid):
                        running = True
                        break
                status = "running" if running else "finished"
            else:
                # PID file removed on completion; infer finished from EXIT_CODE in cwd.txt
                cwd_file = info["dir"] / "cwd.txt"
                try:
                    text = cwd_file.read_text(encoding="utf-8", errors="replace")
                except FileNotFoundError:
                    text = ""
                if "EXIT_CODE=" in text:
                    status = "finished"
            if status_cache.get(run_id) != status:
                status_cache[run_id] = status

        # Summary block + screen render
        now = time.time()
        if any_new_lines or (now - last_summary) >= args.summary_interval:
            last_summary = now
            groups = {"running": [], "finished": [], "unknown": []}
            for run_id in sorted(runs.keys()):
                groups[status_cache.get(run_id, "unknown")].append(run_id)

            # Header lines
            running_list = ", ".join(format_run_id(rid) for rid in groups["running"]) if groups["running"] else "-"
            finished_list = ", ".join(format_run_id(rid) for rid in groups["finished"]) if groups["finished"] else "-"
            unknown_list = ", ".join(format_run_id(rid) for rid in groups["unknown"]) if groups["unknown"] else "-"
            header = [
                f"{C_BOLD}Agent Status @ {time.strftime('%H:%M:%S')}  runs={len(runs)}{C_RESET}",
                f"{C_RUN}running({len(groups['running'])}): {running_list}{C_RESET}",
                f"{C_FIN}finished({len(groups['finished'])}): {finished_list}{C_RESET}",
                f"{C_UNK}unknown({len(groups['unknown'])}): {unknown_list}{C_RESET}",
                "-" * 72,
            ]

            # Determine how many log lines to render
            term_height = shutil.get_terminal_size((120, 30)).lines
            header_lines = len(header)
            tail_lines = args.tail_lines if args.tail_lines > 0 else max(5, term_height - header_lines - 2)
            tail_lines = min(tail_lines, len(log_buffer))

            if is_tty:
                # Render full screen in TTY
                sys.stdout.write("\033[2J\033[H")
                for line in header:
                    sys.stdout.write(line + "\n")
                if tail_lines:
                    for run_id, line in list(log_buffer)[-tail_lines:]:
                        sys.stdout.write(format_log_line(run_id, line) + "\n")
                sys.stdout.flush()
            else:
                # Non-tty: print only new lines
                if any_new_lines:
                    for run_id, line in list(log_buffer)[-tail_lines:]:
                        sys.stdout.write(format_log_line(run_id, line) + "\n")
                    sys.stdout.flush()

        time.sleep(args.poll_interval)


if __name__ == "__main__":
    raise SystemExit(main())
