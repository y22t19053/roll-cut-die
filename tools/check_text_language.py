"""Find Chinese text that can reach an English player.

The rule the game promises: an English build contains no Chinese at all; a
Chinese build may keep a little English (control names, film jargon). So every
CJK character in shipped code has to sit where it can only be shown in Chinese,
or not be shown at all:

  * inside a `_w(zh, en)` style pair call, whose first argument is Chinese;
  * inside a `_hint(key, zh, en)` call, whose second argument is Chinese;
  * inside a `{"en": ..., "zh": ...}` table or a `["中文", "EN"]` pair array;
  * assigned to a `zh`-named variable or constant;
  * under an `if Loc.language == "zh":` branch (indentation is tracked);
  * in a comment.

Everything else is a leak — and the interesting leaks are the ones that only
appear on the third death of the ninth set, which no screenshot would cover.
The runtime half of the same rule lives in tests/test_text_language.gd.

Exit codes: 0 = clean, 1 = leaks found, 2 = nothing to scan.
"""

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CJK = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")

# Calls whose FIRST argument is the Chinese half of a pair.
ZH_FIRST = {"_w", "w", "_words", "word", "_both", "_sign", "sign", "_zh", "tr"}
# Calls whose SECOND argument is the Chinese half: _hint(key, zh, en).
ZH_SECOND = {"_hint", "hint"}

# Same line already picks a language: "中文" if zh else "English", and friends.
SAME_LINE = re.compile(r"\bif\s+(?:zh|_zh|zh_mode)\b|\bif\s+Loc\.language\b|\bif\s+\.language\s*==")

# A line that opens a branch whose body is Chinese only.
ZH_BLOCK = re.compile(r"^\s*(?:if|elif)\s+(?:Loc\.language\s*==\s*\"zh\"|zh|_zh)\s*:\s*$")

# A lookup table that keeps the Chinese column next to the English one.
ZH_KEYS = ('"zh"', "'zh'", "zh:")
# Assigned to something explicitly named for the Chinese column.
ZH_NAME = r"(?<![A-Za-z0-9_])[A-Za-z0-9_]*zh[A-Za-z0-9_]*"
ZH_ASSIGN = re.compile(r"^\s*(?:static\s+)?(?:var|const)?\s*" + ZH_NAME + r"\s*(?::[^=]*)?=",
                       re.IGNORECASE)
# A two-element pair literal: ["中文", "EN"].
PAIR_ARRAY = re.compile(r"\[\s*\"[^\"]*\"\s*,\s*\"[^\"]*\"\s*\]")
# `zh_stock.append("…")` and friends: the name says which column this is.
ZH_APPEND = re.compile(ZH_NAME + r"\s*\.\s*(?:append|push_back|insert)\s*\(", re.IGNORECASE)
# An explicit, reviewable "this Chinese never reaches an English player" note.
SUPPRESS = re.compile(r"#\s*zh-ok\b")


def strip_comments(line):
    """Drop a trailing `#` comment without being fooled by a # inside a string."""
    out, quote, i = [], None, 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\":
                out.append(line[i:i + 2])
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def indent_of(line):
    return len(line) - len(line.lstrip())


def argument_index_before(line, column, names):
    """Which argument of the nearest enclosing call `names` holds `column`."""
    best, best_at = None, -1
    for name in names:
        start = 0
        while True:
            open_at = line.find(name + "(", start)
            if open_at < 0 or open_at >= column:
                break
            start = open_at + 1
            # "play_wrap(" ends with "w(" — only a standalone identifier counts.
            if open_at > 0 and (line[open_at - 1].isalnum() or line[open_at - 1] == "_"):
                continue
            if open_at <= best_at:
                continue
            depth, commas, i = 0, 0, open_at + len(name)
            while i < column:
                ch = line[i]
                if ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
                    if depth == 0:
                        break
                elif ch == "," and depth == 1:
                    commas += 1
                i += 1
            best, best_at = commas, open_at
    return best


def label(path):
    """Path as the reader of this report sees it: repo-relative when possible."""
    try:
        return str(path.resolve().relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def scan(path):
    leaks = []
    guards = []  # indent of every open Chinese-only branch
    depth = 0  # bracket depth at the start of the current line
    open_at = None  # depth at which a multi-line exemption ends
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        indent = indent_of(raw)
        while guards and indent <= guards[-1]:
            guards.pop()

        stripped = strip_comments(raw)
        here = depth
        depth += stripped.count("(") + stripped.count("[") + stripped.count("{")
        depth -= stripped.count(")") + stripped.count("]") + stripped.count("}")
        before = open_at
        if open_at is not None:
            open_at = None if depth < open_at else open_at

        opening = ZH_BLOCK.match(stripped)
        if opening:
            guards.append(indent)
            continue
        # Exemptions that open a multi-line span are decided even on lines that
        # hold no Chinese themselves: the array opener is the line that says so.
        if guards or before is not None:
            continue
        if SUPPRESS.search(raw):
            if depth > here:
                open_at = here
            continue
        if ZH_ASSIGN.match(stripped) or ZH_APPEND.search(stripped) or PAIR_ARRAY.search(stripped):
            if depth > here:
                open_at = here
            continue
        if raw.lstrip().startswith("#") or not CJK.search(stripped):
            continue
        if any(key in stripped for key in ZH_KEYS) or SAME_LINE.search(stripped):
            continue

        leak = None
        swapped_line = False
        for match in CJK.finditer(stripped):
            pos = match.start()
            if argument_index_before(stripped, pos, ZH_FIRST) == 1:
                swapped_line = True  # reported once, by english_slots()
                break
            if argument_index_before(stripped, pos, ZH_FIRST) == 0:
                continue
            if argument_index_before(stripped, pos, ZH_SECOND) == 1:
                continue
            leak = {"file": label(path), "line": number, "text": raw.strip()[:200]}
            break
        if leak and not swapped_line:
            leaks.append(leak)
    return leaks


def english_slots(path):
    """Chinese sitting in the English half of a _w(zh, en) pair."""
    bad = []
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = strip_comments(raw)
        if not CJK.search(stripped):
            continue
        for match in CJK.finditer(stripped):
            pos = match.start()
            if argument_index_before(stripped, pos, ZH_FIRST) == 1:
                bad.append({"file": label(path), "line": number, "text": raw.strip()[:200]})
                break
    return bad


EN_VALUE = re.compile(r"\"en\"\s*:\s*\"([^\"]*)\"")


def english_values(path):
    """A bilingual table whose "en" column is itself Chinese.

    This is how a Chinese label survives into an English screen even though the
    source looks perfectly paired: the pair is there, but half of it is wrong.
    """
    bad = []
    text = path.read_text(encoding="utf-8")
    for match in EN_VALUE.finditer(text):
        if CJK.search(match.group(1)):
            line = text[:match.start()].count("\n") + 1
            bad.append({"file": label(path), "line": line,
                        "text": match.group(0)[:200]})
    return bad


def main():
    # The report quotes Chinese source; a GBK console would rather crash.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--paths", nargs="*", default=["scripts", "scenes", "autoload"])
    parser.add_argument("--quiet", action="store_true", help="print the count only")
    args = parser.parse_args()

    files = []
    for entry in args.paths:
        base = ROOT / entry
        if base.is_dir():
            files.extend(p for p in base.rglob("*") if p.suffix in {".gd", ".tscn"} and p.is_file())
        elif base.is_file():
            files.append(base)
    if not files:
        print("nothing to scan", file=sys.stderr)
        return 2

    leaks, swapped = [], []
    for path in sorted(files):
        if path.name == "loc.gd":
            # The dictionary is skipped by the line scanner — its zh column is
            # the point — but its "en" column still has to read as English.
            swapped.extend(english_values(path))
            continue
        leaks.extend(scan(path))
        swapped.extend(english_slots(path))
        swapped.extend(english_values(path))

    report = {"files": len(files), "leaks": len(leaks) + len(swapped),
              "detail": leaks + swapped}
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    elif args.quiet:
        print(f"{report['leaks']} leaks in {len(files)} files")
    else:
        for leak in leaks:
            print(f"{leak['file']}:{leak['line']}: {leak['text']}")
        for swap in swapped:
            print(f"{swap['file']}:{swap['line']}: ENGLISH SLOT {swap['text']}")
        print(f"\n{report['leaks']} Chinese string(s) that can reach an English player, in {len(files)} files")
    return 0 if not report["leaks"] else 1


if __name__ == "__main__":
    sys.exit(main())
