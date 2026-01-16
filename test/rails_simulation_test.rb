# frozen_string_literal: true

require 'minitest/autorun'
require 'tiktoken/encoder'
require 'get_process_mem'

# Simulates Rails application usage patterns
# Tests long-running process behavior and request-like patterns
class RailsSimulationTest < Minitest::Test
  # In Rails, you might reuse an encoder across requests (singleton pattern)
  # or create a new one per request. Test both patterns.
  
  # Allow reasonable memory growth for Go GC variations
  # Go's concurrent GC may not immediately reclaim memory
  ALLOWED_MEMORY_GROWTH_MB = 20.0
  SIMULATED_REQUESTS = 1000

  def setup
    force_gc
    @baseline_memory = current_memory_mb
  end

  def teardown
    force_gc
  end

  # Pattern 1: Singleton encoder (recommended for Rails)
  # One encoder instance shared across all requests
  def test_singleton_encoder_pattern
    encoder = TikToken::Encoder.new('cl100k_base')
    
    # Simulate web requests
    request_texts = [
      'Short text',
      'Medium length text that simulates a typical API request body with some content',
      'Longer text ' * 100,
      'Very long text with lots of content ' * 500,
      'Unicode text: こんにちは世界 🌍 مرحبا بالعالم',
    ]

    # Warmup
    50.times do
      text = request_texts.sample
      size, tokens = encoder.encode_string(text)
      encoder.decode_tokens(tokens, size)
    end
    force_gc
    memory_after_warmup = current_memory_mb

    # Simulate many requests over time
    SIMULATED_REQUESTS.times do |i|
      text = request_texts.sample
      size, tokens = encoder.encode_string(text)
      decoded = encoder.decode_tokens(tokens, size)
      
      # Periodically check memory (like a monitoring service would)
      if (i + 1) % 100 == 0
        force_gc
        current = current_memory_mb
        growth = current - memory_after_warmup
        assert growth < ALLOWED_MEMORY_GROWTH_MB,
               "Memory growing during requests: #{growth.round(2)}MB at request #{i + 1}"
      end
    end

    force_gc
    final_memory = current_memory_mb
    total_growth = final_memory - memory_after_warmup

    assert total_growth < ALLOWED_MEMORY_GROWTH_MB,
           "Singleton pattern leaked #{total_growth.round(2)}MB over #{SIMULATED_REQUESTS} requests"
  ensure
    encoder&.free_encoder
  end

  # Pattern 2: Per-request encoder (not recommended but sometimes used)
  def test_per_request_encoder_pattern
    request_texts = [
      'Short text',
      'Medium length text for testing',
      'Longer text ' * 50,
    ]

    # Warmup
    20.times do
      encoder = TikToken::Encoder.new('cl100k_base')
      text = request_texts.sample
      encoder.encode_string(text)
      encoder.free_encoder
    end
    force_gc
    memory_after_warmup = current_memory_mb

    # Simulate requests, each with its own encoder
    500.times do |i|
      encoder = TikToken::Encoder.new('cl100k_base')
      text = request_texts.sample
      size, tokens = encoder.encode_string(text)
      encoder.decode_tokens(tokens, size)
      encoder.free_encoder
      
      # Periodic GC to simulate realistic conditions
      force_gc if (i + 1) % 50 == 0
    end

    force_gc
    final_memory = current_memory_mb
    total_growth = final_memory - memory_after_warmup

    assert total_growth < ALLOWED_MEMORY_GROWTH_MB,
           "Per-request pattern leaked #{total_growth.round(2)}MB over 500 requests"
  end

  # Pattern 3: Background job processing (like Sidekiq)
  def test_background_job_pattern
    # Simulate batch processing jobs
    batch_texts = Array.new(100) { "Document content #{rand(1000)} with some text to process " * 20 }

    encoder = TikToken::Encoder.new('cl100k_base')

    # Warmup
    batch_texts.first(10).each do |text|
      size, tokens = encoder.encode_string(text)
      encoder.decode_tokens(tokens, size)
    end
    force_gc
    memory_after_warmup = current_memory_mb

    # Simulate 50 batch jobs, each processing multiple documents
    50.times do |job_num|
      # Each job processes a batch of documents
      batch_texts.each do |text|
        size, tokens = encoder.encode_string(text)
        encoder.decode_tokens(tokens, size)
      end
      
      # GC between jobs (simulates job queue idle time)
      force_gc if job_num % 5 == 0
    end

    force_gc
    final_memory = current_memory_mb
    total_growth = final_memory - memory_after_warmup

    assert total_growth < ALLOWED_MEMORY_GROWTH_MB,
           "Background job pattern leaked #{total_growth.round(2)}MB over 50 batch jobs"
  ensure
    encoder&.free_encoder
  end

  # Test encoder pooling pattern (advanced Rails pattern)
  def test_encoder_pool_pattern
    # Create a small pool of encoders
    pool_size = 3
    pool = Array.new(pool_size) { TikToken::Encoder.new('cl100k_base') }
    
    test_texts = [
      'Request 1 content',
      'Request 2 with more content here',
      'Request 3 ' * 50,
    ]

    # Warmup
    50.times do
      encoder = pool.sample
      text = test_texts.sample
      size, tokens = encoder.encode_string(text)
      encoder.decode_tokens(tokens, size)
    end
    force_gc
    memory_after_warmup = current_memory_mb

    # Simulate concurrent-like access (sequential but mimics pattern)
    1000.times do |i|
      encoder = pool[i % pool_size]
      text = test_texts.sample
      size, tokens = encoder.encode_string(text)
      encoder.decode_tokens(tokens, size)
    end

    force_gc
    final_memory = current_memory_mb
    total_growth = final_memory - memory_after_warmup

    assert total_growth < ALLOWED_MEMORY_GROWTH_MB,
           "Encoder pool pattern leaked #{total_growth.round(2)}MB"
  ensure
    pool&.each(&:free_encoder)
  end

  # Long-running stability test
  def test_long_running_stability
    encoder = TikToken::Encoder.new('cl100k_base')
    test_text = 'Standard test text for long running test ' * 10

    # Warmup
    100.times do
      size, tokens = encoder.encode_string(test_text)
      encoder.decode_tokens(tokens, size)
    end
    force_gc
    memory_baseline = current_memory_mb

    # Track memory over time
    memory_samples = []
    
    10.times do |phase|
      # Each phase simulates ~10 minutes of activity (scaled down)
      500.times do
        size, tokens = encoder.encode_string(test_text)
        encoder.decode_tokens(tokens, size)
      end
      
      force_gc
      memory_samples << current_memory_mb
      
      # Check for continuous growth (would indicate a leak)
      if memory_samples.size >= 3
        recent_trend = memory_samples.last(3)
        if recent_trend == recent_trend.sort && recent_trend.last - recent_trend.first > 5.0
          flunk "Memory continuously growing: #{recent_trend.map { |m| m.round(2) }.join(' -> ')}MB"
        end
      end
    end

    final_growth = memory_samples.last - memory_baseline
    assert final_growth < ALLOWED_MEMORY_GROWTH_MB,
           "Long-running test leaked #{final_growth.round(2)}MB over 10 phases"
  ensure
    encoder&.free_encoder
  end

  private

  def current_memory_mb
    GetProcessMem.new.mb
  end

  def force_gc
    3.times do
      GC.start(full_mark: true, immediate_sweep: true)
      sleep(0.01)
    end
  end
end
