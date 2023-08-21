require 'ffi'
module Example
  extend FFI::Library
  ffi_lib File.expand_path("./libttwrapper.so", File.dirname(__FILE__))

  class ArrayAndSize < FFI::Struct
    layout :array, :pointer,
           :size, :size_t
  end

  attach_function :getEncoding, [:string ], :pointer
#   attach_function :freeEncoding, [:pointer], :void
  attach_function :encode , [:pointer, :string], ArrayAndSize.by_value
end

# test it out
p "get encoding for cl100k_base"
ptr = Example.getEncoding("cl100k_base")
# Convert the uintptr to a C pointer
if ptr.null?
    puts "ptr is null"
else
    p "ptr is not null"
    c_ptr = FFI::Pointer.new(ptr)
end

# Call the function

begin
  p "call encode with string hello"
  tokens_and_size = Example.encode(c_ptr, "I love to eat potatoes, they're fantastic")

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
