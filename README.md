# jso_protector — Ruby client

Ruby gem for the [JavaScript Obfuscator](https://javascriptobfuscator.com/) HTTP API. Mirrors the `protect()` surface of the [npm `jso-protector` CLI](https://javascriptobfuscator.com/docs/npmcli.aspx), the [Python](../jso-protector-python/), [Go](../jso-protector-go/), and [.NET](../jso-protector-dotnet/) clients so behavior stays in lockstep across runtimes.

Pure stdlib — uses `net/http` and `json`. No third-party dependency.

## Install

```bash
gem install jso_protector
```

Or, in a Gemfile:

```ruby
gem "jso_protector"
```

## Quick start

```ruby
require "jso_protector"

result = JsoProtector.protect(
  files: { "app.js" => File.read("dist/app.js") },
  preset: "balanced",
  label: ENV["GIT_COMMIT"],
  # api_key/api_password default to JSO_API_KEY/JSO_API_PASSWORD env vars.
)

result.files.each { |name, code| File.write("dist-protected/#{name}", code) }
puts "BuildId: #{result.build_id}"
puts "Fingerprint: #{result.polymorphism_fingerprint}"
```

## Credentials

Reads `JSO_API_KEY` / `JSO_API_PASSWORD` (or the long-form `JAVASCRIPT_OBFUSCATOR_API_KEY` / `JAVASCRIPT_OBFUSCATOR_API_PASSWORD`) from the environment before falling back to the keyword arguments. Use env vars on shared / CI machines.

## Presets

| Preset | Notes |
|---|---|
| `standard` | Core string encoding, string-array move, name mangling, compression. |
| `balanced` | Adds string encryption, deep obfuscation, flat transform, code transposition. |
| `maximum` | Adds member rename, global rename, member move, dead-code insertion. |

For fine-grained control pass `options: {...}` with Pascal-case keys exactly as the [HTTP API](https://javascriptobfuscator.com/docs/) documents. Explicit options override preset defaults:

```ruby
result = JsoProtector.protect(
  files: { "app.js" => src },
  preset: "balanced",
  options: { "LockDate" => true, "LockDomain" => true, "LockDomainList" => "example.com" },
)
```

## Result

`JsoProtector::Result` exposes:

| Method | Type | Notes |
|---|---|---|
| `files` | `Hash{String => String}` | Protected source by input filename. |
| `build_id` | `String, nil` | Stable identifier for this run. |
| `polymorphism_fingerprint` | `String, nil` | Short fingerprint over the protected output. |
| `report` | `Hash` | Full Report — identifier maps, enabled options, compatibility findings, release metadata. |
| `raw` | `Hash` | Complete decoded response body. |

## Error handling

```ruby
begin
  result = JsoProtector.protect(files: { "app.js" => src })
rescue JsoProtector::Error => e
  # e.message is safe to log — API key/password never interpolated.
  # e.type and e.error_code carry the API's Type/ErrorCode when present.
  warn "JSO protection failed: #{e.message} (type=#{e.type}, code=#{e.error_code})"
end
```

## Tests

```bash
ruby -Ilib -Itest test/test_jso_protector.rb
```

Uses Minitest + Net::HTTP.stub for offline mocking — no network calls.

## License

Free companion to the JSO service. An active JSO account is required to make API calls.
