# Tiktoken-go-wrapper-gem
A Ruby gem wrapper around the tiktoken-go package

`tiktoken_wrapper.go` exposes the tiktoken interface in a C compatible wrapper.

After making changes to `tiktoken_wrapper.go` the command: `go build -buildmode=c-shared -o libttwrapper.so tiktoken_wrapper.go` generates a C library that can be imported in Ruby through Fiddle::Library.

The go functions are attached as private to allow for error handling on the Ruby side.

A set of Ruby functions are exposed for those purposes.

# Setup
In a terminal execute `script/setup` this should install any needed go deps for development, and build the C lib needed for the gem to function.

# Building for manual testing
If you make changes to the tiktoken_wrapper.go file, you will need to execute `script/build-clib` to generate the necessary libraries used by the Ruby gem

For changes to the `lib/tiktoken/encoder.rb` file you will not need to make any modifications. You can simply reference the module and call a function.


# Building the gem
In a terminal execute `script/build` this will build the C libraries that are needed as well as the Gemfile.
If you are updating this gem please be certain to update the version inside of the gemspec.

# Testing

In a terminal execute `script/function-test`

tests are in the test/test/tiktoken dir

# Profiling the approach

In a terminal execute `script/memory-profile`

This will perform the following benchmarks
## Go Profiling
profile_test.rb#L49 contains a call to a `goProfile` function in the cgo lib tiktoken_wrapper.go#L120.
This runs all of the exposed tiktoken functions including a run of `encode` over 1000 executions.
This is called on benchmark_test.rb#L64
The output is written to a pprof file, which can be opened using `pprof -http=localhost:6600 mem.pprof`

## C profiling
test/cgo_profile.c is compiled and executed it runs the same `goProfile` function mentioned above using either `leaks` on MacOs
or `heaptrack` either locally or in a docker container.

## Ruby Profiling
profile_test.rb#L37 wraps an `encode` block run 50000 times in  MemoryProfiler calls that describe object allocation
and overall memory usage.

## Long testing
profile_test.rb includes a `test_over_time` method that takes a block and repeats the block 100 times.
It could be used to test looooong chains of encoding or decoding over time to see if there is a memory leak if
need be. I have used it before to verify my approach but did not include it in scripting due to the efficacy of the above profiling.



# Timing the approach

In a terminal execute `script/benchmark`

benchmark_test.rb#L25 includes a 50000 execution block of calls to Encode with timings.


# CI

CI will build the gem and run tests against the gem in a docker container.
It also Lints the Go and Ruby code

There is also a set of regression tests to make sure that latency is not increased and that memory leaks are vetted.
