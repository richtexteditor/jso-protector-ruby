# frozen_string_literal: true

require_relative "lib/jso_protector"

Gem::Specification.new do |spec|
  spec.name          = "jso_protector"
  spec.version       = JsoProtector::VERSION
  spec.authors       = ["JavaScript Obfuscator"]
  spec.summary       = "Ruby client for the JavaScript Obfuscator HTTP API."
  spec.description   = "Pure-stdlib Ruby client mirroring the jso-protector npm CLI. " \
                       "Three protection presets, env-var-first credentials, BuildId + " \
                       "polymorphism fingerprint surfaced for audit/symbolication."
  spec.homepage      = "https://javascriptobfuscator.com/docs/npmcli.aspx"
  spec.license       = "LicenseRef-Proprietary"  # see LICENSE; client for the JSO hosted service.

  spec.required_ruby_version = ">= 2.7.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "jso_protector.gemspec"
  ]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "homepage_uri"      => spec.homepage,
    "documentation_uri" => "https://javascriptobfuscator.com/docs/",
    "source_code_uri"   => "https://github.com/richtexteditor/jso-protector-ruby",
  }
end
