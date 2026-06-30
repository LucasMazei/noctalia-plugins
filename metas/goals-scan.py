#!/usr/bin/env python3
"""Scan a folder of Obsidian goal notes (#goal frontmatter) and emit a JSON
rollup for the Metas desktop widget. Read-only; never writes to the vault.

Usage: goals-scan.py <goalsDir> <year>
Output (stdout): {year, overall, totalGoals, onTarget, categories[], goals[]}
"""
import sys, os, json, glob, re

def parse_frontmatter(path):
    fm = {}
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.readlines()
    except Exception:
        return fm
    if not lines or lines[0].strip() != "---":
        return fm
    for ln in lines[1:]:
        if ln.strip() == "---":
            break
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", ln)
        if m:
            fm[m.group(1).strip()] = m.group(2).strip()
    return fm

def to_num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None

def ratio_of(cur, tgt, direction):
    cur, tgt = to_num(cur), to_num(tgt)
    if cur is None or tgt is None:
        return None
    d = (direction or "Maximize").lower()
    if d.startswith("min"):
        if cur <= 0:
            return 1.0
        r = tgt / cur
    else:
        if tgt == 0:
            return 0.0
        r = cur / tgt
    return max(0.0, min(1.0, r))

def main():
    goals_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    year = sys.argv[2] if len(sys.argv) > 2 else None

    goals = []
    for path in sorted(glob.glob(os.path.join(goals_dir, "*.md"))):
        fm = parse_frontmatter(path)
        if year is not None and str(fm.get("year", "")).strip() != str(year):
            continue
        r = ratio_of(fm.get("current"), fm.get("target"), fm.get("direction"))
        if r is None:                      # adherence/no-metric goals: skip from math
            continue
        goals.append({
            "title": os.path.splitext(os.path.basename(path))[0],
            "type": fm.get("type", "Outros"),
            "current": to_num(fm.get("current")),
            "target": to_num(fm.get("target")),
            "direction": fm.get("direction", "Maximize"),
            "ratio": round(r, 4),
        })

    # Category rollup (mean ratio per type)
    cats = {}
    for g in goals:
        cats.setdefault(g["type"], []).append(g["ratio"])
    categories = [{
        "type": t,
        "ratio": round(sum(rs) / len(rs), 4),
        "count": len(rs),
        "onTarget": sum(1 for x in rs if x >= 0.999),
    } for t, rs in cats.items()]
    categories.sort(key=lambda c: (-c["ratio"], c["type"]))

    overall = round(sum(g["ratio"] for g in goals) / len(goals), 4) if goals else 0.0
    on_target = sum(1 for g in goals if g["ratio"] >= 0.999)

    print(json.dumps({
        "year": int(year) if year and str(year).isdigit() else year,
        "overall": overall,
        "totalGoals": len(goals),
        "onTarget": on_target,
        "categories": categories,
        "goals": goals,
    }, ensure_ascii=False))

if __name__ == "__main__":
    main()
