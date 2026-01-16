# frozen_string_literal: true

require 'tiktoken/encoder'
require 'memory_profiler'

# Ruby object allocation profiling
# NOTE: This only tracks Ruby objects, not native C/Go memory.
# For native memory testing, use memory_leak_test.rb or rails_simulation_test.rb
#
# Usage: ruby -Itiktoken-encoder/lib test/memory_profiler_test.rb

def run_memory_profiler_test
  puts "=" * 60
  puts "Ruby Object Allocation Profile"
  puts "NOTE: This tracks Ruby objects only, not native C/Go memory"
  puts "=" * 60

  report = MemoryProfiler.report do
    encoder = TikToken::Encoder.new('cl100k_base')
    test_text = 'This is a test string that we will encode and decode multiple times.'

    1000.times do
      size, tokens = encoder.encode_string(test_text)
      decoded = encoder.decode_tokens(tokens, size)
      raise "Roundtrip failed" unless decoded == test_text
    end

    encoder.free_encoder
  end

  puts "\nTop 10 allocations by gem:"
  report.pretty_print(to_file: nil, scale_bytes: true, detailed_report: false)

  puts "\n" + "=" * 60
  puts "Key metrics:"
  puts "  Total allocated: #{report.total_allocated} objects"
  puts "  Total retained:  #{report.total_retained} objects"
  puts "=" * 60

  # Check for unexpected retained objects
  if report.total_retained > 100
    puts "\nWARNING: High retained object count may indicate Ruby-side leaks"
    puts "Review retained objects above"
  else
    puts "\nRuby object retention looks healthy"
  end
end

run_memory_profiler_test
