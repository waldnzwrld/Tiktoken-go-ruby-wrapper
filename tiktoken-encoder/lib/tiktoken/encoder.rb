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
      # Use a release proc that captures only the pointer value, not self
      # This avoids the closure bug where self would never be GC'd
      ObjectSpace.define_finalizer(self, self.class.release_encoder_proc(@encoder))
    end

    # Creates a release proc that only captures the pointer value
    # This is necessary to avoid preventing GC of the Encoder instance
    def self.release_encoder_proc(encoder_ptr)
      proc { freeBpe(encoder_ptr) }
    end

    def encode_string(text)
      tokens = self.class.encode(@encoder, text, @token_size)
      size = @token_size.read_long
      result = tokens.read_array_of_int(size)
      # Free the C-allocated memory
      self.class.free_memory(tokens)
      [size, result]
    rescue StandardError => e
      # free_encoder on the encoder if the encoder is allocated
      free_encoder if @encoder != FFI::Pointer::NULL
      raise e
    end

    def decode_tokens(tokens, size)
      # takes an array of tokens gets the length of the array and calls the decode function
      # returns a string
      raise StandardError, 'size must be an integer' unless size.is_a?(Integer)

      token_ptr = tokens.is_a?(Array) ? convert_tokens_to_pointer(tokens) : tokens
      # Create an output pointer for the decoded string
      out_str_ptr = FFI::MemoryPointer.new(:pointer)
      self.class.decode(@encoder, token_ptr, size, out_str_ptr)

      # Read the C string from the output pointer
      c_str_ptr = out_str_ptr.read_pointer
      result = c_str_ptr.read_string

      # Free the C-allocated string memory
      self.class.free_memory(c_str_ptr)
      # Free the token pointer if we created it
      token_ptr.free if tokens.is_a?(Array)

      result
    rescue StandardError => e
      # free_encoder on the pointer if the pointer is allocated
      free_encoder if @encoder != FFI::Pointer::NULL
      raise e
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
    attach_function :decode, %i[pointer pointer long pointer], :int
    attach_function :freeBpe, [:pointer], :void
    attach_function :free_memory, :freeMemory, [:pointer], :void
    attach_function :startMemoryProfile, [], :void
    attach_function :stopMemoryProfile, [], :void

    def self.profile_memory
      startMemoryProfile
      yield
      stopMemoryProfile
    end
  end
end
