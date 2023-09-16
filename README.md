# Tiktoken-go-ruby-wrapper
A Ruby gem wrapper around the tiktoken-go package

`tiktoken_wrapper.go` exposes the tiktoken interface in a C compatible wrapper.

After making changes to `tiktoken_wrapper.go` the command: `go build -buildmode=c-shared -o libttwrapper.so tiktoken_wrapper.go` generates a C library that can be imported in Ruby through FFI::Library.

The go functions are attached as private to allow for error handling on the Ruby side.

A set of Ruby functions are exposed for those purposes.

# Setup
In a terminal execute `script/setup` this should install any needed go deps for development, and build the C lib needed for the gem to function.

# Profiling the approach

in a terminal execute `script/run-benchmarks`

This will perform the following benchmarks
## Go Profiling
encoder.rb#L71 contains a call to a `goProfile` function in the cgo lib tiktoken_wrapper.go#L120.
This runs all of the exposed tiktoken functions including a run of `encode` over 1000 executions.
The output is written to a pprof file, which can be opened using `pprof -http=localhost:6600 mem.pprof`

## Ruby Profiling
benchmark.rb#L51 wraps an `encode` block run 50000 times in  MemoryProfiler calls that describe object allocation
and overall memory usage.

benchmark.rb#L47 includes a 50000 execution block of calls to Encode with timings.
