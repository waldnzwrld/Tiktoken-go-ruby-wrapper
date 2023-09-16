# frozen_string_literal: true

require_relative '../../../tiktoken-encoder/lib/tiktoken/encoder'
require_relative '../../helper'
require 'minitest/autorun'
require 'pry'

class TiktokenEncoderTest < Minitest::Test
  def setup
    @str_encoding = 'cl100k_base'
    @encoder = TikToken::Encoder.new(@str_encoding)
    @named_encoding = 'gpt-4'
    @named_encoder = TikToken::Encoder.new(@named_encoding)
    @four_h_string = Helper::FOUR_H_STRING
    @test_string = Helper::TEST_STRING
  end

  def test_encode_string
    size, tokens = @encoder.encode_string(@test_string)
    assert_equal 5, size
    assert_equal [16_010, 19_987, 1093, 2466, 15_039], tokens
  end

  def test_encode_string_four_hundred
    size, tokens = @encoder.encode_string(@four_h_string)
    assert_equal 384, size
    assert_equal [33_883, 27_439, 24_578, 2503, 28_311], tokens.first(5)
  end

  def test_decode_tokens
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = tokens.size
    assert_equal @test_string, @encoder.decode_tokens(tokens, size)
  end

  def test_convert_tokens_to_pointer
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = tokens.size
    pointer = @encoder.convert_tokens_to_pointer(tokens)
    assert_equal tokens, pointer.read_array_of_int(size)
  end

  def test_free_encoder
    @encoder.free_encoder
    assert_equal FFI::Pointer::NULL, @encoder.encoder
  end

  def test_named_encoder
    size, tokens = @named_encoder.encode_string(@test_string)
    assert_equal 5, size
    assert_equal [16_010, 19_987, 1093, 2466, 15_039], tokens
  end

  def test_named_encoder_four_hundred
    size, tokens = @named_encoder.encode_string(@four_h_string)
    assert_equal 384, size
    assert_equal [33_883, 27_439, 24_578, 2503, 28_311], tokens.first(5)
  end

  def test_named_decode_tokens
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = tokens.size
    assert_equal @test_string, @named_encoder.decode_tokens(tokens, size)
  end

  def test_creating_encoder_with_bad_name_raises
    assert_raises(RuntimeError) { TikToken::Encoder.new('not_a_real_encoder') }
  end

  def calling_encode_with_a_non_string_raises_and_releases_encoder
    assert_raises(RuntimeError) { @encoder.encode_string(FFI::Pointer::NULL) }
    assert_equal FFI::Pointer::NULL, @encoder.encoder
  end

  def test_decode_tokens_raises_if_size_is_not_int
    tokens = [16_010, 19_987, 1093, 2466, 15_039]
    size = 'not an int'
    assert_raises { @encoder.decode_tokens(tokens, size) }
    assert_equal FFI::Pointer::NULL, @encoder.encoder
  end
end
