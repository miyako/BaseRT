# BaseRT for 4D

Manage a local [BaseRT](https://github.com/basecompute/baseRT) inference server
from a 4D application: resolve model downloads, construct CLI arguments,
launch a background worker, and stop it on exit.

[Documentation](https://miyako.github.io/BaseRT/) ·
[Class reference](BaseRT/Documentation/Classes/BaseRT.md) ·
[Upstream](https://github.com/basecompute/baseRT) ·
[Releases](https://github.com/miyako/BaseRT/releases)

## What is built from source?

As verified on **2026-11-02**, upstream `main` and latest release **v0.4.3**
resolve to [`e704113597cdfb98c7a925a0968a339dec7bdab1`](https://github.com/basecompute/baseRT/commit/e704113597cdfb98c7a925a0968a339dec7bdab1),
dated **2026-10-29 UTC**. The public Rust source builds the **`basert` launcher
and converter**, not the proprietary inference engine.

The current `basert serve` command delegates to **Superfluid**. This repository
builds the launcher, the tested Superfluid **v0.1.6**
([`b421ef5c0474d786ea46ab4a410088d625699694`](https://github.com/basecompute/superfluid/tree/b421ef5c0474d786ea46ab4a410088d625699694)),
its process helpers, and the BaseRT worker from source. **Inference still requires
a separately obtained, compatible, licensed `libbaseRT` engine and its Metal libraries.**
There is no full engine source build in the public upstream repository.

The proprietary legacy runtime has been removed from the current tree. No
inference executable, engine dylib or Metal kernels are bundled. The separate
open-source `basert` launcher is retained, but is not an inference engine or a
replacement for `basert-serve`. Source builds are isolated under ignored `.build/`;
selecting a runtime is explicit.

## Requirements and supported platforms

| Target | Status |
| --- | --- |
| Apple Silicon macOS | Supported component target. New source tooling targets **macOS 15+**, ARM64. |
| Intel macOS, Windows | Unsupported; no working engine/component builds provided. |
| Linux ARM64 / NVIDIA GB10 (DGX Spark) | Supported by upstream engine, **not by this macOS 4D adapter/build script**. |
| Linux x86_64, CPU-only, AMD GPU | No verified upstream BaseRT engine support. |

The package's existing 4D build target is **20.7 ARM**. Source dependency
resolution uses the `dependencies.json` format marked `2100`; use **4D 21+**
for that workflow. Install the declared
[`tcp`, `workers`, and `event`](BaseRT/Project/Sources/dependencies.json)
components. Compatibility of the complete component on each 4D release must
be checked in the host application.

For native builds: Git, Python 3.9+, Xcode Command Line Tools, and
**Rust 1.99.0** via rustup. Older Rust 1.91/1.93 cannot compile the pinned
Superfluid's atomic API despite upstream's lower declared minimum.
The upstream engine advertises macOS 14+, but the
source-built server packaging here conservatively targets macOS 15.0.
Model format/architecture and unified-memory requirements are upstream-specific:
use compatible **`.base`** weights, not llama.cpp GGUF models.

## Installation and source build

1. Use the current source component under `BaseRT/Project` and resolve its
   component dependencies. Existing release tags/ZIP/DMG files predate the
   runtime removal; do not treat them as wrapper-only distributions.
2. Obtain the BaseRT engine separately from
   [upstream v0.4.3](https://github.com/basecompute/baseRT/releases/tag/v0.4.3),
   review its license, and retain its matching libraries, Metal files, LICENSE
   and NOTICE together. This repository does **not** download or redistribute it.
3. Build the public native tooling:

   ```sh
   rustup toolchain install 1.99.0 --profile minimal
   python3 scripts/build-native.py
   ```

4. Set `source_runtime` and `engine_dir` in the 4D options below. Alternatively,
   for an independently obtained, compatible legacy server installation, set
   `executable: File("/absolute/path/to/licensed/runtime/basert-serve")` instead
   of `source_runtime`. Keep its matching libraries, Metal files and notices
   alongside it, outside this repository/component, and make it executable
   during your own installation. The adapter does not change installed files
   or permissions. It never searches `/RESOURCES/bin` or `PATH`.

Selecting neither runtime, both selectors, a malformed selector or a missing
executable reports `onError(options, error)` with code **3** before worker launch.
The message explains how to install/select the missing runtime; no engine is
automatically fetched. File existence is not executable, architecture, version
or ABI verification. Check compatibility and licensing for your installation.

Build output is `.build/runtime/`. It contains a compatibility `basert-serve`
shell entry point that executes the source-built **`basert serve`**, plus the
source-built Superfluid server/worker, upstream notices and `build-info.json`.
No engine or legacy companion tools are copied into it.
The metadata records exact Git revisions, Cargo lockfile and output hashes,
Rust/Cargo, Xcode/SDK, deployment target and host macOS.

```sh
python3 scripts/build-native.py --force          # clean both Cargo workspaces
python3 scripts/build-native.py --offline        # existing sources/cache only
python3 scripts/build-native.py --jobs 4          # bound build parallelism
python3 scripts/smoke-native.py .build/runtime   # no engine/model downloads
python3 -m unittest discover -s tests -p 'test_*.py'
```

Pins are maintained in [`native-sources.json`](native-sources.json). To update,
verify upstream `main`, latest release, tested Superfluid/engine compatibility
and licenses; update full SHAs/versions/toolchain deliberately, then rebuild.
Do not use a floating “latest” engine or silently replace the source-built CLI
with the prebuilt `basert` inside an engine archive. A locked build is traceable,
not a claim of byte-for-byte identical output across different SDKs/hosts.

For adapter regression checks with a local 4D 21+ utility runtime:

```sh
python3 scripts/test-4d.py --tool4d /path/to/tool4d.app/Contents/MacOS/tool4d
python3 scripts/test-4d-native.py --tool4d /path/to/tool4d.app/Contents/MacOS/tool4d
```

The first suite runs command construction, local-model dispatch and deterministic
download scheduling against controlled event/worker components. It covers inline
cache hits, distinct destinations sharing a provider object ID, duplicate,
failed, cancelled and stale completions. It also runs compiler syntax-only
checking of its fixture, including the public constructor and TCP dispatcher.
The native suite uses the production controller and harmless OS children for
stream routing, callback identities and worker reuse. Native-shaped error
translation and an error-without-response lifecycle are explicitly controlled
probes, not observed OS error callbacks. On tool4d 21 R4.100208, a nonexistent
executable throws before callbacks; Blob stderr events are empty text while
`responseError` retains the bytes. These limitations are reported, not hidden.
Add `--check-logs` to the native command on macOS to verify exactly one fallback
diagnostic and none for a subscribed error, using a narrowly filtered live log.
Neither suite loads an engine or replaces resolved-component, host-application,
older 20.7-target compatibility or inference testing.

## Quick start

Use an existing, compatible local `.base` file. In the host application's startup
code, replace these absolute paths with your own:

```4d
var $home : 4D.Folder
$home:=Folder(fk home folder).folder(".BaseRT")
$home.create()

var $event : cs.event.event
$event:=cs.event.event.new()
$event.onError:=Formula(ALERT($2.message))
$event.onTerminate:=Formula(LOG EVENT(Into 4D debug message; "BaseRT exited"))

var $options : Object
$options:={\
  model: $home.file("Qwen3.5-2B-Q8.base"); \
  source_runtime: Folder("/absolute/path/to/BaseRT/.build/runtime"); \
  engine_dir: Folder("/absolute/path/to/licensed/engine"); \
  max_tokens: 4096; max_context: 8192}

var $BaseRT : cs.BaseRT.BaseRT
$BaseRT:=cs.BaseRT.BaseRT.new(8080; Null; $home; $options; $event)
```

Alternatively, supply `cs.event.huggingfaces` references to download missing
models; see the [class example](BaseRT/Documentation/Classes/BaseRT.md).
Review the model provider's license independently.

In the host application's `onExit`:

```4d
var $BaseRT : cs.BaseRT.BaseRT
$BaseRT:=cs.BaseRT.BaseRT.new()
$BaseRT.terminate()
```

### Options and lifecycle

The adapter passes the first model positionally and additional model files as
repeated `--model` arguments. Other keys translate from `snake_case` into
`--kebab-case`; true booleans emit flags. `source_runtime` and `engine_dir`
are adapter-only `4D.Folder` options; `executable` is an adapter-only `4D.File`.
None are CLI flags. An external executable uses its parent as working directory.
The source-runtime wrapper fixes `BASERT_SUPERFLUID_DIR` and disables automatic
Superfluid installation/update checks, and explicitly selects the staged
`SUPERFLUID_WORKER_BASERT`; the adapter sets `BASERT_LIB` to `engine_dir`.
The engine must expose the ABI required by Superfluid; a matching filename
alone does not establish compatibility. The removed legacy engine was previously
probed and lacks `baseRT_load_tokenizer_only`, so it cannot serve with the new
source runtime. Obtain a compatible licensed engine separately; do not copy
the old dylib into the new stage.

Check `.build/runtime/basert-serve --help` for actual server options. Current
upstream defaults to port **8453**; this 4D adapter explicitly supplies **8080**
unless a different valid port is passed. Do not copy llama.cpp flags such as
`ctx_size`, `n_gpu_layers`, `jinja`, `models_dir`, or `models_preset`.
The legacy router branches are not supported BaseRT features.

`onData`/`onResponse` describe model downloads. `onStdOut`/`onStdErr` receive
native process output as `(worker, event)`, with `This` set to the controller;
stderr is not automatically a fatal error. `onError(options, error)` reports
preflight, selection, download or native execution failures. Native execution
errors use code **4**, retain diagnostics in `error.native` (`pid`, `errors`,
`event`), and use the controller receiver. Other error receivers are unchanged.
This is not a raw alias of SystemWorker's differently shaped `onError`.
Without a callable native-error subscriber, diagnostics are logged; the
pinned event class's empty default handler is not treated as a subscription.
`onTerminate` reports process exit, including ordinary nonzero exits.
**`onSuccess` currently means launch requested, not HTTP/model readiness.**
It can be followed by a later native execution error or termination.
Check the selected runtime's diagnostics/protocol and verify that responses
belong to your process/model before sending requests. `/v1/models` can list
unloaded models and is not, alone, proof of model readiness or inference.
Superfluid provides an OpenAI-style `/v1/chat/completions` endpoint; use the
model ID actually returned by `/v1/models`. Configure `api_key` for access
beyond a trusted local application.

Downloads are tracked per destination and startup attempt, not just provider
object ID. All required files must complete before one launch request. Failed,
cancelled, duplicate or superseded completions cannot launch an old attempt.
`terminate()` also cancels pending startup/TCP/download attempts, then requests
termination of all registered workers. Cleanup is serialized on the startup
worker; callers outside startup/native-worker callbacks wait up to 10 seconds
for that request, with an explicit diagnostic on timeout. A start requested
during cleanup is cancelled; retry after termination completes. This prevents
late startup, but does not abort HTTP transfers/file writes or progress callbacks
owned by the external download component. Cache reuse remains size-only on
`main`; no model pinning, checksum policy or cache migration is introduced.

## Automation, Pages, and licensing

- [`build-native.yml`](.github/workflows/build-native.yml) builds pinned open
  tooling and uploads a source-only artifact, with CLI help/version checks.
  It does not publish releases or include the engine.
- [`publish.yml`](.github/workflows/publish.yml) is **unconditionally blocked**,
  for automatic and manual runs. Its legacy 4D packaging/signing/release steps
  have no approved wrapper-only packaging contract. No acknowledgment can bypass
  the gate. Source/tooling builds remain usable; enabling a future release
  pipeline requires a separate reviewed wrapper-only packaging change.
- [`check-distribution.yml`](.github/workflows/check-distribution.yml) rejects
  engine filenames, opaque archives, symlinks and unreviewed native payloads.
  Run `python3 scripts/check-distribution.py` before making a source package.
  It checks tracked files and the entire component tree, including ignored/stale
  files. Only the existing open-source `basert` launcher and unrelated 4D bridge
  `Libraries/lib4d-arm64.dylib` are retained as byte-pinned native exceptions;
  that allowlist is not a new license or a provenance claim.
  `.gitignore` also excludes known engine assets. Do not copy a licensed
  installation into this repository, use `git add -f`, or archive `.build/`
  or a user installation for publication. Native tooling artifacts are staged
  separately and checked for engine assets and unrecorded cached files.
- [`pages.yml`](.github/workflows/pages.yml) validates and deploys the custom
  static [`docs/`](docs/) site on `main`; pull requests only validate/upload.
  Enable **Settings → Pages → Source: GitHub Actions** manually. No repository
  setting is changed by this patch. Preview with
  `python3 -m http.server 8000 --directory docs`; check links with
  `python3 scripts/check-docs.py`. No Jekyll/theme/README-as-homepage build is used.

The wrapper and public launcher/server source use **Apache-2.0**; retain their
licenses and notices. This does **not** relicense binary assets.
[`BaseRT/third party/LICENSE`](BaseRT/third%20party/LICENSE) is retained as the
license record for the removed legacy engine. It explicitly covers
`libbaseRT`, Metal kernels and `basert-*` runtime executables, restricts
redistribution/third-party hosting, and distinguishes the open-source `basert`
launcher. Removed paths under `BaseRT/Resources/bin/macOS/` are:
`basert-bench`, `basert-chat`, `basert-complete`, `basert-inspect`,
`basert-serve`, `basert-transcribe`, `libbaseRT.dylib`, `baseRT.metallib`
and `baseRT_tensor.metallib`.

This is a current-tree removal, **not a history or release purge**. Historical
Git objects/tags (including `20.0.3`) still contain those files; existing
`20.0.1`–`20.0.3` releases have ZIP/DMG assets that need a separate distribution
review. Those release assets were not downloaded, inspected or changed here.
The current upstream engine also has separate proprietary terms; obtain it
independently and review those terms before use. An acknowledgment does not
grant redistribution rights. Model weights and other dependencies have their
own terms.
