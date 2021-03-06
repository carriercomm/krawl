import C "stdio.h"

func fib(n int) int {
	if n < 2 {
		return n
	} else {
		return fib(n - 1) + fib(n - 2)
	}
}

func main(argc int, argv **byte) int {
	for i := 0; i < 20; i++ {
		C.printf("fib(%d): %d\n", i, fib(i))
	}
	return 0
}
