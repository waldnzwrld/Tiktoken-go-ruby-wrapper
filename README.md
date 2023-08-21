# Tiktoken-go-ruby-wrapper
A Ruby gem wrapper around the tiktoken-go pacakge


`tiktoken_wrapper.go` exposes the tiktoken interface in a C compatible wrapper. 

After making changes to `tiktoken_wrapper.go` the command: `go build -buildmode=c-shared -o libttwrapper.so tiktoken_wrapper.go` generates a C library that can be imported in Ruby through FFI::Library

The go functions are attached as private to allow for error handling on the Ruby side. 

A set of Ruby functions are exposed for those purposes. 

THis is still very beta, and I would like to vet the memory implications involved with the amount of unsafe pointers in play and pointer conversion between C and Go
