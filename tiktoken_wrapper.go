package main

/*

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
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
	tke, err := tiktoken.GetEncoding(C.GoString(encoding))
	if err != nil {
		fmt.Println(err)
		return uintptr(0)
	}

	ptr := unsafe.Pointer(tke)

	if ptr == nil {
		return uintptr(0)
	}

	tiktokenMap[uintptr(ptr)] = tke

	return uintptr(ptr)
}

//export getEncodingForModel
func getEncodingForModel(model *C.char) uintptr {
	// tiktoken.SetBpeLoader(tiktoken.NewDefaultBpeLoader())
	tke, err := tiktoken.EncodingForModel(C.GoString(model))
	if err != nil {
		fmt.Println(err)
		return uintptr(0)
	}

	ptr := unsafe.Pointer(tke)

	if ptr == nil {
		return uintptr(0)
	}

	tiktokenMap[uintptr(ptr)] = tke

	return uintptr(ptr)
}

//export encode
func encode(ptr uintptr, text *C.char) C.struct_ArrayAndSize {
	// convert unsafe.Pointer to *tiktoken.Tiktoken
	pointer := *(*tiktoken.Tiktoken)(unsafe.Pointer(ptr))
	// get the referenced struct
	encoder := &pointer
	// encode
	token := encoder.Encode(C.GoString(text), nil, nil)
	// return the token and size
	size := C.int(len(token))
	cArray := C.malloc(C.size_t(size) * C.sizeof_int)

	// Copy the integers to the C array
	for i, v := range token {
		(*(*C.int)(unsafe.Pointer(uintptr(cArray) + uintptr(i)*C.sizeof_int))) = C.int(v)
	}
	return C.struct_ArrayAndSize{Array: (*C.int)(cArray), Size: C.size_t(size)}
}

//export decode
func decode(ptr uintptr, tokenArr *C.int, size C.int) *C.char {
	tokens := make([]int, size)
	for i := 0; i < int(size); i++ {
		tokens[i] = int(*(*C.int)(unsafe.Pointer(uintptr(unsafe.Pointer(tokenArr)) + uintptr(i)*unsafe.Sizeof(*tokenArr))))
	}

	pointer := *(*tiktoken.Tiktoken)(unsafe.Pointer(ptr))
	// get the referenced struct
	encoder := &pointer

	text := encoder.Decode(tokens)

	return C.CString(text)

}

var tiktokenMap = make(map[uintptr]*tiktoken.Tiktoken)

//export freeBpe
func freeBpe(ptr uintptr) {
	_, ok := tiktokenMap[ptr]
	if !ok {
		fmt.Printf("Invalid pointer: %p\n", ptr)
		return
	}
	// Free any resources associated with tke

	delete(tiktokenMap, ptr)

}

func main() {}
