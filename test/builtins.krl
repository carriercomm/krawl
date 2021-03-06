import "stdio.h"

type Dummy struct {
	a, b, c int
	d *Dummy
	e double
}

func main(argc int, argv **byte) int {
	var d Dummy

	stdio.printf("sizeof(type Dummy) == %d\n", sizeof(Dummy))
	stdio.printf("sizeof(type [3]Dummy) == %d\n", sizeof([3]Dummy))
	stdio.printf("sizeof(d) == %d\n", sizeof(d))
	stdio.printf("sizeof(&d) == %d\n", sizeof(&d))
	return 0
}
