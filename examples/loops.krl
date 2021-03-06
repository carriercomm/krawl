import C "stdio.h"

func geti(i int) int {
	return i
}

func increment(i int) int {
	i++
	return i
}

func main(argc int, argv **byte) int {
	i := 0
	// while (1) kind of loop
	for {
		if i > 5 {
			break
		}
		C.printf("first loop i: %d\n", i)
		i++
	}

	// while (expr) kind of loop
	for i > 5 && i < 10 {
		C.printf("second loop i: %d\n", i)
		i++
	}

	// C's standard for loop
	for i := 0; i < 10; i++ {
		if i % 2 == 0 {
			// codegen check here
			i := 50
			i = 7
			continue
		}
		C.printf("third loop i: %d\n", i)
	}

	// loop with side effects in its header statements
	for i := 0; geti(i) < 5; i = increment(geti(i)) {
		C.printf("fourth loop i: %d\n", i)
	}
	return 0
}
