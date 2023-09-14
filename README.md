# Tiktoken-go-ruby-wrapper
A Ruby gem wrapper around the tiktoken-go package

`tiktoken_wrapper.go` exposes the tiktoken interface in a C compatible wrapper.

After making changes to `tiktoken_wrapper.go` the command: `go build -buildmode=c-shared -o libttwrapper.so tiktoken_wrapper.go` generates a C library that can be imported in Ruby through FFI::Library

The go functions are attached as private to allow for error handling on the Ruby side.

A set of Ruby functions are exposed for those purposes.

# Profiling the approach
## Go Profiling
encoder.rb#L73 contains a call to a `fullRun` function in the cgo lib tiktoken_wrapper.go#L120.
This runs all of the exposed tiktoken functions including a run of `encode` over 1000 executions.
The output is written to a pprof file, which can be opened using `pprof -http=localhost:6600 mem.pprof`

## Ruby Profiling
encoder.rb#L76 and encoder.rb#L103-104 include MemoryProfiler calls that descirbe object allocation
and overall memory usage. Uncomment those lines to generate a memory profile

encoder.rb#L83-89 include a 50000 execution block of calls to Encode. Uncomment these lines to discern overall timing
and avg timing per operation.
