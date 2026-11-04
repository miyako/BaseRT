#!/usr/bin/env python3
"""Run production native-process callbacks in real tool4d, without an engine or model.

Usage: python3 scripts/test-4d-native.py --tool4d /path/to/tool4d
Add --check-logs to require Console emission counts using a live stream filtered
to tool4d and this invocation's unique fixture token; stored logs are not scanned.

The only child is a generated, harmless shell script. All fixtures, cache and
scratch paths belong to a disposable .build directory. Native launch failures
are reported separately from the controlled onError routing check: some 4D
versions throw during SystemWorker.new before they can deliver callbacks.
Blob stderr is compared with a direct SystemWorker control: affected tool4d
versions deliver empty text events but preserve stderr in responseError. An
additional, explicitly controlled Blob event checks unchanged stderr routing.
A real timeout/reuse probe is separate from the controlled no-response onError
lifecycle probe, which reconstructs the controller's post-execute state.
"""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
CLASSES = ("_CLI", "_CLI_Controller", "_BaseRT", "_BaseRT_Controller", "_server")
CHILD = """#!/bin/sh
for arg do
    if [ "$arg" = "--native-timeout" ]; then
        exec /bin/sleep 5
    fi
done
printf 'native stdout\\n'
printf 'arg=<%s>\\n' "$@"
printf 'native stderr\\n' >&2
exit 7
"""


def load_result(path):
    if not path.is_file():
        raise SystemExit("Native 4D regression produced no result file.")
    try:
        result = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise SystemExit(f"Cannot read native 4D regression result: {error}") from error
    if not isinstance(result, dict) or not isinstance(result.get("errors"), list):
        raise SystemExit("Native 4D regression result is missing an explicit errors array.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d", required=True, type=Path,
                        help="installed tool4d executable (4D 21+); nothing is downloaded")
    parser.add_argument("--check-logs", action="store_true",
                        help="require one fallback and zero subscribed messages in a narrowly "
                             "filtered macOS Console stream (requires log-stream access)")
    args = parser.parse_args()
    tool4d = args.tool4d.expanduser().resolve()
    if not tool4d.is_file() or not os.access(tool4d, os.X_OK):
        parser.error(f"not an executable tool4d: {tool4d}")

    build = ROOT / ".build"
    build.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="4d-native-", dir=build) as directory:
        work = Path(directory)
        fixture = work / "fixture"
        shutil.copytree(ROOT / "tests/4d", fixture)
        shutil.copytree(ROOT / "tests/4d-native", fixture, dirs_exist_ok=True)
        classes = fixture / "Project/Sources/Classes"
        for name in CLASSES:
            shutil.copy2(ROOT / f"BaseRT/Project/Sources/Classes/{name}.4dm", classes)
        shutil.copy2(ROOT / "BaseRT/Project/Sources/Methods/_argNumber.4dm",
                     fixture / "Project/Sources/Methods")
        # This controlled-suite-only class needs _Model and _startup, neither of
        # which belongs to the native stream/process fixture.
        (classes / "LifecycleModels.4dm").unlink(missing_ok=True)
        (fixture / "Resources/bin/macOS").mkdir(parents=True, exist_ok=True)
        child = work / "native child.sh"
        child.write_text(CHILD)
        child.chmod(0o700)
        model = work / "model with spaces.base"
        model.write_text("Only a path argument; this is not a model.\n")
        scratch = work / "scratch"
        scratch.mkdir()
        result_path = work / "result.json"
        env = dict(os.environ, TMPDIR=str(scratch.resolve()) + "/")
        command = [
            str(tool4d), str(fixture / "Project/Smoke.4DProject"),
            "--skip-onstartup", "--startup-method=nativeSmoke", "--dataless",
            f"--user-param={result_path}",
        ]
        log_process = None
        if args.check_logs:
            log_process = subprocess.Popen(
                ["/usr/bin/log", "stream", "--style", "ndjson", "--level", "debug",
                 "--predicate", f'process == "tool4d" AND eventMessage CONTAINS "{work.name}"'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env,
            )
        started = datetime.now().astimezone().isoformat()
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True, env=env)
        try:
            stdout, stderr = process.communicate(timeout=120)
        except subprocess.TimeoutExpired as error:
            process.kill()
            process.communicate()
            raise SystemExit(f"Native 4D regression timed out after 120 seconds; "
                             f"pid={process.pid}, started={started}, command={command}") from error
        finally:
            if log_process is not None:
                log_process.terminate()
                log_stdout, log_stderr = log_process.communicate(timeout=10)
        ended = datetime.now().astimezone().isoformat()
        completed = subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
        engine = dict(pid=process.pid, started=started, ended=ended,
                      returnCode=completed.returncode, command=command)
        if completed.returncode or not result_path.exists():
            raise SystemExit(
                f"tool4d exited {completed.returncode}; "
                f"result file {'exists' if result_path.exists() else 'missing'}.\n"
                f"Engine invocation: {json.dumps(engine)}\n{completed.stdout}\n{completed.stderr}"
            )
        result = load_result(result_path)
        result["engine"] = engine
        if log_process is not None:
            messages = []
            for line in log_stdout.splitlines():
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if entry.get("processID") == process.pid:
                    messages.append(entry.get("eventMessage", ""))
            subscribed = sum(f"{work.name}-subscribed" in message for message in messages)
            fallback = sum(f"{work.name}-fallback" in message for message in messages)
            result["consoleLogs"] = dict(subscribed=subscribed, fallback=fallback,
                                         streamDiagnostics=log_stderr)
            if subscribed != 0 or fallback != 1:
                result["errors"].append("Console log probe expected zero subscribed and "
                                        f"one fallback message; got {result['consoleLogs']}")
        if result.get("fatal"):
            raise SystemExit("Native 4D regression failed:\n" + json.dumps(
                result, indent=2, ensure_ascii=False))

        # Python comparisons are byte/case-sensitive, unlike 4D's text equality.
        expected_stdout = f"native stdout\narg=<{model}>\narg=<--port>\narg=<8123>\n"
        expected_stderr = "native stderr\n"
        baseline = result["blobBaseline"]
        if (baseline["stdout"] != expected_stdout
                or baseline["responseError"] != expected_stderr
                or baseline["stderr"] not in ("", expected_stderr)):
            raise SystemExit(f"Unexpected raw SystemWorker Blob behavior: {baseline}")
        cases = result.get("cases", [])
        if [case["label"] for case in cases] != [
            "text", "blob", "absent-reset", "malformed", "callable-again"
        ]:
            raise SystemExit(f"Missing native test cases: {result}")
        for case in cases:
            stream_stderr = baseline["stderr"] if case["label"] == "blob" else expected_stderr
            if (case["stdout"] != expected_stdout or case["stderr"] != stream_stderr
                    or case["responseError"] != expected_stderr):
                raise SystemExit(f"Native payload changed: {case!r}")
            if case["callbacks"]:
                if (case["callbackStdout"] != expected_stdout
                        or case["callbackStderr"] != stream_stderr):
                    raise SystemExit(f"Callback payload changed: {case!r}")
            elif case["callbackStdout"] or case["callbackStderr"]:
                raise SystemExit(f"An absent/malformed callback ran: {case!r}")
            if case["exitCode"] != 7 or case["nativeErrors"] or case["terminations"] != 1:
                raise SystemExit(f"Native lifecycle changed: {case!r}")

        launch = result.get("launchError", {})
        if not launch.get("engineErrors") and launch.get("nativeErrors") != 1:
            raise SystemExit(f"Nonexistent executable produced no observable error: {launch}")
        if result.get("errors"):
            raise SystemExit("Native 4D assertions failed (exact Python payload checks "
                             "passed):\n" + json.dumps(result, indent=2, ensure_ascii=False))
        print("Native tool4d checks passed: production _BaseRT/_server, text and Blob "
              "stdout/stderr, exact callback identities, exit 7, one termination, "
              "absent/malformed/reset callbacks, and inherited custom controller.")
        print("Controlled native-shaped onError routing passed separately "
              "(code 4, original options, controller receiver, native metadata).")
        print("Controlled Blob stderr forwarding passed separately (real worker; "
              "synthetic event containing an actual 4D.Blob).")
        if not baseline["stderr"]:
            print("LIMIT: raw SystemWorker Blob mode emits empty-text stderr events "
                  "on this tool4d. Forwarded events match exactly; responseError "
                  "independently preserves the exact stderr payload.")
        print("Actual nonexistent-executable launch evidence: "
              + json.dumps(launch, ensure_ascii=False, sort_keys=True))
        print("Actual bounded timeout/reuse evidence: "
              + json.dumps(result["reuse"], ensure_ascii=False, sort_keys=True))
        print("Controlled no-response onError/reuse evidence (real worker; "
              "synthetic error/termination lifecycle): "
              + json.dumps(result["controlledReuse"], ensure_ascii=False, sort_keys=True))
        if args.check_logs:
            print("Console log probe passed: zero subscribed messages, one fallback; "
                  "subscribed callback receiver/worker/event identity preserved.")
        else:
            print("Log callback probe passed; Console emission counts require --check-logs.")
        print("Engine invocation: " + json.dumps(engine, ensure_ascii=False, sort_keys=True))
        if launch.get("engineErrors") and not launch.get("nativeErrors"):
            print("LIMIT: this tool4d raises before onError/onTerminate; the controlled "
                  "routing check is NOT evidence of a real OS launch-error callback.")
        print("No model, engine, download, or build was used.")


if __name__ == "__main__":
    main()
