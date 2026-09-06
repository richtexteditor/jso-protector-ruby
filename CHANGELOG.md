# Change Log

## 0.1.0 — 2026-05-19

Initial release.

- `JsoProtector.protect(files:, preset:, ...)` Ruby gem mirroring the Node/Python/Go/.NET clients.
- Three presets: `standard`, `balanced`, `maximum`.
- `JsoProtector::Result` with `files`, `build_id`, `polymorphism_fingerprint`, `report`, `raw`.
- `JsoProtector::Error` with `type` and `error_code` attributes; messages are safe to log.
- Env-var-first credentials: reads `JSO_API_KEY` / `JSO_API_PASSWORD` (or the long-form names) before falling back to keyword arguments.
- Pure stdlib (`net/http` + `json`), no third-party dependency.
- Eight Minitest unit tests covering label propagation, options override, env fallback, missing creds, unknown preset, empty files, error mapping, preset table integrity.
