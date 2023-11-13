# frozen_string_literal: true

# disable Naming/MethodName for the whole file
# this is to ensure parity with the function
# names in the C wrapper

# rubocop:disable Naming/MethodName

module Tiktoken
  class Encoder

    # This class communicates with a C lib that acts as a wrapper
    # for the tiktoken.go package
    require "fiddle"

    LIBPATH = File.expand_path("../ext/libttwrapper.so", File.dirname(__FILE__))

    attr_reader :encoding_type, :encoding
    def initialize(encoding_type)
      @encoding_type = encoding_type
      @encoding = self.class.getEncoding(@encoding_type)
      ObjectSpace.define_finalizer(self, self.class.finalizer)
    end

    def self.finalizer
      proc { freeBpe(@encoding) }
    end

    def encode_string(encoding: @encoding, text:)
      token_size = Fiddle::Pointer.malloc(Fiddle::SIZEOF_LONG)
      if encoding.nil? || encoding.null?
        # gracefully handle the error by reallocating the encoding
        encoding = self.class.getEncoding(@encoding_type)
      end

      tokens = self.class.encode(encoding, text, token_size)
      if tokens.null?
        raise RuntimeError.new("Could not encode text")
      end
      # get the int value at the first address of the pointer,
      # convert to string then unpack to int
      size = token_size[0, Fiddle::SIZEOF_LONG].unpack("q")[0]
      # get the full set of tokens from the pointer
      # convert to string then unpack to array of int
      [size, tokens[0, size * Fiddle::SIZEOF_INT].unpack("i#{size}")]
    # rescue from RuntimeError and StandardError
    rescue RuntimeError, StandardError => e
      # free_encoding on the encoding if the encoding is allocated
      free_encoding(encoding: encoding) if !encoding&.null? && encoding.is_a?(Fiddle::Pointer)
      raise e
    ensure
      Fiddle.free(token_size) if token_size.is_a?(Fiddle::Pointer)
      self.class.freeTokensArray(tokens) if !tokens&.null? && tokens.is_a?(Fiddle::Pointer)
    end

    def decode_tokens(encoding: @encoding, tokens:, size:)
      if encoding.nil? || encoding.null?
        # gracefully handle the error by reallocating the encoding
        encoding = self.class.getEncoding(@encoding_type)
      end
      # takes an array of tokens gets the length of the array and calls the decode function
      # returns a string
      raise StandardError, "size must be an integer" unless size.is_a?(Integer)

      tokens = convert_tokens_to_pointer(tokens) if tokens.is_a?(Array)

      text_ptr = self.class.decode(encoding, tokens, size)
      text_ptr.to_s
    rescue => e
      # free_encoding on the pointer if the pointer is allocated
      encoding = free_encoding(encoding: encoding) if !encoding&.null?
      raise e
    ensure
      Fiddle.free(tokens) if tokens.is_a?(Fiddle::Pointer)
      self.class.freeText(text_ptr) if !text_ptr&.null? && text_ptr.is_a?(Fiddle::Pointer)
    end

    def convert_tokens_to_pointer(tokens)
      size = tokens.size
      pointer = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * size)
      pointer[0, Fiddle::SIZEOF_INT * size] = tokens.pack("i#{size}")

      pointer
    end


    def free_encoding(encoding: @encoding)
      self.class.freeBpe(encoding)
      encoding = nil
    end

  private
    def self.ttwrapper
      @ttwrapper ||= Fiddle.dlopen(LIBPATH)
    end

    def self.goProfile(encoding, text, token_size, runs, extProfile = 0)
      Fiddle::Function.new(
        ttwrapper["goProfile"],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOID
      ).call(encoding, text, token_size, runs, extProfile)
    end

    def self.freeTokensArray(tokens)
      Fiddle::Function.new(
        ttwrapper["freeTokensArray"],
        [Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOID
      ).call(tokens)
    end

    def self.freeText(text)
      Fiddle::Function.new(
        ttwrapper["freeText"],
        [Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOID
      ).call(text)
    end

    def self.freeBpe(encoding)
      Fiddle::Function.new(
        ttwrapper["freeBpe"],
        [Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOID
      ).call(encoding)
    end

    def self.getEncoding(encoding_type)
      ptr = Fiddle::Function.new(
        ttwrapper["getEncoding"],
        [Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOIDP
      ).call(encoding_type)
      # if ptr references 0 raise an error the encoding failed
      raise RuntimeError.new("Could not find encoding #{@encoding_type}") if ptr.null?
      ptr
    end

    def self.encode(encoding, text, token_size)
      Fiddle::Function.new(
        ttwrapper["encode"],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
        Fiddle::TYPE_VOIDP
      ).call(encoding, text, token_size)
    end


    def self.decode(encoding, tokens, size)
      Fiddle::Function.new(
        ttwrapper["decode"],
        [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT],
        Fiddle::TYPE_VOIDP
      ).call(encoding, tokens, size)
    end
  end
end
