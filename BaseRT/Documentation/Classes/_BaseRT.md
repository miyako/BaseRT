# _BaseRT

Extends [`_CLI`](_CLI.md) with the executable name `basert-serve`.

> _BaseRT.new(class : 4D.Class)

The optional controller class must inherit from
[`_BaseRT_Controller`](_BaseRT_Controller.md); otherwise the default is used.
There is no command-name mapping to other BaseRT executables.

| Member | Purpose |
| --- | --- |
| `port : Integer` | Server port |
| `onData`, `onDataError`, `onTerminate : 4D.Function` | Process callbacks |
| `bind(option; properties)` | Copies named properties from an options object |
| `worker : 4D.SystemWorker` | Current controller worker |
| `terminate()` | Delegates to controller termination |

[`_server`](_server.md) specializes this class for server arguments.
