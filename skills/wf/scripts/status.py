#!/usr/bin/env python3
"""作業ステータス（docs/issues/<issue_name>/status.json）の生成・更新を自動化する CLI。

status は md ではなく **JSON** を真実源とし、各ノードはこのスクリプト経由で更新する
（手で JSON を編集しない）。スキーマは .claude/templates/status.schema.json。
作業フォルダの場所は .claude/config.json の paths.work_ledger_dir（既定 docs/issues）。

使い方:
  status.py new "<タスク名>" [--issue N] [--type 標準|content|ui]
      → <work_ledger_dir>/<issue_name>/status.json を作成し、絶対パスを表示。
  status.py set    <status.json> <key> <value>        # current_node / priority / done / issue ...
  status.py node   <status.json> <node> [--status todo|doing|done] [--result PASS|FAIL]
                   [--note "..."] [--commit <hash>] [--pr <url>] [--coverage backend=97.6 flutter=92.0]
  status.py check  <status.json> <node> <key> [--done|--undone]
  status.py commit <status.json> --node <node> --hash <hash> [--summary "..."]
  status.py metric <status.json> <node> [--start] [--end] [--loopback] [--artifacts N]
                   [--tokens in=.. out=..]            # トークン/速度/手戻り/成果物数の計測
  status.py show   <status.json>                       # 人間可読サマリ（日本語）

node 名: design / implement / verify / review / mr（日本語 設計/実装/検証/レビュー/MR も可）。
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "lib"))
from config import get, load_config, repo_root  # noqa: E402

SCHEMA = "aidd/status@1"
ROOT = repo_root()
_CFG = load_config()
LEDGER_DIR = get(_CFG, "paths.work_ledger_dir", "docs/issues")


def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _new_metrics() -> dict:
    """ノードの計測枠。時間/手戻り/成果物数は正確、tokens は best-effort(自己申告/transcript)。"""
    return {"started_at": None, "ended_at": None, "duration_sec": 0,
            "tokens": {"in": 0, "out": 0, "total": 0}, "loopbacks": 0, "artifacts": 0}

NODE_ALIAS = {
    "設計": "design", "実装": "implement", "検証": "verify",
    "レビュー": "review", "mr": "mr", "MR": "mr",
    "design": "design", "implement": "implement", "verify": "verify",
    "review": "review",
}
NODE_JA = {
    "design": "設計", "implement": "実装", "verify": "検証",
    "review": "レビュー", "mr": "MR",
}
NODE_ORDER = ["design", "implement", "verify", "review", "mr"]


def _today() -> str:
    return datetime.date.today().isoformat()


def _slug(title: str) -> str:
    s = title.strip().replace(" ", "-").replace("/", "-")
    # 英数・日本語・_- のみ残す
    s = re.sub(r"[^0-9A-Za-z぀-ヿ一-龯ー_-]", "", s)
    return s or "task"


def _resolve_node(name: str) -> str:
    n = NODE_ALIAS.get(name)
    if not n:
        sys.exit(f"未知のノード: {name}（design/implement/verify/review/mr）")
    return n


def _default_status(title: str, issue, ntype: str) -> dict:
    st = {
        "schema": SCHEMA,
        "title": title,
        "issue": issue,
        "issue_url": None,
        "type": ntype,
        "priority": None,
        "created": _today(),
        "current_node": "design",
        "done": False,
        "nodes": {
            "design": {"status": "todo", "notes": "", "checks": {}, "commit": None,
                       "metrics": _new_metrics()},
            "implement": {"status": "todo", "notes": "", "checks": {}, "commit": None,
                          "metrics": _new_metrics()},
            "verify": {"status": "todo", "notes": "", "result": None,
                       "coverage": {}, "checks": {}, "commit": None,
                       "metrics": _new_metrics()},
            "review": {"status": "todo", "notes": "", "findings": [],
                       "checks": {}, "commit": None, "metrics": _new_metrics()},
            "mr": {"status": "todo", "notes": "", "pr_url": None,
                   "checks": {}, "commit": None, "metrics": _new_metrics()},
        },
        "commits": [],
    }
    if ntype == "content":
        st["domain"] = {"kind": "content", "track": None, "concept": None,
                        "lesson_path": None, "check_content": None}
    elif ntype == "ui":
        st["domain"] = {"kind": "ui", "target": None, "states": [],
                        "run_checks": None}
    return st


def _load(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"status.json を読めません: {exc}")


def _save(path: str, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def _gh_url(issue) -> str | None:
    if not issue:
        return None
    import shutil
    import subprocess
    if not shutil.which("gh"):
        return None
    try:
        out = subprocess.run(
            ["gh", "issue", "view", str(issue), "--json", "url", "-q", ".url"],
            capture_output=True, text=True, timeout=15,
        )
        url = out.stdout.strip()
        return url or None
    except Exception:  # noqa: BLE001
        return None


def cmd_new(args) -> None:
    ntype = {"学習コンテンツ": "content", "UI": "ui"}.get(args.type, args.type)
    if ntype not in ("標準", "content", "ui"):
        ntype = "標準"
    slug = _slug(args.title)
    name = f"{args.issue}-{slug}" if args.issue else slug
    out_dir = os.path.join(ROOT, *LEDGER_DIR.split("/"), name)
    out = os.path.join(out_dir, "status.json")
    os.makedirs(out_dir, exist_ok=True)
    if os.path.exists(out):
        print(out)
        return
    data = _default_status(args.title, args.issue, ntype)
    data["issue_url"] = _gh_url(args.issue)
    _save(out, data)
    print(out)


def cmd_name(args) -> None:
    """issue_name（NN-slug か slug）を表示する。worktree 名/ブランチ名に使う。"""
    slug = _slug(args.title)
    print(f"{args.issue}-{slug}" if args.issue else slug)


def cmd_set(args) -> None:
    data = _load(args.path)
    key, val = args.key, args.value
    if key not in data:
        sys.exit(f"未知のトップレベルキー: {key}")
    if key == "done":
        val = val.lower() in ("1", "true", "yes", "y")
    elif key == "issue":
        val = int(val) if val.isdigit() else val
        data["issue_url"] = _gh_url(val)
    data[key] = val
    _save(args.path, data)
    print(f"set {key}={val}")


def cmd_node(args) -> None:
    data = _load(args.path)
    node = _resolve_node(args.node)
    n = data["nodes"][node]
    if args.status:
        n["status"] = args.status
    if args.result is not None:
        n["result"] = args.result
    if args.note is not None:
        n["notes"] = args.note
    if args.commit is not None:
        n["commit"] = args.commit
    if args.pr is not None:
        n["pr_url"] = args.pr
    for kv in args.coverage or []:
        k, _, v = kv.partition("=")
        n.setdefault("coverage", {})[k] = float(v) if v else None
    data["current_node"] = node
    _save(args.path, data)
    print(f"node {node} -> {json.dumps(n, ensure_ascii=False)}")


def cmd_check(args) -> None:
    data = _load(args.path)
    node = _resolve_node(args.node)
    data["nodes"][node].setdefault("checks", {})[args.key] = not args.undone
    _save(args.path, data)
    print(f"check {node}.{args.key} = {not args.undone}")


def cmd_commit(args) -> None:
    data = _load(args.path)
    node = _resolve_node(args.node)
    data["commits"].append({"node": NODE_JA[node], "hash": args.hash,
                            "summary": args.summary or ""})
    data["nodes"][node]["commit"] = args.hash
    if data["nodes"][node]["status"] != "done":
        data["nodes"][node]["status"] = "done"
    _save(args.path, data)
    print(f"commit recorded: {node} {args.hash}")


def _parse_iso(ts: str):
    try:
        return datetime.datetime.fromisoformat((ts or "").replace("Z", "+00:00"))
    except Exception:  # noqa: BLE001
        return None


def cmd_metric(args) -> None:
    """ノードのメトリクス(トークン/速度/手戻り/成果物数)を記録する。

    時間は --start/--end で正確に計測（duration を自動計算）、--loopback は再入回数を +1、
    --artifacts は変更ファイル数、--tokens in=.. out=.. は best-effort(自己申告/transcript 由来)。
    """
    data = _load(args.path)
    node = _resolve_node(args.node)
    m = data["nodes"][node].setdefault("metrics", _new_metrics())
    if args.start:
        m["started_at"] = _now_iso()
    if args.loopback:
        m["loopbacks"] = int(m.get("loopbacks", 0)) + 1
    if args.artifacts is not None:
        m["artifacts"] = args.artifacts
    for kv in args.tokens or []:
        k, _, v = kv.partition("=")
        if k in ("in", "out") and v:
            m.setdefault("tokens", {"in": 0, "out": 0, "total": 0})[k] = int(v)
    if "tokens" in m:
        m["tokens"]["total"] = int(m["tokens"].get("in", 0)) + int(m["tokens"].get("out", 0))
    if args.end:
        m["ended_at"] = _now_iso()
        st, en = _parse_iso(m.get("started_at")), _parse_iso(m["ended_at"])
        if st and en:
            m["duration_sec"] = int((en - st).total_seconds())
    _save(args.path, data)
    print(f"metric {node} -> {json.dumps(m, ensure_ascii=False)}")


def cmd_show(args) -> None:
    d = _load(args.path)
    line = "─" * 60
    print(line)
    print(f"作業: {d['title']}  [{d['type']}]  current={NODE_JA.get(d['current_node'], d['current_node'])}"
          + ("  ✅完了" if d.get("done") else ""))
    issue = f"#{d['issue']}" if d.get("issue") else "なし"
    print(f"Issue: {issue}  {d.get('issue_url') or ''}  起票 {d.get('created')}")
    print(line)
    for node in NODE_ORDER:
        n = d["nodes"][node]
        mark = {"done": "✅", "doing": "🔄", "todo": "⬜"}.get(n["status"], "⬜")
        extra = ""
        if node == "verify" and n.get("result"):
            cov = " ".join(f"{k}={v}%" for k, v in (n.get("coverage") or {}).items())
            extra = f"  result={n['result']} {cov}"
        if n.get("commit"):
            extra += f"  commit={n['commit'][:9]}"
        print(f"  {mark} {NODE_JA[node]:<6}{extra}")
        m = n.get("metrics") or {}
        tok = (m.get("tokens") or {}).get("total", 0)
        if m.get("duration_sec") or m.get("loopbacks") or tok or m.get("artifacts"):
            print(f"       ⏱ {m.get('duration_sec', 0)}s  ↺{m.get('loopbacks', 0)}  "
                  f"tok={tok}  files={m.get('artifacts', 0)}")
        for k, v in (n.get("checks") or {}).items():
            print(f"       [{'x' if v else ' '}] {k}")
    if d.get("commits"):
        print(line)
        print("コミット:")
        for c in d["commits"]:
            print(f"  - {c['node']}: {c['hash'][:9]} {c['summary']}")
    print(line)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="status.py", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("new"); s.add_argument("title")
    s.add_argument("--issue"); s.add_argument("--type", default="標準")
    s.set_defaults(func=cmd_new)

    s = sub.add_parser("name"); s.add_argument("title"); s.add_argument("--issue")
    s.set_defaults(func=cmd_name)

    s = sub.add_parser("set"); s.add_argument("path"); s.add_argument("key")
    s.add_argument("value"); s.set_defaults(func=cmd_set)

    s = sub.add_parser("node"); s.add_argument("path"); s.add_argument("node")
    s.add_argument("--status", choices=["todo", "doing", "done"])
    s.add_argument("--result", choices=["PASS", "FAIL"])
    s.add_argument("--note"); s.add_argument("--commit"); s.add_argument("--pr")
    s.add_argument("--coverage", nargs="*"); s.set_defaults(func=cmd_node)

    s = sub.add_parser("check"); s.add_argument("path"); s.add_argument("node")
    s.add_argument("key"); s.add_argument("--undone", action="store_true")
    s.add_argument("--done", action="store_true"); s.set_defaults(func=cmd_check)

    s = sub.add_parser("commit"); s.add_argument("path")
    s.add_argument("--node", required=True); s.add_argument("--hash", required=True)
    s.add_argument("--summary"); s.set_defaults(func=cmd_commit)

    s = sub.add_parser("metric"); s.add_argument("path"); s.add_argument("node")
    s.add_argument("--start", action="store_true"); s.add_argument("--end", action="store_true")
    s.add_argument("--loopback", action="store_true"); s.add_argument("--artifacts", type=int)
    s.add_argument("--tokens", nargs="*"); s.set_defaults(func=cmd_metric)

    s = sub.add_parser("show"); s.add_argument("path"); s.set_defaults(func=cmd_show)

    args = p.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
