package main

/*

#include <stdlib.h>

*/
import "C"
import (
	"fmt"
	"os"
	"runtime"
	"runtime/pprof"
	"unsafe"

	"github.com/pkoukk/tiktoken-go"
)

// set a global map to store references to the tiktoken structs
// so that they don't get garbage collected
// this works because the script is loaded by FFI::Library
// and stored in memory
// GC is run for the entire process once the ruby class
// is no longer in use
var tiktokenMap = make(map[uintptr]*tiktoken.Tiktoken)

//export getEncoding
func getEncoding(encoding *C.char) uintptr {
	tke, err := tiktoken.GetEncoding(C.GoString(encoding))
	// if the encoding is not found check to see if a model was passed
	if err != nil {
		tke, err = tiktoken.EncodingForModel(C.GoString(encoding))
		if err != nil {
			fmt.Println(err)
			return uintptr(0)
		}
	}

	// since we cannot directly convert a go pointer to a C pointer
	// we need to convert it to an unsafe pointer first
	ptr := unsafe.Pointer(tke)

	// if the pointer is nil, return a pointer to 0
	if ptr == nil {
		return uintptr(0)
	}

	// this stores a reference to the tiktoken struct
	// so that it doesn't get garbage collected
	tiktokenMap[uintptr(ptr)] = tke

	// return the pointer as a uintptr which is read as an FFI::Pointer
	return uintptr(ptr)
}

//export encode
func encode(ptr uintptr, text *C.char, numTokens *C.long) *C.int {
	// numTokens is an empty FFI::MemoryPointer
	// which will be used to store the number of tokens

	// get the referenced pointer
	// from the inmemory map
	// to the *tiktoken.Tiktoken encoder struct
	pointer := *tiktokenMap[ptr]
	// get the referenced struct
	encoder := &pointer
	// encode
	token := encoder.Encode(C.GoString(text), nil, nil)

	size := len(token)
	if numTokens != nil {
		// set the FFI::MemoryPointer value to size
		*numTokens = C.long(size)
	}

	// Allocate a C array of the correct size
	cArray := C.malloc(C.size_t(size) * C.sizeof_int)

	// Copy the integers to the C array
	for i, v := range token {
		(*(*C.int)(unsafe.Pointer(uintptr(cArray) + uintptr(i)*C.sizeof_int))) = C.int(v)
	}

	// Return a pointer to the C array which will be read as an FFI::Pointer
	return (*C.int)(cArray)
}

//export decode
func decode(ptr uintptr, tokenArr *C.int, size C.long) *C.char {
	// Here an FFI::Pointer tokenArr is passed in as a uintptr
	// and then converted to a C array of ints
	// This is probably the most difficult part of the code to read
	// let's break it down
	// in order to perform pointer arithmetic on the C array referenced by a *C.int
	// we first need to convert it to an unsafe.Pointer then a uintptr
	// then in order to get the offest bytes needed to access the correct element
	// we multiply the index by the size of an int
	// Finally we convert the resulting uintptr back to a *C.int through an unsafe.Pointer
	// and dereference it to get the value
	// This is done for each element in the array
	// Long story short although this seems complex it is a necessary conversion.
	// Since the unsafe.Pointers are used immediately GC is not an issue

	tokens := make([]int, size)
	for i := 0; i < int(size); i++ {
		tokens[i] = int(*(*C.int)(unsafe.Pointer(uintptr(unsafe.Pointer(tokenArr)) + uintptr(i)*C.sizeof_int)))
	}

	// get the referenced pointer
	// from the inmemory map
	// to the *tiktoken.Tiktoken encoder struct
	pointer := *tiktokenMap[ptr]
	// get the referenced struct
	encoder := &pointer

	text := encoder.Decode(tokens)
	// return a C string
	return C.CString(text)
}

//export freeBpe
func freeBpe(ptr uintptr) {
	// This frees the reference to the tiktoken struct
	// so that it can be safely garbage collected by go runtime
	_, ok := tiktokenMap[ptr]
	if !ok {
		runtime.GC()
		return
	}

	// delete the reference to the tiktoken struct
	delete(tiktokenMap, ptr)
	runtime.GC()
}

//export goProfile
func goProfile(model *C.char, text *C.char, numTokens *C.long, runs C.int) {
	// get the encoding as a uintptr
	tke := getEncoding(model)
	// initialise an empty pointer for tokens to be stored in
	var tokens *C.int

	// encode text runs number of times
	// passing the uintptr to the tiktoken struct
	// and the text to be encoded
	// as well as an empty FFI::MemoryPointer with C.long type
	ops := int(runs)
	if ops == 0 {
		ops = 1000
	}
	if ops > 15000 {
		ops = 15000
	}
	for i := 0; i < ops; i++ {
		tokens = encode(tke, text, numTokens)
	}

	tokens = encode(tke, text, numTokens)
	// Read the long value from the numTokens pointer
	size := *numTokens

	decode(tke, tokens, size)
	// This usually happens in Ruby when the GC runs
	// Since tokens is a pointer referenced there
	C.free(unsafe.Pointer(tokens))

	// free the tiktoken struct
	freeBpe(tke)

	// write the heap profile to a file
	// this can be read with pprof
	// pprof -web localhost:6000 mem.pprof
	f, _ := os.Create("mem.pprof")
	pprof.WriteHeapProfile(f)
	f.Close()
}

func main() {}
