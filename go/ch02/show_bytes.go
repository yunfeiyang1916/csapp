package main

import (
	"fmt"
	"unsafe"
)

// 输出字节序
func showBytes(val unsafe.Pointer, size uintptr) {
	for i := 0; i < int(size); i++ {
		v := *(*byte)(unsafe.Pointer(uintptr(val) + uintptr(i)))
		fmt.Printf("%.2x ", v)
	}
	fmt.Println()
	for i := 0; i < int(size); i++ {
		v := *(*byte)(unsafe.Pointer(uintptr(val) + uintptr(i)))
		fmt.Printf("%.8b ", v)
	}
	fmt.Println()
}

func showInt32(val int32) {
	showBytes(unsafe.Pointer(&val), unsafe.Sizeof(val))
}

func showInt(val int) {
	showBytes(unsafe.Pointer(&val), unsafe.Sizeof(val))
}

func showFloat32(val float32) {
	showBytes(unsafe.Pointer(&val), unsafe.Sizeof(val))
}

func showPointer(val *int) {
	showBytes(unsafe.Pointer(&val), unsafe.Sizeof(val))
}

func showStr(val string) {
	showBytes(unsafe.Pointer(&val), uintptr(len(val)))
}

// 测试输出字节序
func testShowBytes() {
	val := 12345
	showInt32(int32(val))
	showInt(val)
	showFloat32(float32(val))
	showPointer(&val)
	fmt.Println()
	str := "abcdef"
	showStr(str)
}

// 测试补码
func testT() {
	var x int16 = -12345
	mx := uint16(x)
	fmt.Printf("x=%d\n", x)
	showBytes(unsafe.Pointer(&x), unsafe.Sizeof(x))
	fmt.Printf("mx=%d\n", mx)
	showBytes(unsafe.Pointer(&mx), unsafe.Sizeof(mx))
}

func main() {
	// testShowBytes()
	testT()
}
