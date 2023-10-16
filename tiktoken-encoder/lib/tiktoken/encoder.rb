# frozen_string_literal: true

require 'ffi'

module TikToken
  # This class communicates with a C lib that acts as a wrapper
  # for the tiktoken.go package
  class Encoder
    extend FFI::Library
    ffi_lib File.expand_path('../../ext/tiktoken-encoder/libttwrapper.so', File.dirname(__FILE__))

    attr_reader :token_size, :encoder

    def initialize(encoding_type)
      @encoding_type = encoding_type
      @token_size = FFI::MemoryPointer.new(:long)
      @encoder = self.class.get_encoding(encoding: encoding_type)
      ObjectSpace.define_finalizer(self, proc { free_encoder })
    end

    def encode_string(text)
      tokens = self.class.encode(@encoder, text, @token_size)
      [@token_size.read_long, tokens.read_array_of_int(@token_size.read_long)]
    rescue StandardError => e
      # free_encoder on the encoder if the encoder is allocated
      free_encoder if @encoder != FFI::Pointer::NULL
      raise e
    end

    def decode_tokens(tokens, size)
      # takes an array of tokens gets the length of the array and calls the decode function
      # returns a string
      raise StandardError, 'size must be an integer' unless size.is_a?(Integer)

      tokens = convert_tokens_to_pointer(tokens) if tokens.is_a?(Array)

      self.class.decode(@encoder, tokens, size)
    rescue StandardError => e
      # free_encoder on the pointer if the pointer is allocated
      free_encoder if @encoder != FFI::Pointer::NULL
      raise e
    ensure
      tokens.free if tokens.is_a?(FFI::MemoryPointer)
    end

    def convert_tokens_to_pointer(tokens)
      # takes an array of tokens and converts them into a C Array
      size = tokens.size
      FFI::MemoryPointer.new(:int, size).write_array_of_int(tokens)
    end

    def free_encoder
      self.class.freeBpe(@encoder)
      @encoder = FFI::Pointer::NULL
    end

    def self.get_encoding(encoding:)
      ptr = getEncoding(encoding)
      # if ptr references 0 raise an error the encoding failed
      raise "Could not find encoding #{encoding}" if ptr == FFI::Pointer::NULL

      ptr
    end

    attach_function :goProfile, %i[string string pointer int], :void
    attach_function :getEncoding, [:string], :pointer
    attach_function :encode, %i[pointer string pointer], :pointer
    attach_function :decode, %i[pointer pointer int], :string
    attach_function :freeBpe, [:pointer], :void
  end
end
