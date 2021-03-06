<prefix="SDL_">
import "SDL/SDL.h"

import (
	"stdlib.h"
	"string.h"
	"stdio.h"
)

const blockSize = 15
const smallBlockSize = 9
const smallBlockOffset = (blockSize - smallBlockSize) / 2

// ████
//   ████
const specN = `
0110
1200
0000
0000
`
//   ████
// ████
const specNMirrored = `
1100
0210
0000
0000
`
//   ██
// ██████
const specT = `
0100
1210
0000
0000
`
// ████████
const specI = `
0100
0200
0100
0100
`
// ████
// ████
const specB = `
1100
1100
0000
0000
`
// ██████
// ██
const specL = `
0100
0200
0110
0000
`
// ██████
//     ██
const specLMirrored = `
0100
0200
1100
0000
`

var screen *SDL.Surface

type TetrisBlockColor struct {
	r, g, b byte
}

var specColors []TetrisBlockColor = {
	{255, 0,   0},
	{0,   255, 0},
	{100, 100, 255},
	{255, 255, 255},
	{255, 0,   255},
	{255, 255, 0},
	{0,   255, 255},
}

var specs []*byte = {
	specN,
	specNMirrored,
	specT,
	specI,
	specB,
	specL,
	specLMirrored,
}

func BlockDraw(x, y int, color TetrisBlockColor) {
	chalf := SDL.MapRGB(screen.format,
				color.r / 2, color.g / 2, color.b / 2)
	cfull := SDL.MapRGB(screen.format,
				color.r, color.g, color.b)

	r := {x, y, blockSize, blockSize}.(SDL.Rect)
	SDL.FillRect(screen, &r, chalf)

	r.x += smallBlockOffset
	r.y += smallBlockOffset
	r.w, r.h = smallBlockSize, smallBlockSize

	SDL.FillRect(screen, &r, cfull)
}

//-------------------------------------------------------------------------
// TetrisBlock
//-------------------------------------------------------------------------

type TetrisBlock struct {
	filled bool
	color TetrisBlockColor
}

func TetrisBlockDraw(b *TetrisBlock, x, y int) {
	if !b.filled {
		return
	}

	BlockDraw(x, y, b.color)
}

//-------------------------------------------------------------------------
// TetrisFigure
//-------------------------------------------------------------------------

type TetrisFigure struct {
	// center of the figure (range: 0..3 0..3)
	cx, cy int

	// position in blocks relative to top left tetris field block
	x, y int
	blocks [16]TetrisBlock
	class uint
}

func NewTetrisFigure(spec *byte, color TetrisBlockColor) (f *TetrisFigure) {
	f = stdlib.malloc(sizeof(TetrisFigure))
	string.memset(f, 0, sizeof(*f))
	f.x = 3
	f.cx = -1
	f.cy = -1

	len := string.strlen(spec)
	i := 0
	for *spec != 0 {
		switch *spec {
		case '2':
			f.cx = i % 4
			f.cy = i / 4
			fallthrough
		case '1':
			f.blocks[i].filled = true
			f.blocks[i].color = color
			fallthrough
		case '0':
			i++
		}
		spec++
	}
}

func NewRandomTetrisFigure() (f *TetrisFigure) {
	ri := stdlib.rand() % (sizeof(specs)/sizeof(specs[0]))
	f = NewTetrisFigure(specs[ri], specColors[ri])
	f.class = ri
}

func NewRandomTetrisFigureNot(templ *TetrisFigure) (f *TetrisFigure) {
	var ri int
	for {
		ri = stdlib.rand() % (sizeof(specs)/sizeof(specs[0]))
		if ri != templ.class {
			break
		}
	}

	f = NewTetrisFigure(specs[ri], specColors[ri])
	f.class = ri
}

func TetrisFigureSetColor(f *TetrisFigure, color TetrisBlockColor) {
	for i := 0; i < 16; i++ {
		if !f.blocks[i].filled {
			continue
		}

		f.blocks[i].color = color
	}
}

func RotateCWBlock(x, y int) (ox, oy int) {
	ox, oy = -y, x
}

func RotateCCWBlock(x, y int) (ox, oy int) {
	ox, oy = y, -x
}

type RotateFunc func(int, int) (int, int)


func TetrisFigureGetRotNum(f *TetrisFigure, rotate RotateFunc) int {
	const (
		Rotate1 = 1 << iota
		Rotate2
		Rotate3
		Rotate4
	)

	validrots := ^0.(uint)

	// first we rotate each visible block four times around the center
	// and checking whether each rotation is valid, then we make a list
	// of valid rotation counts (like: [3, 4] or [1, 2, 3, 4])
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			bmask := 0
			if !f.blocks[y*4 + x].filled {
				continue
			}
			bx, by := x - f.cx, y - f.cy
			for i := 0; i < 4; i++ {
				bx, by = rotate(bx, by)
				rbx, rby := f.cx + bx, f.cy + by

				// check whether a rotation is valid an record it
				if rbx >= 0 && rbx <= 4 && rby >= 0 && rby <= 4 {
					bmask |= 1 << i
				}
			}

			// apply mask to global mask
			validrots &= bmask
		}
	}

	// determine number of rotations
	if validrots & Rotate1 > 0 {
		return 1
	} else if validrots & Rotate2 > 0 {
		return 2
	} else if validrots & Rotate3 > 0 {
		return 3
	} else if validrots & Rotate4 > 0 {
		return 4
	}

	return 0
}

func TetrisFigureRotate(f *TetrisFigure, rotate RotateFunc) {
	// if there is no center, then the figure cannot be rotated
	if f.cx == -1 {
		return
	}

	rotnum := TetrisFigureGetRotNum(f, rotate)

	var newblocks [16]TetrisBlock
	for i := 0; i < 16; i++ {
		if !f.blocks[i].filled {
			continue
		}

		x := i % 4
		y := i / 4
		x, y = x - f.cx, y - f.cy

		for j := 0; j < rotnum; j++ {
			x, y = rotate(x, y)
		}

		x, y = x + f.cx, y + f.cy
		newblocks[y*4+x] = f.blocks[i]
	}

	f.blocks = newblocks
}

func TetrisFigureDraw(f *TetrisFigure, ox, oy int) {
	ox += (f.x + 1) * blockSize
	oy += f.y * blockSize
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			offset := y*4+x
			TetrisBlockDraw(&f.blocks[offset],
					ox + x * blockSize,
					oy + y * blockSize)
		}
	}
}

//-------------------------------------------------------------------------
// TetrisField
//-------------------------------------------------------------------------

type TetrisField struct	{
	width uint
	height uint
	blocks *TetrisBlock
}

func NewTetrisField(w, h int) (f *TetrisField) {
	f = stdlib.malloc(sizeof(TetrisField))
	f.width = w
	f.height = h
	f.blocks = stdlib.malloc(sizeof(TetrisBlock) * w * h)
	TetrisFieldClear(f)
}

func TetrisFieldFree(f *TetrisField) {
	stdlib.free(f.blocks)
	stdlib.free(f)
}

func TetrisFieldClear(f *TetrisField) {
	for i, n := 0, f.width * f.height; i < n; i++ {
		f.blocks[i].filled = false
	}
}

func TetrisFieldPixelsWidth(f *TetrisField) int {
	return (f.width + 2) * blockSize
}

func TetrisFieldPixelsHeight(f *TetrisField) int {
	return (f.height + 1) * blockSize
}

func TetrisFieldDraw(f *TetrisField, ox, oy int) {
	leftwallx := TetrisFieldPixelsWidth(f) - blockSize
	grey := {80, 80, 80}.(TetrisBlockColor)
	for y := 0; y < f.height + 1; y++ {
		BlockDraw(ox, oy + y * blockSize, grey)
		BlockDraw(ox + leftwallx, oy + y * blockSize, grey)
	}
	bottomwally := TetrisFieldPixelsHeight(f) - blockSize
	for x := 0; x < f.width; x++ {
		BlockDraw(ox + (x + 1) * blockSize, oy + bottomwally, grey)
	}

	ox += blockSize
	for y := 0; y < f.height; y++ {
		for x := 0; x < f.width; x++ {
			offset := y * f.width + x
			TetrisBlockDraw(&f.blocks[offset],
					ox + x * blockSize,
					oy + y * blockSize)
		}
	}
}

func TetrisFieldCollide(f *TetrisField, fig *TetrisFigure) bool {
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			offset := y * 4 + x
			if !fig.blocks[offset].filled {
				continue
			}

			fx, fy := fig.x + x, fig.y + y
			if fx < 0 || fy < 0 || fx >= f.width || fy >= f.height {
				return true
			}
			fieldoffset := fy * f.width + fx
			if f.blocks[fieldoffset].filled {
				return true
			}
		}
	}
	return false
}

func TetrisFieldStepCollideAndMerge(f *TetrisField, fig *TetrisFigure) bool {
	fig.y++
	if !TetrisFieldCollide(f, fig) {
		return false
	}
	fig.y--

	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			offset := y * 4 + x
			if !fig.blocks[offset].filled {
				continue
			}
			fx, fy := fig.x + x, fig.y + y
			fieldoffset := fy * f.width + fx
			f.blocks[fieldoffset] = fig.blocks[offset]
		}
	}
	return true
}

func TetrisFieldCheckForLines(f *TetrisField) int {
	lines := 0
	for y := 0; y < f.height; y++ {
		full := true
		for x := 0; x < f.width; x++ {
			offset := y * f.width + x
			if !f.blocks[offset].filled {
				full = false
				break
			}
		}

		if !full {
			continue
		}

		// if the line is full, increment counter and move all those
		// that are above this line one line down
		lines++

		for y2 := y - 1; y2 >= 0; y2-- {
			for x := 0; x < f.width; x++ {
				offset := y2 * f.width + x
				f.blocks[offset + f.width] = f.blocks[offset]
			}
		}
	}
	return lines
}

//-------------------------------------------------------------------------
// GameSession
//-------------------------------------------------------------------------

type GameSession struct {
	field *TetrisField
	figure *TetrisFigure
	next *TetrisFigure

	time uint
	cx, cy int
	gameover bool
}

func NewGameSession() (gs *GameSession) {
	gs = stdlib.malloc(sizeof(GameSession))
	gs.field = NewTetrisField(10, 25)
	gs.figure = NewRandomTetrisFigure()
	gs.next = NewRandomTetrisFigureNot(gs.figure)
	gs.time = 0

	gs.cx = (640 - TetrisFieldPixelsWidth(gs.field)) / 2
	gs.cy = (480 - TetrisFieldPixelsHeight(gs.field)) / 2
	gs.gameover = false
}

func GameSessionFree(gs *GameSession) {
	TetrisFieldFree(gs.field)
	if gs.figure != nil {
		stdlib.free(gs.figure)
	}
	if gs.next != nil {
		stdlib.free(gs.next)
	}
}

func GameSessionUpdate(gs *GameSession, delta uint) {
	gs.time += delta
	if gs.time > 200 {
		gs.time -= 200
		if TetrisFieldStepCollideAndMerge(gs.field, gs.figure) {
			TetrisFieldCheckForLines(gs.field)
			stdlib.free(gs.figure)
			gs.figure = gs.next
			gs.next = nil

			if TetrisFieldCollide(gs.field, gs.figure) {
				gs.gameover = true
				return
			}

			gs.next = NewRandomTetrisFigureNot(gs.figure)
		}
	}
}

func GameSessionHandleKey(gs *GameSession, key uint) bool {
	switch key {
	case SDL.SDLK_LEFT, SDL.SDLK_a, SDL.SDLK_j:
		gs.figure.x--
		if TetrisFieldCollide(gs.field, gs.figure) {
			gs.figure.x++
		}
	case SDL.SDLK_RIGHT, SDL.SDLK_d, SDL.SDLK_l:
		gs.figure.x++
		if TetrisFieldCollide(gs.field, gs.figure) {
			gs.figure.x--
		}
	case SDL.SDLK_UP, SDL.SDLK_w, SDL.SDLK_i:
		TetrisFigureRotate(gs.figure, RotateCWBlock)
		if TetrisFieldCollide(gs.field, gs.figure) {
			TetrisFigureRotate(gs.figure, RotateCCWBlock)
		}
	case SDL.SDLK_DOWN, SDL.SDLK_s, SDL.SDLK_k, SDL.SDLK_SPACE:
		for {
			if TetrisFieldCollide(gs.field, gs.figure) {
				gs.figure.y--
				break
			} else {
				gs.figure.y++
			}
		}
	case SDL.SDLK_ESCAPE:
		return false
	}
	return true
}

func GameSessionDraw(gs *GameSession) {
	TetrisFieldDraw(gs.field, gs.cx, gs.cy)
	TetrisFigureDraw(gs.figure, gs.cx, gs.cy)
	TetrisFigureDraw(gs.next, gs.cx + TetrisFieldPixelsWidth(gs.field), gs.cy + 50)
}

func main(argc int, argv **byte) int {
	SDL.Init(SDL.INIT_VIDEO | SDL.INIT_TIMER)
	screen = SDL.SetVideoMode(640, 480, 24, SDL.HWSURFACE | SDL.DOUBLEBUF)
	stdlib.srand(SDL.GetTicks())

	SDL.WM_SetCaption("KrawlTris", "KrawlTris")
	SDL.EnableKeyRepeat(250, 45)

	gs := NewGameSession()
	last := SDL.GetTicks()
	running := true

	var e SDL.Event
	for running {
		for SDL.PollEvent(&e) != 0 {
			switch e._type {
			case SDL.QUIT:
				running = false
			case SDL.KEYDOWN:
				running = GameSessionHandleKey(gs, e.key.keysym.sym)
			}
		}

		now := SDL.GetTicks()
		delta := now - last
		last = now

		black := SDL.MapRGB(screen.format, 0, 0, 0)
		all := {0, 0, 640, 480}.(SDL.Rect)
		SDL.FillRect(screen, &all, black)

		GameSessionUpdate(gs, delta)
		if gs.gameover {
			break
		}

		GameSessionDraw(gs)
		SDL.Flip(screen)
	}

	return 0
}
