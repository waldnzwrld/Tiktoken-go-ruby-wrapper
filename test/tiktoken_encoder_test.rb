# frozen_string_literal: true

require_relative "../lib/tiktoken"
require_relative "helpers/helper"
require "minitest/autorun"
require "mocha/minitest"

class TiktokenEncoderTest < Minitest::Test
  def setup
    @str_encoding = "cl100k_base"
    @encoder = Tiktoken::Encoder.new(@str_encoding)
    @named_encoding = "gpt-4"
    @named_encoder = Tiktoken::Encoder.new(@named_encoding)
    @four_h_string = Helper::FOUR_H_STRING
    @test_string = Helper::TEST_STRING
  end

  def test_encode_string
    size, tokens = @encoder.encode_string(text: @test_string)
    assert_equal 5, size
    assert_equal [16_010, 19_987, 1093, 2466, 15_039], tokens
  end

  def test_encode_string_four_hundred
    size, tokens = @encoder.encode_string(text: @four_h_string)
    assert_equal 384, size
    assert_equal [33_883, 27_439, 24_578, 2503, 28_311], tokens.first(5)
  end

  def test_encode_string_frees_tokens
    pointer = Fiddle::Pointer.to_ptr(55)
    Tiktoken::Encoder.stubs(:encode).returns(pointer)
    Tiktoken::Encoder.expects(:freeTokensArray).with(pointer)
    @encoder.encode_string(text: @test_string)
  end

  def test_encode_string_raises_if_returned_value_is_null
    pointer = Fiddle::Pointer.new(0)
    Tiktoken::Encoder.stubs(:encode).returns(pointer)
    Tiktoken::Encoder.expects(:freeTokensArray).with(pointer).never
    @encoder.expects(:free_encoding)
    assert_raises(RuntimeError) { @encoder.encode_string(text: @test_string) }
  end

  def test_decode_tokens
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = tokens.size
    assert_equal @test_string, @encoder.decode_tokens(tokens: tokens, size: size)
  end

  def test_decode_tokens_frees_text
    pointer = Fiddle::Pointer.to_ptr("Test")
    Tiktoken::Encoder.stubs(:decode).returns(pointer)
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = tokens.size
    Tiktoken::Encoder.expects(:freeText).with(pointer)
    @encoder.decode_tokens(tokens: tokens, size: size)
  end

  def test_convert_tokens_to_pointer
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = tokens.size
    pointer = @encoder.convert_tokens_to_pointer(tokens)
    assert_equal tokens, pointer[0, size * Fiddle::SIZEOF_INT].unpack("i#{size}")
  end

  def test_free_encoding
    encoding = @encoder.free_encoding
    assert_nil encoding
  end

  def test_named_encoder
    size, tokens = @named_encoder.encode_string(text: @test_string)
    assert_equal 5, size
    assert_equal [16_010, 19_987, 1093, 2466, 15_039], tokens
  end

  def test_named_encoder_four_hundred
    size, tokens = @named_encoder.encode_string(text: @four_h_string)
    assert_equal 384, size
    assert_equal [33_883, 27_439, 24_578, 2503, 28_311], tokens.first(5)
  end

  def test_named_decode_tokens
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = tokens.size
    assert_equal @test_string, @named_encoder.decode_tokens(tokens: tokens, size: size)
  end

  def test_creating_encoder_with_bad_name_raises
    assert_raises(RuntimeError) { Tiktoken::Encoder.new("not_a_real_encoder") }
  end

  def calling_encode_with_a_non_string_raises_and_releases_encoder
    assert_raises(RuntimeError) { @encoder.encode_string(text: Fiddle::Pointer.new(0)) }
    assert_equal Fiddle::Pointer.new(0), @encoder.encoder
  end

  def test_decode_tokens_raises_if_size_is_not_int
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = "not an int"
    @encoder.expects(:free_encoding)
    assert_raises { @encoder.decode_tokens(tokens: tokens, size: size) }
  end

  def test_functionality_if_opened_in_worker_thread
    tokens, size = nil, nil
    decoded_text = nil

    thread = Thread.new do
      encoder = Tiktoken::Encoder.new(@str_encoding)
      size, tokens = encoder.encode_string(text: @test_string)
    end

    thread.join

    assert_equal 5, size
    assert_equal [16_010, 19_987, 1093, 2466, 15_039], tokens

    thread = Thread.new do
      encoder = Tiktoken::Encoder.new(@str_encoding)
      decoded_text = encoder.decode_tokens(tokens: tokens, size: size)
    end

    thread.join

    assert_equal @test_string, decoded_text
  end

  def test_functionality_if_opened_in_many_worker_threads
    tokens, size = nil, nil
    decoded_text = nil

    # Create an array to hold the threads
    threads = Array.new(15)

    # Start the threads
    threads.each_with_index do |_, i|
      threads[i] = Thread.new do
        encoder = Tiktoken::Encoder.new(@str_encoding)
        size, tokens = encoder.encode_string(text: @test_string)
      end
    end

    # Wait for all threads to finish
    threads.each(&:join)

    assert_equal 5, size
    assert_equal [16_010, 19_987, 1093, 2466, 15_039], tokens

    # Start the threads for decoding
    threads.each_with_index do |_, i|
      threads[i] = Thread.new do
        encoder = Tiktoken::Encoder.new(@str_encoding)
        decoded_text = encoder.decode_tokens(tokens: tokens, size: size)
      end
    end

    # Wait for all threads to finish
    threads.each(&:join)

    assert_equal @test_string, decoded_text
  end

  def test_functionality_if_opened_in_forked_process
    tokens, size = nil, nil
    decoded_text = nil

    # Create an array to hold the process IDs
    pids = []

    # Start the processes
    15.times do
      pid = fork do
        # Code inside this block will be executed in the child process
        encoder = Tiktoken::Encoder.new(@str_encoding)
        size, tokens = encoder.encode_string(text: @test_string)
        assert_equal 5, size
        assert_equal [16_010, 19_987, 1093, 2466, 15_039], tokens
        exit! # Ensure child process exits after finishing work
      end

      pids << pid
    end

    # Wait for all child processes to finish
    pids.each { |pid| Process.wait(pid) }

    pids = []

    # Start the processes for decoding
    15.times do
      pid = fork do
        # Code inside this block will be executed in the child process
        encoder = Tiktoken::Encoder.new(@str_encoding)
        decoded_text = encoder.decode_tokens(tokens: [16_010, 19_987, 1093, 2466, 15_039], size: 5)
        assert_equal @test_string, decoded_text
        exit! # Ensure child process exits after finishing work
      end

      pids << pid
    end

    # Wait for all child processes to finish
    pids.each { |pid| Process.wait(pid) }
  end
end
