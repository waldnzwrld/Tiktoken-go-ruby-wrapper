require_relative '../../tiktoken-wrapper/lib/tiktoken/encoder.rb'
require 'ffi'
require 'benchmark'
require 'memory_profiler'

class BenchmarkTests
    four_h_string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

    FOUR_K_STRING = four_h_string * 10
    def benchmark()
        # do not allow the block to be a call to go_profile
        return unless block_given?
        time = Benchmark.realtime do
            50000.times do
                yield
            end
        end
        puts "Total time taken for 50000 iterations: #{time} seconds"
        puts "Average time per iteration: #{time / 50000} seconds"
    end

    def ruby_profile()
        # do not allow the block to be a call to go_profile
        # this will cause a segfault
        return unless block_given?
        MemoryProfiler.start
        yield
        report = MemoryProfiler.stop
        report.pretty_print
    end

    def test_over_time()
        return unless block_given?
        i = 0
        while i < 100
            yield
            p "#{i + 1} successful runs"
            i += 1
        end
    end
end

benchmarker = BenchmarkTests.new
encoding = "cl100k_base"
encoder = TikToken::Encoder.new(encoding_type: encoding)

benchmarker.benchmark do
  encoder.encode_string(text: BenchmarkTests::FOUR_K_STRING)
end

benchmarker.ruby_profile do
  50000.times do
    encoder.encode_string(text: BenchmarkTests::FOUR_K_STRING)
  end
  encoder.free_encoder
end

encoder.go_profile(text: BenchmarkTests::FOUR_K_STRING)
