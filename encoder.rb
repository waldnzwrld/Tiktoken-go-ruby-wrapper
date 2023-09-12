require 'ffi'
require 'benchmark'
module Encoder
  extend FFI::Library
  ffi_lib File.expand_path("./libttwrapper.so", File.dirname(__FILE__))

  class ArrayAndSize < FFI::Struct
    layout :array, :pointer,
           :size, :size_t
  end

  def self.get_encoding(encoding:)
    ptr = Encoder.getEncoding(encoding)
    # Convert the uintptr to a C pointer
    if ptr.null?
        puts "ptr is null"
    else
        FFI::Pointer.new(ptr)
    end
  end

  def self.get_encoding_for_model(model:)
    ptr = Encoder.getEncodingForModel(model)
    # Convert the uintptr to a C pointer
    if ptr.null?
        puts "ptr is null"
    else
        FFI::Pointer.new(ptr)
    end
  end

  def self.encode_string(pointer:, text:)
    begin
      tokens_and_size = Encoder.encode(pointer, text)

      # Access the array pointer and size from the struct
      tokens = tokens_and_size[:array].read_array_of_int(tokens_and_size[:size])
      size = tokens_and_size[:size]

      tokens
    rescue => e
        puts "error: #{e}"
        # freeBpe on the pointer if the pointer is allocated
        Encoder.freeBpe(pointer) if pointer
    end
  end

  def self.decode_tokens(pointer:, tokens:)
    # takes an array of tokens gets the length of the array and calls the decode function
    # returns a string
    # Allocate memory for the array in Go
    begin
      size = tokens.size
      c_array = FFI::MemoryPointer.new(:int, size)
      c_array.write_array_of_int(tokens)
      text = Encoder.decode(pointer, c_array, size)

      c_array.free
      text
    rescue => e
        puts "error: #{e}"
        # freeBpe on the pointer if the pointer is allocated
        Encoder.freeBpe(pointer) if pointer
    end
  end

  private

  attach_function :getEncoding, [:string ], :pointer
  attach_function :getEncodingForModel, [:string], :pointer
  attach_function :encode , [:pointer, :string], ArrayAndSize.by_value
  attach_function :decode, [:pointer, :pointer, :int], :string
  attach_function :freeBpe, [:pointer], :void
end

test_string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

# make a string that is test string repeated 10 times
four_thou_string = test_string * 10

c_ptr = Encoder.get_encoding(encoding: "cl100k_base")

# benchmark the next function over 1000 calls
time = Benchmark.realtime do
  1000.times do
    Encoder.encode_string(pointer: c_ptr, text: four_thou_string)
  end
end

puts "Total time taken for 1000 iterations: #{time} seconds"
puts "Average time per iteration: #{time / 1000} seconds"

Encoder.freeBpe(c_ptr)

m_ptr = Encoder.get_encoding_for_model(model: "gpt-3.5-turbo")

tokens = Encoder.encode_string(pointer: m_ptr, text: "Big cats like big boxes")

value = Encoder.decode_tokens(pointer: m_ptr, tokens: tokens)

Encoder.freeBpe(m_ptr)
