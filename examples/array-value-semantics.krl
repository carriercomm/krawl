import C "stdio.h"

func print_array(a [5]int) {
	for i := 0; i < 5; i++ {
		C.printf("%d\n", a[i])
	}
}

func mutate_array(a [5]int) {
	C.printf("in mutator, before:\n")
	print_array(a)
	for i := 0; i < 5; i++ {
		a[i] *= 1000
	}
	C.printf("in mutator, after:\n")
	print_array(a)
}

func main(argc int, argv **byte) int {
	var a []int = {1, 2, 3, 4, 5}
	C.printf("before mutation:\n")
	print_array(a)

	mutate_array(a)

	C.printf("after mutation:\n")
	print_array(a)
	return 0
}
