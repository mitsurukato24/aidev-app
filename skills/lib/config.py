#!/usr/bin/env python3
"""AIDD のプロジェクト設定 `.claude/config.json` の読取りヘルパ（py/bash 共用）。

スクリプト（status.py / run-checks.sh など）はスタックを直書きせず、本ヘルパ経由で
config を読んでプロジェクトに沿って動く。stdlib のみ（依存なし）。

Python から:
    from config import load_config, repo_root, get
    cfg = load_config(); gate = get(cfg, "components")

bash から（CLI）:
    python3 .claude/skills/lib/config.py root                 # リポジトリ root の絶対パス
    python3 .claude/skills/lib/config.py get vcs.default_branch
    python3 .claude/skills/lib/config.py get project.codename
    python3 .claude/skills/lib/config.py checks               # run-checks.sh 用の TSV（1 check/行）
    python3 .claude/skills/lib/config.py components           # component 名を改行区切り

`get` は dotted パス（例 vcs.default_branch）。値が dict/list なら JSON で出力。
`checks` の TSV 列: component<TAB>path<TAB>label<TAB>cwd<TAB>cmd<TAB>coverage_gate<TAB>env_unset(カンマ)
"""
from __future__ import annotations

import json
import os
import sys

CONFIG_REL = os.path.join(".claude", "config.json")


def repo_root(start: str | None = None) -> str:
    """`.claude/config.json` を持つ最も近い祖先ディレクトリを返す（worktree 対応）。"""
    here = os.path.abspath(start or __file__)
    if os.path.isfile(here):
        here = os.path.dirname(here)
    cur = here
    while True:
        if os.path.isfile(os.path.join(cur, CONFIG_REL)):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent
    # 見つからなければ lib から 3 つ上（.claude/skills/lib → root）にフォールバック
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def config_path(start: str | None = None) -> str:
    return os.path.join(repo_root(start), CONFIG_REL)


def load_config(start: str | None = None) -> dict:
    path = config_path(start)
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        return {}
    except Exception as exc:  # noqa: BLE001
        sys.exit(f"config.json を読めません: {exc}")


def get(cfg: dict, dotted: str, default=None):
    cur = cfg
    for part in dotted.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return default
    return cur


def _emit_checks(cfg: dict) -> None:
    for comp in cfg.get("components", []):
        name = comp.get("name", "")
        path = comp.get("path", "")
        for chk in comp.get("checks", []):
            row = [
                name,
                path,
                chk.get("label", ""),
                chk.get("cwd", ""),
                chk.get("cmd", ""),
                str(chk.get("coverage_gate", "")),
                ",".join(chk.get("env_unset", []) or []),
            ]
            print("\t".join(row))


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 0
    cmd = argv[0]
    cfg = load_config()
    if cmd == "root":
        print(repo_root())
    elif cmd == "get":
        if len(argv) < 2:
            sys.exit("get には dotted キーが必要です")
        val = get(cfg, argv[1])
        if isinstance(val, (dict, list)):
            print(json.dumps(val, ensure_ascii=False))
        elif val is None:
            print("")
        else:
            print(val)
    elif cmd == "checks":
        _emit_checks(cfg)
    elif cmd == "components":
        for comp in cfg.get("components", []):
            print(comp.get("name", ""))
    else:
        sys.exit(f"未知のサブコマンド: {cmd}（root|get|checks|components）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
