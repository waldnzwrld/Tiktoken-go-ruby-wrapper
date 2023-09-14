require 'ffi'
require 'benchmark'
require 'memory_profiler'
module Encoder
  extend FFI::Library
  ffi_lib File.expand_path("./libttwrapper.so", File.dirname(__FILE__))

  four_h_string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

  FOUR_K_STRING = four_h_string * 10

  def self.get_encoding(encoding:)
    ptr = Encoder.getEncoding(encoding)
  end

  def self.get_encoding_for_model(model:)
    ptr = Encoder.getEncodingForModel(model)
  end

  def self.encode_string(pointer:, text:, size:)
    begin
      Encoder.encode(pointer, text, size)
    rescue => e
        puts "error: #{e}"
        # freeBpe on the pointer if the pointer is allocated
        Encoder.freeBpe(pointer) if pointer
    end
  end

  def self.decode_tokens(pointer:, tokens:, size:)
    # takes an array of tokens gets the length of the array and calls the decode function
    # returns a string
    # Allocate memory for the array in Go
    begin
      if tokens.is_a?(FFI::Pointer)
        Encoder.decode(pointer, tokens, size)
      elsif tokens.is_a?(Array)
        tokens.size
        tpointer = Encoder.convertTokensToPointer(tokens: tokens)
        Encoder.decode(pointer, tpointer, size)
      end
    rescue => e
        puts "error: #{e}"
        # freeBpe on the pointer if the pointer is allocated
        Encoder.freeBpe(pointer) if pointer
    ensure
      tpointer.free if tpointer.is_a?(FFI::Pointer)
    end
  end

  def self.convertTokensToPointer(tokens:)
    # takes an array of tokens and converts them into a C Array
    size = tokens.size
    return FFI::MemoryPointer.new(:int, size).write_array_of_int(tokens)
  end

def self.profile(encoding_type:, text:)
  Encoder.fullRun(encoding_type, text)
end

  private

  attach_function :getEncoding, [:string ], :pointer
  attach_function :getEncodingForModel, [:string], :pointer
  attach_function :encode , [:pointer, :string, :pointer], :pointer
  attach_function :decode, [:pointer, :pointer, :int], :string
  attach_function :freeBpe, [:pointer], :void
  attach_function :fullRun, [:string, :string], :void
end


# uncommenting this will run 1000 the full flow in GO with 1000 iterations of encode
# Encoder.profile(encoding_type: "cl100k_base", text: Encoder::FOUR_K_STRING)

# Uncomment this line to profile the memory of the functions exposed from tiktoken.go
# MemoryProfiler.start

n = FFI::MemoryPointer.new(:long)

c_ptr = Encoder.get_encoding(encoding: "cl100k_base")

# # benchmark the next function over 50000 calls
# time = Benchmark.realtime do
#   50000.times do
#     Encoder.encode_string(pointer: c_ptr, text: Encoder::FOUR_K_STRING, size: n)
#   end
# end
# puts "Total time taken for 50000 iterations: #{time} seconds"
# puts "Average time per iteration: #{time / 50000} seconds"


tokens = Encoder.encode_string(pointer: c_ptr, text: "Big cats like big boxes", size: n)
p "size #{n.read_long}"
p "tokens #{tokens.read_array_of_int(n.read_long)}"

value = Encoder.decode_tokens(pointer: c_ptr, tokens: tokens, size: n.read_long)
p "decoded tokens #{value}"

Encoder.freeBpe(c_ptr)

# # If you uncommented the memory profiler above, uncomment this to print the report
# report = MemoryProfiler.stop
# report.pretty_print
