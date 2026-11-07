#!/usr/bin/env python3
"""Compile each case with and without power-up values, run circt-bmc, compare."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parent.parent
PASS = "PASS"
FAIL = "FAIL"
ERROR = "ERROR"


def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(2)


def resolve_circt(explicit: Optional[str]) -> Path:
    candidates = [
        explicit,
        os.environ.get("CIRCT_BIN"),
        str(ROOT / ".tools" / "circt" / "bin"),
    ]
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate).expanduser()
        if (path / "circt-verilog").is_file() and (path / "circt-bmc").is_file():
            return path

    verilog = shutil.which("circt-verilog")
    bmc = shutil.which("circt-bmc")
    if verilog and bmc:
        return Path(verilog).resolve().parent

    die(
        "could not find circt-verilog and circt-bmc.\n"
        "       set CIRCT_BIN to the directory containing both, or add it to PATH.\n"
        "       prebuilt releases: https://github.com/llvm/circt/releases\n"
        "       example: export CIRCT_BIN=/path/to/circt/bin\n"
        "       or extract a release under .tools/circt so .tools/circt/bin exists."
    )


def resolve_z3(explicit: Optional[str]) -> Path:
    candidates = [explicit, os.environ.get("Z3_LIB")]

    brew = shutil.which("brew")
    if brew:
        try:
            prefix = subprocess.run(
                [brew, "--prefix", "z3"],
                check=True,
                capture_output=True,
                text=True,
                timeout=10,
            ).stdout.strip()
            if prefix:
                candidates.append(str(Path(prefix) / "lib" / "libz3.dylib"))
                candidates.append(str(Path(prefix) / "lib" / "libz3.so"))
        except (subprocess.SubprocessError, OSError):
            pass

    candidates += [
        "/opt/homebrew/lib/libz3.dylib",
        "/usr/local/lib/libz3.dylib",
        "/usr/lib/libz3.so",
        "/usr/lib/x86_64-linux-gnu/libz3.so",
        "/usr/lib/aarch64-linux-gnu/libz3.so",
    ]

    from ctypes.util import find_library

    found = find_library("z3")
    if found:
        candidates.append(found)

    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate).expanduser()
        if path.is_file():
            return path

    die(
        "could not find the Z3 shared library.\n"
        "       set Z3_LIB to libz3.dylib or libz3.so, or pass --z3-lib.\n"
        "       macOS: brew install z3   Debian/Ubuntu: apt install libz3-dev"
    )


def run(cmd: List[str], timeout: int) -> Tuple[int, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return 124, f"timed out after {timeout}s: {' '.join(cmd)}"
    except OSError as exc:
        return 127, f"could not run {cmd[0]}: {exc}"
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def run_mode(
    case: Dict[str, Any],
    mode: str,
    circt_bin: Path,
    z3_lib: Path,
    build_dir: Path,
    bound: int,
    timeout: int,
) -> Tuple[str, str]:
    module = case["name"]
    source = ROOT / case["file"]
    output = build_dir / module / f"{mode}.mlir"
    output.parent.mkdir(parents=True, exist_ok=True)

    compile_cmd = [
        str(circt_bin / "circt-verilog"),
        "--ir-hw",
        f"--top={module}",
        "-I",
        str(ROOT / "rtl"),
    ]
    if mode == "noinit":
        compile_cmd.append("-DNO_INIT")
    compile_cmd += [
        str(ROOT / "rtl" / "por_reset.sv"),
        str(source),
        "-o",
        str(output),
    ]

    code, text = run(compile_cmd, timeout)
    if code != 0:
        return ERROR, f"circt-verilog failed:\n{text}"

    bmc_cmd = [
        str(circt_bin / "circt-bmc"),
        "-b",
        str(bound),
        f"--module={module}",
        "--run",
        f"--shared-libs={z3_lib}",
        str(output),
    ]
    code, text = run(bmc_cmd, timeout)

    if "Bound reached with no violations!" in text:
        return PASS, text
    if "Assertion can be violated!" in text:
        return FAIL, text
    return ERROR, f"circt-bmc did not report a verdict (exit {code}):\n{text}"


def print_table(rows: List[List[str]], headers: List[str]) -> None:
    widths = [
        max(len(str(row[index])) for row in [headers] + rows)
        for index in range(len(headers))
    ]
    print("  ".join(header.ljust(width) for header, width in zip(headers, widths)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        print("  ".join(str(cell).ljust(width) for cell, width in zip(row, widths)))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run coldstart's init / no-init bounded model checks."
    )
    parser.add_argument("--case", help="run one case (see --list)")
    parser.add_argument("--circt-bin", help="directory containing circt-verilog and circt-bmc")
    parser.add_argument("--z3-lib", help="path to libz3.dylib or libz3.so")
    parser.add_argument("--bound", type=int, help="override the cycle bound from cases.json")
    parser.add_argument("--timeout", type=int, default=120, help="per-command timeout in seconds")
    parser.add_argument("--list", action="store_true", help="list cases and exit")
    parser.add_argument(
        "--show-cex",
        action="store_true",
        help="print the no-init counterexample for failing cases",
    )
    args = parser.parse_args()

    manifest = json.loads((ROOT / "cases.json").read_text())
    cases = manifest["cases"]

    if args.case:
        cases = [case for case in cases if case["name"] == args.case]
        if not cases:
            die(f"unknown case '{args.case}' (try --list)")

    if args.list:
        for case in cases:
            print(f"{case['name']:<20} {case['class']:<16} {case['property']}")
        return 0

    circt_bin = resolve_circt(args.circt_bin)
    z3_lib = resolve_z3(args.z3_lib)

    rows: List[List[str]] = []
    details: List[Dict[str, Any]] = []
    mismatches = 0

    for case in cases:
        bound = args.bound or case.get("bound") or manifest.get("bound", 12)

        init, init_out = run_mode(case, "init", circt_bin, z3_lib, ROOT / "build", bound, args.timeout)
        noinit, noinit_out = run_mode(case, "noinit", circt_bin, z3_lib, ROOT / "build", bound, args.timeout)

        fixed = case.get("fixed")
        if fixed:
            f_init, f_init_out = run_mode(fixed, "init", circt_bin, z3_lib, ROOT / "build", bound, args.timeout)
            f_noinit, f_noinit_out = run_mode(fixed, "noinit", circt_bin, z3_lib, ROOT / "build", bound, args.timeout)
        else:
            f_init = f_noinit = "-"
            f_init_out = f_noinit_out = ""

        expected = case["expect"]
        ok = init == expected["init"] and noinit == expected["noinit"]
        if fixed:
            fixed_expected = fixed["expect"]
            ok = ok and f_init == fixed_expected["init"] and f_noinit == fixed_expected["noinit"]

        if ERROR in (init, noinit, f_init, f_noinit):
            ok = False
        if not ok:
            mismatches += 1

        rows.append([case["name"], case["class"], init, noinit, f_init, f_noinit, "ok" if ok else "MISMATCH"])
        details.append(
            {
                "case": case,
                "init": init,
                "noinit": noinit,
                "init_out": init_out,
                "noinit_out": noinit_out,
                "fixed": fixed,
                "f_init": f_init,
                "f_noinit": f_noinit,
                "f_init_out": f_init_out,
                "f_noinit_out": f_noinit_out,
            }
        )

    print()
    print(f"coldstart: {len(cases)} case(s), bound {args.bound or manifest.get('bound', 12)}")
    print(f"circt:     {circt_bin}")
    print(f"z3:        {z3_lib}")
    print()
    print_table(rows, ["design", "class", "init", "no-init", "fixed-init", "fixed-no-init", "status"])

    if mismatches:
        print()
        for detail in details:
            case = detail["case"]
            expected = case["expect"]
            if detail["init"] != expected["init"]:
                print(f"  {case['name']}: init expected {expected['init']}, got {detail['init']}", file=sys.stderr)
            if detail["noinit"] != expected["noinit"]:
                print(f"  {case['name']}: no-init expected {expected['noinit']}, got {detail['noinit']}", file=sys.stderr)
            fixed = detail["fixed"]
            if fixed:
                fixed_expected = fixed["expect"]
                if detail["f_init"] != fixed_expected["init"]:
                    print(f"  {fixed['name']}: init expected {fixed_expected['init']}, got {detail['f_init']}", file=sys.stderr)
                if detail["f_noinit"] != fixed_expected["noinit"]:
                    print(f"  {fixed['name']}: no-init expected {fixed_expected['noinit']}, got {detail['f_noinit']}", file=sys.stderr)

    if args.show_cex:
        for detail in details:
            for verdict_key, output_key, label in (
                ("init", "init_out", "init"),
                ("noinit", "noinit_out", "no-init"),
                ("f_init", "f_init_out", "fixed init"),
                ("f_noinit", "f_noinit_out", "fixed no-init"),
            ):
                if detail[verdict_key] == FAIL:
                    print(f"\n--- {detail['case']['name']} ({label}) ---")
                    print(detail[output_key])
                elif detail[verdict_key] == ERROR:
                    print(f"\n--- {detail['case']['name']} ({label}) error ---")
                    print(detail[output_key])

    if mismatches:
        print(f"\n{mismatches} case(s) did not match cases.json", file=sys.stderr)
        return 1

    print("\nall cases match cases.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
