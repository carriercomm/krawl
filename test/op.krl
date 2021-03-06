import "stdio.h"
import "stdlib.h"

func assert(cond bool) {
	if !cond {
		stdio.printf("fail\n")
		stdlib.exit(1)
	}
	stdio.printf("ok\n")
}

func main(argc int, argv **byte) int {
	{
		// random math ops
		a := 5
		b := 8
		c := (((((a + b) * 4) / 2 - 6) << 7) % 113) >> 2
		assert(c == 18)
	}
	{
		// unsigned overflow
		a := 245.(uint8)
		b := 15.(uint8)
		c := a + b
		assert(c == 4)
	}
	{
		// signed overflow
		a := -125.(int8)
		b := 20.(int8)
		c := a - b
		assert(c == 111)
	}
	{
		pi := 3.1415
		halfpi := pi / 2
		// TODO: varargs type promotion
		stdio.printf("%f / 2 = %f\n", pi, halfpi)
	}
	{
		// some logic operations
		a := 10 > 5 && 2 != 3 && (77-7) == 70
		b := 10 < 5 || 7 > 0
		c := a && !b
		assert(!c)
	}
	{
		ten, five := 10, 5
		A := five <= ten || ten == five
		B := five == 5 || ten == 5
		C := A && B
		assert(C)
	}
	{
		a := 50
		b := 50.(uint8)
		c := 50.(uint16)
		a, b, c = ^a, ^b, ^c
		assert(a == -51 && b == 205 && c == 65485)
	}
	return 0
}
