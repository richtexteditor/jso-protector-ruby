# frozen_string_literal: true

# Ruby client for the JavaScript Obfuscator HTTP API.
#
# Mirrors the protect() surface of the jso-protector npm CLI, the Python /
# Go / .NET clients so behavior stays in lockstep across runtimes. Pure
# stdlib — uses net/http and json, no third-party dependency.
#
# Quick start:
#
#   require "jso_protector"
#
#   result = JsoProtector.protect(
#     files: { "app.js" => File.read("dist/app.js") },
#     preset: "balanced",
#     label: ENV["GIT_COMMIT"],
#   )
#   result.files.each { |name, code| File.write("dist-protected/#{name}", code) }
#   puts "BuildId: #{result.build_id}"
#   puts "Fingerprint: #{result.polymorphism_fingerprint}"

require "json"
require "net/http"
require "uri"

module JsoProtector
  VERSION = "0.1.0"
  DEFAULT_ENDPOINT = "https://javascriptobfuscator.com/HttpApi.ashx"

  PRESETS = {
    "standard" => {
      "Compress"             => true,
      "EncodeStrings"        => true,
      "MoveStringsIntoArray" => true,
      "NameMangling"         => true,
    }.freeze,
    "balanced" => {
      "Compress"             => true,
      "EncodeStrings"        => true,
      "EncryptStrings"       => true,
      "MoveStringsIntoArray" => true,
      "NameMangling"         => true,
      "DeepObfuscate"        => true,
      "FlatTransform"        => true,
      "CodeTransposition"    => true,
    }.freeze,
    "maximum" => {
      "Compress"             => true,
      "EncodeStrings"        => true,
      "EncryptStrings"       => true,
      "MoveStringsIntoArray" => true,
      "NameMangling"         => true,
      "DeepObfuscate"        => true,
      "FlatTransform"        => true,
      "CodeTransposition"    => true,
      "ProtectMembers"       => true,
      "RenameGlobals"        => true,
      "MoveMembers"          => true,
      "DeadCodeInsertion"    => true,
    }.freeze,
  }.freeze

  # Raised when the JSO API rejects a request or the response is malformed.
  # The message is safe to log — API key / password are never interpolated.
  class Error < StandardError
    attr_reader :type, :error_code

    def initialize(message, type: nil, error_code: nil)
      super(message)
      @type = type
      @error_code = error_code
    end
  end

  # Outcome of a successful protect call.
  class Result
    attr_accessor :files, :build_id, :polymorphism_fingerprint, :report, :raw

    def initialize
      @files = {}
      @report = {}
      @raw = {}
    end
  end

  # Send JavaScript files to the JSO HTTP API and return the protected output.
  #
  # @param files [Hash{String => String}] map of filename to source. Required.
  # @param preset [String] one of "standard", "balanced", "maximum". Default "balanced".
  # @param options [Hash{String => Object}, nil] Pascal-case options overriding preset defaults.
  # @param label [String, nil] release label tagged as ReleaseLabel on the request.
  # @param api_key [String, nil] base64 API key; defaults to JSO_API_KEY env var.
  # @param api_password [String, nil] base64 API password; defaults to JSO_API_PASSWORD env var.
  # @param project_name [String] audit-log project name. Default "ruby-session".
  # @param endpoint [String] API endpoint. Default DEFAULT_ENDPOINT.
  # @param timeout [Numeric] read timeout in seconds. Default 180.
  # @return [Result]
  # @raise [Error]
  def self.protect(files:, preset: "balanced", options: nil, label: nil,
                   api_key: nil, api_password: nil, project_name: "ruby-session",
                   endpoint: DEFAULT_ENDPOINT, timeout: 180)
    api_key = resolve_credential(api_key, "JSO_API_KEY", "JAVASCRIPT_OBFUSCATOR_API_KEY")
    api_password = resolve_credential(api_password, "JSO_API_PASSWORD", "JAVASCRIPT_OBFUSCATOR_API_PASSWORD")
    if api_key.empty? || api_password.empty?
      raise Error, "JSO API credentials not configured. Pass api_key/api_password or export JSO_API_KEY / JSO_API_PASSWORD."
    end

    raise Error, "At least one file is required." if files.nil? || files.empty?

    preset_name = preset.to_s.downcase
    unless PRESETS.key?(preset_name)
      raise Error, "Unknown preset #{preset.inspect}. Pick one of #{PRESETS.keys.sort.inspect}."
    end

    payload = {
      "APIKey"  => api_key,
      "APIPwd"  => api_password,
      "Name"    => project_name,
      "Items"   => files.map { |name, code| { "FileName" => name, "FileCode" => code.to_s } },
    }
    payload["ReleaseLabel"] = label unless label.nil? || label.to_s.empty?
    PRESETS[preset_name].each { |k, v| payload[k] = v }
    options&.each { |k, v| payload[k] = v }

    uri = URI(endpoint)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "text/json"
    request["User-Agent"] = "jso-protector-ruby/#{VERSION}"
    request.body = JSON.dump(payload)

    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: uri.scheme == "https",
                               read_timeout: timeout) do |http|
      http.request(request)
    end

    code = response.code.to_i
    body = response.body.to_s
    if code < 200 || code >= 300
      snippet = body[0, 200]
      raise Error, "HTTP #{code}: #{snippet}"
    end

    parsed = begin
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise Error, "Malformed JSON in response: #{e.message}"
    end

    type = parsed["Type"]
    if type != "Succeed"
      msg = parsed["Message"] || parsed["ErrorCode"] || "API request failed"
      raise Error.new(msg, type: type, error_code: parsed["ErrorCode"])
    end

    result = Result.new
    result.raw = parsed
    (parsed["Items"] || []).each do |item|
      name = item["FileName"]
      code = item["FileCode"]
      result.files[name] = code if name && code.is_a?(String)
    end
    raise Error, "API response did not include any protected files." if result.files.empty?

    if (report = parsed["Report"]).is_a?(Hash)
      result.report = report
      result.build_id = report["BuildId"]
      result.polymorphism_fingerprint = report["PolymorphismFingerprint"]
    end
    result
  end

  # @api private
  def self.resolve_credential(value, *env_var_names)
    v = value.to_s.strip
    return v unless v.empty?

    env_var_names.each do |name|
      candidate = ENV[name].to_s.strip
      return candidate unless candidate.empty?
    end
    ""
  end
end
