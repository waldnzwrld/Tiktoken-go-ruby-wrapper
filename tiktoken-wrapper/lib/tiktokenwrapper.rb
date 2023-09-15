require 'ffi'

module TikTokenWrapper
  extend FFI::Library
  ffi_lib File.expand_path("../ext/tiktoken-wrapper/libttwrapper.so", File.dirname(__FILE__))

  def self.get_encoding(encoding:)
    ptr = self.getEncoding(encoding)
    # if ptr references 0 raise an error the encoding failed
    if ptr == FFI::Pointer::NULL
      raise "Encoding failed"
    end
    ptr
  end

  def self.get_encoding_for_model(model:)
    ptr = self.getEncodingForModel(model)
    # if ptr references 0 raise an error the encoding failed
    if ptr == FFI::Pointer::NULL
      raise "Encoding failed"
    end
    ptr
  end

  def self.encode_string(encoder:, text:, size:)
    begin
      self.encode(encoder, text, size)
    rescue => e
        puts "error: #{e}"
        # free_encoder on the encoder if the encoder is allocated
        self.free_encoder(encoder) if encoder
    end
  end

  def self.decode_tokens(encoder:, tokens:, size:)
    # takes an array of tokens gets the length of the array and calls the decode function
    # returns a string
    # Allocate memory for the array in Go
    begin
      if tokens.is_a?(FFI::Pointer)
        self.decode(encoder, tokens, size)
      elsif tokens.is_a?(Array)
        tokens.size
        tpointer = self.convertTokensToPointer(tokens: tokens)
        self.decode(encoder, tpointer, size)
      end
    rescue => e
        puts "error: #{e}"
        # free_encoder on the pointer if the pointer is allocated
        self.free_encoder(encoder) if encoder
    ensure
      tpointer.free if tpointer.is_a?(FFI::Pointer)
    end
  end

  def self.convertTokensToPointer(tokens:)
    # takes an array of tokens and converts them into a C Array
    size = tokens.size
    return FFI::MemoryPointer.new(:int, size).write_array_of_int(tokens)
  end


  def self.free_encoder(encoder:)
    self.freeBpe(encoder)
    encoder = FFI::Pointer::NULL
  end

  def self.example_run
    n = FFI::MemoryPointer.new(:long)
    c_ptr = self.get_encoding_for_model(model: "gpt-4")

    tokens = self.encode_string(encoder: c_ptr, text: "Big cats like big boxes", size: n)
    p "size #{n.read_long}"
    p "tokens #{tokens.read_array_of_int(n.read_long)}"

    value = self.decode_tokens(encoder: c_ptr, tokens: tokens, size: n.read_long)
    p "decoded tokens #{value}"

    self.free_encoder(encoder: c_ptr)
  end

  private

  attach_function :getEncoding, [:string ], :pointer
  attach_function :getEncodingForModel, [:string], :pointer
  attach_function :encode , [:pointer, :string, :pointer], :pointer
  attach_function :decode, [:pointer, :pointer, :int], :string
  attach_function :freeBpe, [:pointer], :void
  attach_function :fullRun, [:string, :string, :pointer], :void
end

# TikTokenWrapper.example_run
