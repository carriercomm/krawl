import (
	"stdio.h"
	"stdlib.h"
)

func sort_ints(a, b *void) int {
	if *a.(*int) > *b.(*int) {
		return 1
	}
	return 0
}

func main(argc int, argv **byte) int {
	var a []int = {5, 3, 1, 4, 2}
	stdlib.qsort(&a, 5, 4, sort_ints)

	for i := 0; i < 5; i++ {
		stdio.printf("%d\n", a[i])
	}
	return 0
}
