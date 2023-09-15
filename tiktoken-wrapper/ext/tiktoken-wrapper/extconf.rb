require "fileutils"


def run_command(command)
  puts "Running command: #{command}"
  system(command)
end


# Run 'go mod tidy'
run_command("go mod tidy")

# build the C extension
run_command("go build -buildmode=c-shared -o libttwrapper.so tiktoken_wrapper.go")
