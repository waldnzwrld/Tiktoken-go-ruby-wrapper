package main

/*
// void f(void* ptr) {}

#include <stdlib.h>
struct ArrayAndSize{
    int* Array;
    size_t Size;
};

*/
import "C"
import (
	"fmt"
	"unsafe"

	"github.com/pkoukk/tiktoken-go"
)

//export getEncoding
func getEncoding(encoding *C.char) uintptr {
	// tiktoken.SetBpeLoader(tiktoken.NewDefaultBpeLoader())
	fmt.Printf("setting up the Tiktoken struct in memory")
	tke, err := tiktoken.GetEncoding(C.GoString(encoding))
	if err != nil {
		fmt.Println(err)
		return uintptr(0)
	}

	fmt.Printf("Tiktoken: %v\n", tke)
	ptr := unsafe.Pointer(tke)
	fmt.Printf("Unsafe pointer to Tiktoken: %v\n", ptr)

	if ptr == nil {
		return uintptr(0)
	}

	return uintptr(ptr)
}

//export getEncodingForModel
func getEncodingForModel(model *C.char) uintptr {
	// tiktoken.SetBpeLoader(tiktoken.NewDefaultBpeLoader())
	fmt.Printf("setting up the Tiktoken struct in memory")
	tke, err := tiktoken.EncodingForModel(C.GoString(model))
	if err != nil {
		fmt.Println(err)
		return uintptr(0)
	}

	fmt.Printf("Tiktoken: %v\n", tke)
	ptr := unsafe.Pointer(tke)
	fmt.Printf("Unsafe pointer to Tiktoken: %v\n", ptr)

	if ptr == nil {
		return uintptr(0)
	}

	return uintptr(ptr)
}

//export encode
func encode(ptr uintptr, text *C.char) C.struct_ArrayAndSize {
	fmt.Printf("begin encoding text: %v\n", C.GoString(text))
	// convert unsafe.Pointer to *tiktoken.Tiktoken
	fmt.Printf("converting C pointer to TikToken pointer\n")
	fmt.Printf("ptr: %v\n", ptr)
	pointer := *(*tiktoken.Tiktoken)(unsafe.Pointer(ptr))
	fmt.Printf("pointer: %v\n", pointer)
	// get the referenced struct
	encoder := &pointer
	fmt.Printf("Tiktoken struct rereferenced: %v\n", encoder)
	// encode
	token := encoder.Encode(C.GoString(text), nil, nil)
	fmt.Printf("encoded token: %v\n", token)
	// return the token and size
	size := C.int(len(token))
	cArray := C.malloc(C.size_t(size) * C.sizeof_int)

	// Copy the integers to the C array
	for i, v := range token {
		(*(*C.int)(unsafe.Pointer(uintptr(cArray) + uintptr(i)*C.sizeof_int))) = C.int(v)
	}
	fmt.Printf("returning C array and size\n")
	return C.struct_ArrayAndSize{Array: (*C.int)(cArray), Size: C.size_t(size)}
}

//export decode
// func decode(ptr uintptr, tokens *C.int) *C.char {
// 	pointer := *(*tiktoken.Tiktoken)(unsafe.Pointer(ptr))
// 	fmt.Printf("pointer: %v\n", pointer)
// 	// get the referenced struct
// 	encoder := &pointer
// 	fmt.Printf("Tiktoken struct rereferenced: %v\n", encoder)

// 	text :=encoder.Decode(tokens)

// }

func main() {}
