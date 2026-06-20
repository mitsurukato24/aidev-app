#!/usr/bin/env python3
"""Skill の自動評価ランナー — 作業忠実度のデグレ確認・精度評価。

各 Skill は `<skill>/eval/spec.json` に評価仕様を宣言する。Skill（SKILL.md / agent /
スクリプト）を修正したら本ランナーを回し、必須要素の欠落（デグレ）やスクリプトの精度低下を検出する。

spec.json:
{
  "skill": "<name>",
  "description": "...",
  "contracts": [            # SKILL.md / agent 等のテキスト契約（必須記載が消えていないか）
    {"file": "SKILL.md",
     "must_contain": ["run-checks.sh", "必須チェックリスト"],
     "must_not_contain": ["pytest tests/"]}
  ],
  "commands": [             # スクリプトの挙動・精度（fixture 入出力）
    {"name": "good passes",
     "cmd": ["python3", "scripts/validate-lesson.py", "eval/fixtures/good.json"],
     "expect_exit": 0, "expect_stdout_contains": ["PASS"]}
  ]
}
パスは各 skill ディレクトリ基準（cmd の実行 cwd も skill ディレクトリ）。

使い方:
  eval_runner.py            # 全 Skill
  eval_runner.py <skill>    # 1 Skill（例: content-gen）
終了コード: 全合格 0 / 1 件でも失敗 1。
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

SKILLS_DIR = os.path.abspath(os.path.dirname(__file__))


def _read(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return None


def run_contract(skill_dir: str, c: dict) -> list[str]:
    errs: list[str] = []
    path = os.path.join(skill_dir, c["file"])
    text = _read(path)
    if text is None:
        return [f"contract: ファイルが無い {c['file']}"]
    for s in c.get("must_contain", []):
        if s not in text:
            errs.append(f"contract: {c['file']} に必須文字列が無い: {s!r}")
    for s in c.get("must_not_contain", []):
        if s in text:
            errs.append(f"contract: {c['file']} に禁止文字列がある: {s!r}")
    return errs


def run_command(skill_dir: str, c: dict) -> list[str]:
    errs: list[str] = []
    try:
        proc = subprocess.run(c["cmd"], cwd=skill_dir, capture_output=True,
                              text=True, timeout=c.get("timeout", 120))
    except Exception as exc:  # noqa: BLE001
        return [f"command[{c.get('name')}]: 実行失敗 {exc}"]
    out = (proc.stdout or "") + (proc.stderr or "")
    if "expect_exit" in c and proc.returncode != c["expect_exit"]:
        errs.append(f"command[{c.get('name')}]: exit {proc.returncode} != {c['expect_exit']}")
    for s in c.get("expect_stdout_contains", []):
        if s not in out:
            errs.append(f"command[{c.get('name')}]: 出力に {s!r} が無い")
    for s in c.get("expect_stdout_not_contains", []):
        if s in out:
            errs.append(f"command[{c.get('name')}]: 出力に {s!r} が含まれる")
    return errs


def eval_skill(skill: str) -> tuple[int, int, list[str]]:
    skill_dir = os.path.join(SKILLS_DIR, skill)
    spec_path = os.path.join(skill_dir, "eval", "spec.json")
    spec_text = _read(spec_path)
    if spec_text is None:
        return 0, 0, [f"{skill}: eval/spec.json が無い"]
    try:
        spec = json.loads(spec_text)
    except json.JSONDecodeError as exc:
        return 0, 1, [f"{skill}: spec.json が壊れている {exc}"]
    errs: list[str] = []
    checks = 0
    for c in spec.get("contracts", []):
        checks += 1
        errs += run_contract(skill_dir, c)
    for c in spec.get("commands", []):
        checks += 1
        errs += run_command(skill_dir, c)
    failed = len(errs)
    return checks, failed, errs


def main(argv: list[str]) -> int:
    if argv:
        skills = argv
    else:
        skills = sorted(
            d for d in os.listdir(SKILLS_DIR)
            if os.path.isfile(os.path.join(SKILLS_DIR, d, "eval", "spec.json"))
        )
    total_fail = 0
    for skill in skills:
        checks, failed, errs = eval_skill(skill)
        status = "PASS" if failed == 0 and not (checks == 0 and errs) else "FAIL"
        if errs and checks == 0:
            status = "SKIP" if "が無い" in errs[0] else "FAIL"
        print(f"[{status}] {skill}  ({checks} checks)")
        for e in errs:
            print(f"    - {e}")
        total_fail += failed + (1 if status == "FAIL" and not failed else 0)
    print("RESULT:", "PASS" if total_fail == 0 else "FAIL")
    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
