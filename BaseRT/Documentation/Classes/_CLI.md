# _CLI

Internal command-line adapter, extended by [`_BaseRT`](_BaseRT.md).

> _CLI.new(executableName : Text; controller : 4D.Class)

On macOS, initializes the command name and a temporary working directory.
It does not look in `/RESOURCES/bin`, select a cached runtime or change permissions.
The application adapter requires an explicit external `executable` or
`source_runtime` selection; there is no automatic `PATH` fallback.
Windows returns before controller creation and is unsupported.
`_isArm()` is a processor-name helper; the constructor does not enforce it.

Read-only properties expose `name`, `EOL`, `executableName`, `platform`,
`currentDirectory`, `executablePath`, `executableFile`, and `controller`.

| Method | Purpose |
| --- | --- |
| `escape(text)` | Escapes shell metacharacters for the platform |
| `expand(fileOrFolder)` | Recreates the object using its platform path |
| `quote(text)` | Wraps text in double quotes |
| `_isArm()` | Tests processor name against known ARM-family terms |

[`_CLI_Controller`](_CLI_Controller.md) owns the `4D.SystemWorker`.
