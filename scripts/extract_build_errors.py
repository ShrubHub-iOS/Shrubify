#!/usr/bin/env python3
"""Write readable compiler diagnostics from a GitHub Actions / Theos build log."""
import argparse
from pathlib import Path
import re

ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]|\^\[\[[0-9;]*m')
ERROR = re.compile(r'(?i)\b(?:fatal\s+)?error:\s*')
FAIL = re.compile(r'(?:make(?:\[\d+\])?: \*\*\*|Process completed with exit code|Command failed)', re.I)


def strip_prefix(line):
    line = ANSI.sub('', line).strip()
    # Keep the full source location if there is one; otherwise begin at 'error:'.
    match = ERROR.search(line)
    if not match:
        return line
    start = line.rfind('Sources/', 0, match.start())
    if start >= 0:
        return line[start:]
    if '\t' in line:
        return line.split('\t')[-1].strip()
    return line[max(0, match.start() - 100):]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('logfile')
    parser.add_argument('--output', default='Outputs/Shrubify-build-errors.txt')
    args = parser.parse_args()
    lines = Path(args.logfile).read_text(encoding='utf-8', errors='replace').splitlines()
    errors, seen = [], set()
    for line in lines:
        if ERROR.search(ANSI.sub('', line)):
            cleaned = strip_prefix(line)
            if cleaned not in seen:
                seen.add(cleaned)
                errors.append(cleaned)
    if errors:
        heading = f'{len(errors)} unique compiler error lines (up to 60 shown):'
        content = '\n'.join(errors[:60])
    else:
        failures = [strip_prefix(line) for line in lines if FAIL.search(ANSI.sub('', line))]
        tail = [strip_prefix(line) for line in lines[-140:] if 'warning:' not in line.lower()]
        heading = 'No compiler error line was found; failing commands and recent non-warning output:'
        content = '\n'.join((failures[-25:] + tail[-70:]))
    report = heading + '\n\n' + content + '\n'
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(report, encoding='utf-8')
    print(report)


if __name__ == '__main__':
    main()
