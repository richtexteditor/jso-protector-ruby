# frozen_string_literal: true

# Tests for JsoProtector.protect — patches Net::HTTP.start so no real network
# calls happen during tests. Run with: ruby -Ilib -Itest test/test_jso_protector.rb

require "minitest/autorun"
require "json"
require_relative "../lib/jso_protector"

# A minimal Net::HTTP response stand-in.
class FakeResponse
  attr_accessor :code, :body
  def initialize(body, code: "200")
    @body = body
    @code = code
  end
end

# Captures the request body / URI and returns a canned response.
class FakeHttp
  attr_reader :last_request, :last_uri

  def initialize(response_body, status: "200")
    @response_body = response_body
    @status = status
    @captured = nil
  end

  def captured
    return nil if @captured.nil?
    @captured
  end

  def request(req)
    @captured = req
    FakeResponse.new(@response_body, code: @status)
  end
end

class JsoProtectorTest < Minitest::Test
  def with_mock(response_hash, status: "200")
    fake = FakeHttp.new(JSON.dump(response_hash), status: status)
    captured = nil
    Net::HTTP.stub :start, ->(*_args, **_kw, &block) {
      block.call(fake)
    } do
      yield fake
      captured = fake.captured
    end
    captured
  end

  def parsed_body(captured)
    JSON.parse(captured.body)
  end

  def test_label_propagates_as_release_label
    captured_req = with_mock(
      "Type" => "Succeed",
      "Items" => [{ "FileName" => "app.js", "FileCode" => "PROTECTED;" }],
      "Report" => { "BuildId" => "rel-1", "PolymorphismFingerprint" => "abc123" }
    ) do
      @result = JsoProtector.protect(
        api_key: "k",
        api_password: "p",
        files: { "app.js" => "let x = 1;" },
        preset: "balanced",
        label: "ci-build-7f3a",
      )
    end

    body = parsed_body(captured_req)
    assert_equal "ci-build-7f3a", body["ReleaseLabel"]
    assert_equal "k", body["APIKey"]
    assert_equal "p", body["APIPwd"]
    assert_equal true, body["FlatTransform"]
    assert_equal "rel-1", @result.build_id
    assert_equal "abc123", @result.polymorphism_fingerprint
    assert_equal({ "app.js" => "PROTECTED;" }, @result.files)
  end

  def test_options_override_preset
    captured_req = with_mock(
      "Type" => "Succeed",
      "Items" => [{ "FileName" => "x.js", "FileCode" => "OK;" }]
    ) do
      JsoProtector.protect(
        api_key: "k", api_password: "p",
        files: { "x.js" => "let y = 2;" },
        preset: "balanced",
        options: { "FlatTransform" => false, "LockDomain" => true, "LockDomainList" => "example.com" },
      )
    end
    body = parsed_body(captured_req)
    assert_equal false, body["FlatTransform"]
    assert_equal true, body["LockDomain"]
    assert_equal "example.com", body["LockDomainList"]
  end

  def test_env_var_fallback_for_credentials
    ENV["JSO_API_KEY"] = "env-key"
    ENV["JSO_API_PASSWORD"] = "env-pwd"
    captured_req = with_mock(
      "Type" => "Succeed",
      "Items" => [{ "FileName" => "a.js", "FileCode" => "OK;" }]
    ) do
      JsoProtector.protect(files: { "a.js" => "let z = 3;" })
    end
    body = parsed_body(captured_req)
    assert_equal "env-key", body["APIKey"]
    assert_equal "env-pwd", body["APIPwd"]
  ensure
    ENV.delete("JSO_API_KEY")
    ENV.delete("JSO_API_PASSWORD")
  end

  def test_missing_credentials_raises
    ENV.delete("JSO_API_KEY")
    ENV.delete("JSO_API_PASSWORD")
    ENV.delete("JAVASCRIPT_OBFUSCATOR_API_KEY")
    ENV.delete("JAVASCRIPT_OBFUSCATOR_API_PASSWORD")
    err = assert_raises(JsoProtector::Error) do
      JsoProtector.protect(files: { "a.js" => "x" })
    end
    assert_match(/credentials/i, err.message)
  end

  def test_unknown_preset_raises
    err = assert_raises(JsoProtector::Error) do
      JsoProtector.protect(
        api_key: "k", api_password: "p",
        files: { "a.js" => "x" },
        preset: "elephant"
      )
    end
    assert_match(/preset/i, err.message)
    assert_match(/elephant/, err.message)
  end

  def test_empty_files_raises
    err = assert_raises(JsoProtector::Error) do
      JsoProtector.protect(api_key: "k", api_password: "p", files: {})
    end
    assert_match(/file/i, err.message)
  end

  def test_non_succeed_type_raises_with_message_and_code
    captured_req = with_mock(
      "Type" => "Error",
      "Message" => "Invalid API key",
      "ErrorCode" => "AUTH_FAIL"
    ) do
      err = assert_raises(JsoProtector::Error) do
        JsoProtector.protect(api_key: "k", api_password: "p", files: { "a.js" => "x" })
      end
      assert_equal "Invalid API key", err.message
      assert_equal "Error", err.type
      assert_equal "AUTH_FAIL", err.error_code
    end
    refute_nil captured_req
  end

  def test_preset_table_has_expected_entries
    assert JsoProtector::PRESETS.key?("standard")
    assert JsoProtector::PRESETS.key?("balanced")
    assert JsoProtector::PRESETS.key?("maximum")
    assert JsoProtector::PRESETS["maximum"].size > JsoProtector::PRESETS["standard"].size
  end
end
