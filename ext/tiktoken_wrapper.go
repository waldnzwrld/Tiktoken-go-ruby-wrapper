package main

/*

#include <stdlib.h>

*/
import "C"
import (
	"fmt"
	"os"
	"runtime/pprof"
	"sync"
	"unsafe"

	"github.com/pkoukk/tiktoken-go"
	tiktoken_loader "github.com/pkoukk/tiktoken-go-loader"
)

// set a global map to store references to the tiktoken structs
// so that they don't get garbage collected
// this works because the script is loaded by Fiddle::Library
// and stored in memory
// GC is run for the entire process once the ruby class
// is no longer in use
var tiktokenMap = make(map[uintptr]*tiktoken.Tiktoken)
var mutexLock = sync.RWMutex{}

//export getEncoding
func getEncoding(encoding *C.char) uintptr {
	tiktoken.SetBpeLoader(tiktoken_loader.NewOfflineLoader())
	tke, err := tiktoken.GetEncoding(C.GoString(encoding))
	// if the encoding is not found check to see if a model was passed
	if err != nil {
		tke, err = tiktoken.EncodingForModel(C.GoString(encoding))
		if err != nil {
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
	mutexLock.Lock()
	tiktokenMap[uintptr(ptr)] = tke
	mutexLock.Unlock()
	// return the pointer as a uintptr which is read as an Fiddle::Pointer
	return uintptr(ptr)
}

//export encode
func encode(ptr uintptr, text *C.char, numTokens *C.long) *C.int {
	// numTokens is an empty Fiddle::Pointer
	// which will be used to store the number of tokens

	// get the referenced pointer
	// from the inmemory map
	// to the *tiktoken.Tiktoken encoder struct
	mutexLock.Lock()
	pointer := *tiktokenMap[ptr]
	mutexLock.Unlock()
	// get the referenced struct
	encoder := &pointer
	// encode
	token := encoder.Encode(C.GoString(text), nil, nil)

	size := len(token)
	if numTokens != nil {
		// set the Fiddle::Pointer value to size
		*numTokens = C.long(size)
	}

	// Allocate a C array of the correct size
	cArray := C.malloc(C.size_t(size) * C.sizeof_int)

	// if the malloc fails try again
	if cArray == nil {
		cArray = C.malloc(C.size_t(size) * C.sizeof_int)
	}

	// if the malloc fails again raise an error and fail
	if cArray == nil {
		return nil
	}

	// Copy the integers to the C array
	for i, v := range token {
		(*(*C.int)(unsafe.Pointer(uintptr(cArray) + uintptr(i)*C.sizeof_int))) = C.int(v)
	}

	// Return a pointer to the C array which will be read as an Fiddle::Pointer
	return (*C.int)(cArray)
}

//export freeTokensArray
func freeTokensArray(tokens *C.int) {
	C.free(unsafe.Pointer(tokens))
}

//export decode
func decode(ptr uintptr, tokenArr *C.int, size C.long) unsafe.Pointer {
	// Here an Fiddle::Pointer tokenArr is passed in as a uintptr
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
	mutexLock.Lock()
	pointer := *tiktokenMap[ptr]
	mutexLock.Unlock()
	// get the referenced struct
	encoder := &pointer

	text := encoder.Decode(tokens)
	// return a pointer to the C string so that we can dealloc later
	return unsafe.Pointer(C.CString(text))
}

//export freeText
func freeText(text unsafe.Pointer) {
	cstr := (*C.char)(text)
	C.free(unsafe.Pointer(cstr))
}

//export freeBpe
func freeBpe(ptr uintptr) {
	// This frees the reference to the tiktoken struct
	// so that it can be safely garbage collected by go runtime
	_, ok := tiktokenMap[ptr]
	if !ok {
		return
	}

	// delete the reference to the tiktoken struct
	mutexLock.Lock()
	delete(tiktokenMap, ptr)
	mutexLock.Unlock()
}

//export goProfile
func goProfile(model *C.char, text *C.char, numTokens *C.long, runs C.int, extProfile C.int) {
	// get the encoding as a uintptr
	tke := getEncoding(model)
	// initialise an empty pointer for tokens to be stored in
	var tokens *C.int

	// encode text runs number of times
	// passing the uintptr to the tiktoken struct
	// and the text to be encoded
	// as well as an empty Fiddle::Pointer with C.long type
	ops := int(runs)
	if ops == 0 {
		ops = 1000
	}
	if ops > 15000 {
		ops = 15000
	}
	for i := 0; i < ops; i++ {
		tokens = encode(tke, text, numTokens)
		// free tokens (this would normally happen in Ruby code lib/tiktoken.rb#L32)
		freeTokensArray(tokens)
	}

	tokens = encode(tke, text, numTokens)
	// Read the long value from the numTokens pointer
	size := *numTokens

	cstr := decode(tke, tokens, size)
	// free text, this would normally happen durng GC in Ruby
	freeText(cstr)
	// free tokens (this would normally happen in Ruby code lib/tiktoken.rb#L32)
	freeTokensArray(tokens)
	// free the tiktoken struct
	freeBpe(tke)

	// if extProfile is false
	// write the heap profile to a file
	// this can be read with pprof
	// pprof -web localhost:6000 mem.pprof
	if extProfile == 0 {
		f, _ := os.Create("mem.pprof")
		err := pprof.WriteHeapProfile(f)
		if err != nil {
			fmt.Printf("Error writing heap profile: %v\n", err)
		}
		f.Close()
	}
}

func main() {}
