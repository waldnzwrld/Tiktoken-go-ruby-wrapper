require 'ffi'
module Encoder
  extend FFI::Library
  ffi_lib File.expand_path("./libttwrapper.so", File.dirname(__FILE__))

  class ArrayAndSize < FFI::Struct
    layout :array, :pointer,
           :size, :size_t
  end

  def self.get_encoding(encoding:)
    p "get encoding for #{encoding}"
    ptr = Encoder.getEncoding(encoding)
    # Convert the uintptr to a C pointer
    if ptr.null?
        puts "ptr is null"
    else
        p "ptr is not null"
        FFI::Pointer.new(ptr)
    end
  end

  def self.get_encoding_for_model(model:)
    p "get encoding for #{model}"
    ptr = Encoder.getEncodingForModel(model)
    # Convert the uintptr to a C pointer
    if ptr.null?
        puts "ptr is null"
    else
        p "ptr is not null"
        FFI::Pointer.new(ptr)
    end
  end

  def self.encode_string(pointer:, text:)
    begin
      p "call encode with string #{text}"
      tokens_and_size = Encoder.encode(pointer, text)

      # Access the array pointer and size from the struct
      array = tokens_and_size[:array].read_array_of_int(tokens_and_size[:size])
      size = tokens_and_size[:size]
      # Print the array elements
      puts "Tokens: #{array.join(', ')}"
      puts "Size: #{size}"

      p "free the allocated memory"
    #   Example.free(c_ptr)
    #   Example.free(tokens_and_size[:array])

    rescue => e
        puts "error: #{e}"
        # Example.free(c_ptr)
        # Example.free(tokens_and_size[:array]) if tokens_and_size
    end
  end

  private

  attach_function :getEncoding, [:string ], :pointer
  attach_function :getEncodingForModel, [:string], :pointer
  attach_function :encode , [:pointer, :string], ArrayAndSize.by_value
end



# Call the function
c_ptr = Encoder.get_encoding(encoding: "cl100k_base")

Encoder.encode_string(pointer: c_ptr, text: "Smoked cheese is the best of cheese")

m_ptr = Encoder.get_encoding_for_model(model: "gpt-3.5-turbo")

Encoder.encode_string(pointer: m_ptr, text: "Big cats like big boxes")
