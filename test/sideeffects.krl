import "stdio.h"

func get0() int { stdio.printf("in get0\n"); return 0 }
func get1() int { stdio.printf("in get1\n"); return 1 }
func get2() int { stdio.printf("in get2\n"); return 2 }
func get3() int { stdio.printf("in get3\n"); return 3 }
func get4() int { stdio.printf("in get4\n"); return 4 }
func get5() int { stdio.printf("in get5\n"); return 5 }
func getargs0(a, b int) int { stdio.printf("in getargs0\n"); return 0 }
func getargs1(a, b int) int { stdio.printf("in getargs1\n"); return 1 }

func main(argc int, argv **byte) int {
	a := get1() + get2() * get3()
	stdio.printf("%d\n", a)

	var pair []int = {15, 30}
	pair[get0()], pair[get1()] = pair[getargs1(get2(), get3())], pair[getargs0(get4(), get5())]
	stdio.printf("%d %d\n", pair[0], pair[1])
	return 0
}
