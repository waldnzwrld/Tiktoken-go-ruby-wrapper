# frozen_string_literal: true

require_relative "../../lib/tiktoken"
require_relative "../helpers/helper"
require "benchmark"

class BenchmarkTest
  def benchmark(runs: 50000, &block)
    # do not allow the block to be a call to go_profile
    return unless block_given?

    time = Benchmark.realtime do
      runs.times(&block)
    end
    puts "Total time taken for #{runs} iterations: #{time} seconds\n"
    puts "Average time per iteration: #{time / runs} seconds\n"
    time
  end

  def encoder
    @encoder ||= Tiktoken::Encoder.new("cl100k_base")
  end

  def test_string
    @test_string ||= Helper::FOUR_H_STRING
  end

  def performance_test
    BenchmarkTest.new.benchmark do
      encoder.encode_string(text: test_string)
    end

    encoder.free_encoding
    return
  end
end
