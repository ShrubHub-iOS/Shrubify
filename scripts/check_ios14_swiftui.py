#!/usr/bin/env python3
"""Cheap safety check for the new Shrubify UI's iOS 14 deployment target.

This is intentionally a narrow guard for *known* SwiftUI availability pitfalls,
not a substitute for a full Swift compiler typecheck against the iOS SDK.
"""
from pathlib import Path
import re
import sys


def check(paths):
    problems = []
    for src in paths:
        for lineno, line in enumerate(src.read_text(encoding="utf-8").splitlines(), 1):
            # The iOS 14 target rejects these SwiftUI modifiers as confirmed
            # by the compiler. Text.fontWeight is supported on iOS 14;
            # the generic Button/View.fontWeight modifier is not.
            for expression, reason in (
                (r"\.monospacedDigit\s*\(", "monospacedDigit()"),
                (r"\.bold\s*\(", "bold()"),
                (r"\bButton\s*\([^)]*\)\s*\.fontWeight\s*\(", "Button.fontWeight()"),
            ):
                if re.search(expression, line):
                    problems.append(f"{src}:{lineno}: iOS 14 unsafe {reason}: {line.strip()}")
    return problems


def main():
    root = Path(__file__).resolve().parents[1]
    args = sys.argv[1:]
    paths = [Path(a) for a in args] if args else sorted((root / "Sources/EeveeSpotify/Shrubify3").rglob("*.swift"))
    if not paths:
        sys.exit("No Shrubify3 Swift files found")
    issues = check(paths)
    if issues:
        print("::error::Shrubify SwiftUI iOS 14 compatibility preflight failed.")
        print("\n".join(issues))
        sys.exit(1)
    print(f"iOS 14 SwiftUI compatibility preflight passed ({len(paths)} files).")


if __name__ == "__main__":
    main()
