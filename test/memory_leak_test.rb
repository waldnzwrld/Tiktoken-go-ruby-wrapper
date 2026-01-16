# frozen_string_literal: true

require 'minitest/autorun'
require 'tiktoken/encoder'
require 'get_process_mem'

# Comprehensive memory leak tests for the TikToken gem
# These tests detect native (C/Go) memory leaks by checking for unbounded growth.
#
# Important notes about memory testing with Go:
# - Go has a concurrent GC that doesn't immediately free memory
# - Go may retain some freed memory as reserved for future use
# - Memory usage can fluctuate between GC cycles
#
# These tests focus on detecting TRUE leaks (continuous unbounded growth)
# rather than transient memory usage variations.
class MemoryLeakTest < Minitest::Test
  # Number of iterations for stress tests
  STRESS_ITERATIONS = 5000
  
  # Number of warmup iterations before measuring
  WARMUP_ITERATIONS = 200
  
  # Maximum allowed memory growth per 1000 operations (MB)
  # This is a per-operation rate to detect continuous leaks
  MAX_GROWTH_PER_1000_OPS = 2.0

  def setup
    # Force GC before each test to get clean baseline
    force_gc
    @baseline_memory = current_memory_mb
  end

  def teardown
    force_gc
  end

  # Test that repeated encode operations don't leak memory
  def test_encode_does_not_leak
    encoder = TikToken::Encoder.new('cl100k_base')
    test_text = 'This is a test string for encoding. ' * 10

    # Extended warmup to stabilize Go GC
    WARMUP_ITERATIONS.times { encoder.encode_string(test_text) }
    force_gc
    
    # Run stress test in phases, measuring growth rate
    assert_no_continuous_growth('encode') do
      1000.times { encoder.encode_string(test_text) }
    end
  ensure
    encoder&.free_encoder
  end

  # Test that repeated decode operations don't leak memory
  def test_decode_does_not_leak
    encoder = TikToken::Encoder.new('cl100k_base')
    test_text = 'This is a test string for decoding. ' * 10
    _size, tokens = encoder.encode_string(test_text)

    # Extended warmup
    WARMUP_ITERATIONS.times { encoder.decode_tokens(tokens, tokens.size) }
    force_gc

    # Run stress test in phases
    assert_no_continuous_growth('decode') do
      1000.times { encoder.decode_tokens(tokens, tokens.size) }
    end
  ensure
    encoder&.free_encoder
  end

  # Test that encode + decode roundtrip doesn't leak
  def test_roundtrip_does_not_leak
    encoder = TikToken::Encoder.new('cl100k_base')
    test_text = 'This is a test string for roundtrip. ' * 10

    # Extended warmup
    WARMUP_ITERATIONS.times do
      size, tokens = encoder.encode_string(test_text)
      encoder.decode_tokens(tokens, size)
    end
    force_gc

    # Run stress test in phases
    assert_no_continuous_growth('roundtrip') do
      1000.times do
        size, tokens = encoder.encode_string(test_text)
        decoded = encoder.decode_tokens(tokens, size)
        assert_equal test_text, decoded
      end
    end
  ensure
    encoder&.free_encoder
  end

  # Test that encoder instances are properly garbage collected
  # when explicitly freed
  def test_encoder_lifecycle_with_explicit_free
    # Warmup - create and destroy a few encoders
    10.times do
      e = TikToken::Encoder.new('cl100k_base')
      e.encode_string('warmup')
      e.free_encoder
    end
    force_gc
    memory_after_warmup = current_memory_mb

    # Create many encoder instances with explicit cleanup
    100.times do
      encoder = TikToken::Encoder.new('cl100k_base')
      encoder.encode_string('test string')
      encoder.free_encoder
      force_gc if rand < 0.2  # Periodic GC
    end
    force_gc
    memory_after_test = current_memory_mb

    # Check final memory is close to warmup memory
    # Allow up to 20MB for GC timing variations
    memory_growth = memory_after_test - memory_after_warmup
    assert memory_growth < 20.0,
           "Encoder lifecycle leaked: grew #{memory_growth.round(2)}MB with explicit free"
  end

  # Test with large text - focuses on stabilization
  def test_large_text_stabilizes
    encoder = TikToken::Encoder.new('cl100k_base')
    large_text = 'Lorem ipsum dolor sit amet. ' * 4000  # ~100KB

    # Extended warmup with large text
    50.times do
      size, tokens = encoder.encode_string(large_text)
      encoder.decode_tokens(tokens, size)
    end
    force_gc
    
    # Run multiple phases and check that memory stabilizes
    memory_samples = []
    5.times do |phase|
      50.times do
        size, tokens = encoder.encode_string(large_text)
        encoder.decode_tokens(tokens, size)
      end
      force_gc
      memory_samples << current_memory_mb
    end

    # Check that later phases don't grow significantly more than earlier phases
    # (indicating stabilization rather than continuous leak)
    first_half_avg = memory_samples[0..1].sum / 2.0
    second_half_avg = memory_samples[3..4].sum / 2.0
    growth = second_half_avg - first_half_avg

    assert growth < 15.0,
           "Large text memory doesn't stabilize: phases #{memory_samples.map { |m| m.round(1) }.join(' -> ')}MB"
  ensure
    encoder&.free_encoder
  end

  # Test different encodings don't leak
  def test_multiple_encodings_do_not_leak
    encodings = %w[cl100k_base p50k_base r50k_base]
    test_text = 'Test string for multiple encodings. ' * 5

    # Warmup each encoding
    encodings.each do |enc|
      e = TikToken::Encoder.new(enc)
      10.times { e.encode_string(test_text) }
      e.free_encoder
    end
    force_gc
    memory_after_warmup = current_memory_mb

    # Test cycling through encodings
    30.times do
      encodings.each do |enc|
        encoder = TikToken::Encoder.new(enc)
        size, tokens = encoder.encode_string(test_text)
        encoder.decode_tokens(tokens, size)
        encoder.free_encoder
      end
      force_gc if rand < 0.3
    end
    force_gc
    memory_after_test = current_memory_mb

    memory_growth = memory_after_test - memory_after_warmup
    assert memory_growth < 30.0,
           "Multiple encodings leaked: grew #{memory_growth.round(2)}MB"
  end

  # Test finalizers exist (they provide safety net, even if not reliable for timely cleanup)
  def test_finalizer_is_registered
    encoder = TikToken::Encoder.new('cl100k_base')
    finalizers = ObjectSpace.each_object(Proc).select do |proc|
      proc.source_location&.first&.include?('encoder.rb')
    end
    refute_empty finalizers, 'Encoder should register a finalizer'
  ensure
    encoder&.free_encoder
  end

  private

  def current_memory_mb
    GetProcessMem.new.mb
  end

  def force_gc
    # Run GC multiple times to ensure all finalizers run
    3.times do
      GC.start(full_mark: true, immediate_sweep: true)
      sleep(0.01)  # Small delay to allow Go GC to run
    end
  end

  # Runs a block multiple times and checks for continuous memory growth
  # A true leak would show growth in every phase; normal GC variations
  # would show some phases with no growth or even decreases
  def assert_no_continuous_growth(operation_name)
    memory_samples = []
    
    # Run 5 phases, measuring memory after each
    5.times do |phase|
      yield
      force_gc
      memory_samples << current_memory_mb
    end

    # Check for continuous growth pattern (all phases growing)
    growth_deltas = memory_samples.each_cons(2).map { |a, b| b - a }
    
    # If all deltas are positive and significant, likely a leak
    continuous_growth = growth_deltas.all? { |d| d > 1.0 }
    total_growth = memory_samples.last - memory_samples.first
    
    refute continuous_growth && total_growth > 10.0,
           "#{operation_name} shows continuous memory growth: " \
           "#{memory_samples.map { |m| m.round(1) }.join(' -> ')}MB " \
           "(deltas: #{growth_deltas.map { |d| d.round(1) }.join(', ')}MB)"
  end
end
