import C "stdio.h"

func main(argc int, argv **byte) int {
	C.printf("Command line arguments are:\n")
	for i := 0; i < argc; i++ {
		C.printf("%d: %s\n", i, argv[i])
	}
	return 0
}
