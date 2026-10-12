"""Stop 时刻 (variable D) from leaking into the next night in the sakiko work.

The work resets D when a night is finished through 下班, but not when a night is
left in any other way: dying and picking 再次尝试 on the 结局C* screens restarts
the night with the clock still at the value it had when the player died, and so
does picking a night from the title screen after playing the DLC. A night then
starts with a clock its own gates do not expect (看监控 needs D < gate, 下班 needs
D = gate), which ends the story at that node in players that hide options whose
condition does not match.

Two changes:
  1. every night's entry choice resets D to 0 (day6 already did);
  2. the 下班 gates take D >= gate instead of D = gate, so a clock that was
     carried in from an older save can still be clocked out instead of
     dead-ending.

Usage:
    python tool/fix_sakiko_clock.py [--data <dir>] [--check]

--check only reports what would change. The story data itself is not in git
(res/ is git-ignored), so keep a copy of file.json before running this.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

# The option that starts a night: node id -> option key. Each of these nodes is
# only reachable from the 载入dayN chain (asserted below).
NIGHT_ENTRY = {
    "43633137": "A",  # day1  1-电话来电
    "43633216": "A",  # day2  1-电话来电1
    "43633277": "A",  # day3  1-电话来电12
    "43633337": "A",  # day4  2亮灯判定-绿123ihf5
    "43633399": "A",  # day5  2亮灯判定-绿123ihf57
    "43633523": "A",  # day7  day7 待机
    "43633488": "A",  # day6  day6开始 (already resets D)
}

# 下班 options whose clock condition is relaxed from = to >=.
CLOCK_GATES = {
    "43633166": ("B", "C", "D"),  # night 1, gate 3
    "43633220": ("B", "C", "D"),  # night 2, gate 4
    "43633280": ("B", "C", "D"),  # night 3, gate 5
    "43633338": ("B", "C", "D"),  # night 4, gate 8
    "43633400": ("B", "C", "D"),  # night 5, gate 8
    "43633489": ("B",),           # day6 night, gate 12
    "43633524": ("B",),           # day7 (DLC), gate 8
}

META = ("title", "cid", "type", "pos")


def options(node):
    return {k: v for k, v in node.items() if k not in META and isinstance(v, dict)}


def check_entry_is_reachable_only_from_its_load_chain(data, pos):
    """The reset may only sit on a node a night entered exactly once."""
    def incoming(target):
        sources = set()
        for other, node in data.items():
            for opt in options(node).values():
                if str(opt.get("pos")) == target:
                    sources.add(other)
            if node.get("type") == "direct" and str(node.get("pos")) == target:
                sources.add(other)
        return sources

    current = pos
    for hop in range(4):
        sources = incoming(current)
        assert len(sources) == 1, f"{current} has {len(sources)} incoming edges: {sources}"
        parent = sources.pop()
        node = data[parent]
        if "载入" in node.get("title", "") or "加载" in node.get("title", ""):
            return
        assert node.get("type") == "direct", (
            f"{parent} {node.get('title')!r} is not a load node and not a direct hop"
        )
        current = parent
    raise AssertionError(f"{pos} is not reached through a load node")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", default=os.path.join("res", "works", "sakiko"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    path = os.path.join(args.data, "file.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    print(f"{path}: {len(data)} nodes")

    changes = []

    for pos, key in NIGHT_ENTRY.items():
        check_entry_is_reachable_only_from_its_load_chain(data, pos)
        node = data[pos]
        option = node[key]
        change = option.setdefault("change", [])
        reset = {"var": "D", "op": "set", "num": 0}
        if reset not in change:
            change.append(reset)
            changes.append(f"  {pos} {node.get('title')} {key} "
                           f"{option.get('text')!r}: 时刻归零")
        else:
            print(f"  {pos} {node.get('title')}: already resets 时刻")

    for pos, keys in CLOCK_GATES.items():
        node = data[pos]
        for key in keys:
            option = node[key]
            found = False
            for condition in option.get("condition") or []:
                if condition.get("var") != "D":
                    continue
                found = True
                if condition.get("op") == "ge":
                    print(f"  {pos} {node.get('title')}: already >= {condition['num']}")
                    continue
                condition["op"] = "ge"
                changes.append(f"  {pos} {node.get('title')} {key} "
                               f"{option.get('text')!r}: 时刻 = {condition['num']} "
                               f"-> >= {condition['num']}")
            if not found:
                print(f"  {pos} {node.get('title')} {key}: no 时刻 condition at all")

    if args.check:
        print("\n".join(changes) if changes else "nothing to change")
        return

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=4)
    print("\n".join(changes))
    print(f"written: {path}")


if __name__ == "__main__":
    sys.exit(main())
