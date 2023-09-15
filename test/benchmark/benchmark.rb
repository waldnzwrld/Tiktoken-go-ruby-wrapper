require_relative '../../tiktoken-wrapper/lib/tiktokenwrapper.rb'
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

    def go_profile(encoding_type:, text:, runs: 0)
        n = FFI::MemoryPointer.new(:long)
        TikTokenWrapper.goProfile(encoding_type, text, n, runs)
    end
end

benchmarker = BenchmarkTests.new

n = FFI::MemoryPointer.new(:long)
c_ptr = TikTokenWrapper.get_encoding(encoding: "cl100k_base")

benchmarker.benchmark do
  TikTokenWrapper.encode_string(encoder: c_ptr, text: BenchmarkTests::FOUR_K_STRING, size: n)
end

benchmarker.ruby_profile do
  50000.times do
    TikTokenWrapper.encode_string(encoder: c_ptr, text: BenchmarkTests::FOUR_K_STRING, size: n)
  end
  TikTokenWrapper.free_encoder(encoder: c_ptr)
end

benchmarker.go_profile(encoding_type: "cl100k_base", text: BenchmarkTests::FOUR_K_STRING)
