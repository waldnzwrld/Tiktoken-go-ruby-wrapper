package main

/*

#include <stdlib.h>

struct ArrayAndSize{
    int* Array;
    size_t Size;
};

*/
import "C"
import (
	"fmt"
	"net/http"
	_ "net/http/pprof"
	"os"
	"runtime/pprof"
	"unsafe"

	"github.com/pkoukk/tiktoken-go"
)

//export getEncoding
func getEncoding(encoding *C.char) uintptr {

	tiktoken.SetBpeLoader(tiktoken.NewDefaultBpeLoader())
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
func encode(ptr uintptr, text *C.char, numTokens *C.long) *C.int {
	// convert unsafe.Pointer to *tiktoken.Tiktoken
	pointer := *(*tiktoken.Tiktoken)(unsafe.Pointer(ptr))
	// get the referenced struct
	encoder := &pointer
	// encode
	token := encoder.EncodeOrdinary(C.GoString(text))
	// return the token and size
	size := len(token)
	if numTokens != nil {
		*numTokens = C.long(size)
	}

	cArray := C.malloc(C.size_t(size) * C.sizeof_int)

	// Copy the integers to the C array
	for i, v := range token {
		(*(*C.int)(unsafe.Pointer(uintptr(cArray) + uintptr(i)*C.sizeof_int))) = C.int(v)
	}
	return (*C.int)(cArray)
}

//export decode
func decode(ptr uintptr, tokenArr uintptr, size C.long) *C.char {
	tokens := make([]int, size)
	for i := 0; i < int(size); i++ {
		tokens[i] = int(*(*C.int)(unsafe.Pointer(tokenArr + uintptr(i)*C.sizeof_int)))
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

//export fullRun
func fullRun(model *C.char, text *C.char, numTokens *C.long) {
	go func() {
		fmt.Println(http.ListenAndServe("localhost:6060", nil))
	}()

	tke := getEncoding(model)
	// encode text 1000 times
	for i := 0; i < 1000; i++ {
		encode(tke, text, numTokens)
	}
	tokens := encode(tke, text, numTokens)
	size := *numTokens

	decode(tke, uintptr(unsafe.Pointer(tokens)), size)

	freeBpe(tke)

	f, _ := os.Create("mem.pprof")
	pprof.WriteHeapProfile(f)
	f.Close()
}

func main() {}
