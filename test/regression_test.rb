# frozen_string_literal: true

require_relative "../lib/tiktoken"
require_relative "benchmark/benchmark_test"
require_relative "benchmark/profile_test"
require_relative "helpers/helper"
require "minitest/autorun"
require "mocha/minitest"

class RegressionTest < Minitest::Test
  ENV["CITEST"] = "true"
  system("bash script/memory-profile")

  def setup
    @str_encoding = "cl100k_base"
    @encoder = Tiktoken::Encoder.new(@str_encoding)
    @four_h_string = Helper::FOUR_H_STRING
    @ruby_profile = File.read("ruby.memory.profile.txt")
    @c_profile = File.read("c.memory.profile.txt")
  end

  def test_timing_regression
    runs = 50000
    time1 = BenchmarkTest.new.benchmark(runs: runs) do
      @encoder.encode_string(text: @four_h_string)
    end
    time2 = BenchmarkTest.new.benchmark(runs: runs) do
      @encoder.encode_string(text: @four_h_string)
    end
    time3 = BenchmarkTest.new.benchmark(runs: runs) do
      @encoder.encode_string(text: @four_h_string)
    end

    time = (time1 + time2 + time3) / 3.0
    # these values are tuned for the CI environment,
    # You should see the same or better performance locally
    # or on a codespace
    # Since timings seem to vary in CI we need to get an average
    # and then set our expectatiins based on that
    assert time < 37.0, "Regression: Avg time for 50k runs should be under 37 seconds, retry the build if you feel this is an outlier."
    assert time / runs < 0.00075, "Regression: Avg time per run should be under 0.00075 seconds, retry the build if you feel this is an outlier."
    @encoder.free_encoding
  end


  def test_memory_regression
    result = @ruby_profile
    assert !result.nil? && result.include?("Total retained:"), "Memory profiler failed"
    match = result.match(/Total retained:\s+(\d+)\s+bytes\s+\((\d+)\s+objects\)/)

    assert !match.nil?, "Corrupt Ruby profile"
    puts match

    total_bytes = match[1].to_i
    total_objects = match[2].to_i
    # these values are tuned for the CI environment,
    # You should see the same or better performance locally
    # or on a codespace
    assert total_bytes < 470, "Regression: Increase in retained memory detected"
    assert total_objects < 10, "Regression: Increase in retained objects detected"
  end

  def test_c_memory_regression
    result = @c_profile
    assert !result.nil? && result.include?("total memory leaked:"), "C profile failed"
    match = result.match(/total memory leaked: (\d+(\.\d+)?)K/)
    assert !match.nil?, "Corrupt C profile"
    puts match
    memory_value = match[1].to_f
    # these values are tuned for the CI environment,
    # You should see the same or better performance locally
    # or on a codespace
    assert memory_value < 8.00, "Regression: Increase in retained memory during C profile detected, retry the build if you feel this is an outlier."
  end
end
