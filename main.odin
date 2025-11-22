package main

import "core:fmt"
import "core:math"
import "core:mem"
import gl "vendor:OpenGL"
import "vendor:glfw"
import rl "vendor:raylib"

WIDTH :: 1440
HEIGHT :: 640

VIEW_PORT_WIDTH :: 640
VIEW_PORT_HEIGHT :: 480

TITLE :: "My Window!"
SPEED :: 300 // pixels per second
DIRECTION_LINE_LENGTH :: 20

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

PI :: math.PI
PI_2 :: math.PI / 2
PI_3 :: 3 * math.PI / 2
DEG_RAD :: math.PI / 180
FOV :: 90


main :: proc() {
	rl.InitWindow(WIDTH, HEIGHT, TITLE)
	defer rl.CloseWindow()

	init()

	for !rl.WindowShouldClose() {
		handle_inputs()

		rl.BeginDrawing()

		draw()

		rl.EndDrawing()
	}
}

init :: proc() {
	px = SPEED
	py = SPEED
	pdx = math.cos(pa)
	pdy = math.sin(pa)

}

ButtonKeys :: struct {
	W, A, S, D: int,
}
KEYS: ButtonKeys = {}

handle_inputs :: proc() {
	KEYS.W = rl.IsKeyDown(.W) ? 1 : 0
	KEYS.A = rl.IsKeyDown(.A) ? 1 : 0
	KEYS.S = rl.IsKeyDown(.S) ? 1 : 0
	KEYS.D = rl.IsKeyDown(.D) ? 1 : 0

}

draw :: proc() {
	rl.ClearBackground(rl.Color{0x4c, 0x4c, 0x4c, 0xff})

	draw_map()
	draw_player()

	draw_rays_3d()
}

px, py: f32
pa: f32
pdx, pdy: f32

draw_player :: proc() {
	// update player position and angle
	delta_time := rl.GetFrameTime()
	delta_rad := delta_time * 6
	if KEYS.A == 1 {
		pa -= delta_rad
		if (pa < 0) {
			pa += 2 * PI
		}
		pdx = math.cos(pa)
		pdy = math.sin(pa)
	}
	if KEYS.D == 1 {
		pa += delta_rad
		if (pa > 2 * PI) {
			pa -= 2 * PI
		}
		pdx = math.cos(pa)
		pdy = math.sin(pa)
	}

	our_map := MAP
	dx := pdx * delta_time * SPEED
	dy := pdy * delta_time * SPEED
	xo: f32 = pdx < 0 ? -20 : 20
	yo: f32 = pdy < 0 ? -20 : 20
	tpx: f32
	tpy: f32
	if KEYS.W == 1 {
		tpx = px + dx + xo
		if our_map[int(py) / MAP_BLOCK_SIZE][int(tpx) / MAP_BLOCK_SIZE] == 0 {
			px = tpx - xo
		}
		tpy = py + dy + yo
		if our_map[int(tpy) / MAP_BLOCK_SIZE][int(px) / MAP_BLOCK_SIZE] == 0 {
			py = tpy - yo
		}
	}
	if KEYS.S == 1 {
		tpx = px - dx - xo
		if our_map[int(py) / MAP_BLOCK_SIZE][int(tpx) / MAP_BLOCK_SIZE] == 0 {
			px = tpx + xo
		}
		tpy = py - dy - yo
		if our_map[int(tpy) / MAP_BLOCK_SIZE][int(px) / MAP_BLOCK_SIZE] == 0 {
			py = tpy + yo
		}
	}


	// draw player
	rl.DrawCircleV({px, py}, 4.0, rl.YELLOW)

	// draw direction indicator
	rl.DrawLineV(
		{px, py},
		{px + pdx * DIRECTION_LINE_LENGTH, py + pdy * DIRECTION_LINE_LENGTH},
		rl.YELLOW,
	)
	rl.DrawCircleV(
		{px + pdx * DIRECTION_LINE_LENGTH, py + pdy * DIRECTION_LINE_LENGTH},
		2.0,
		rl.YELLOW,
	)
}

MAP_TILES_X :: 8
MAP_TILES_Y :: 8
MAP_BLOCK_SIZE :: 64
MAP: [8][8]int : {
	{1, 1, 1, 1, 1, 1, 1, 1},
	{1, 0, 1, 0, 0, 0, 0, 1},
	{1, 0, 1, 0, 0, 0, 0, 1},
	{1, 0, 1, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 0, 0, 0, 1, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 1},
	{1, 1, 1, 1, 1, 1, 1, 1},
}

draw_map :: proc() {
	x, y: i32
	for row in MAP {
		for col in row {
			color: rl.Color
			if col == 1 {
				color = rl.WHITE
			} else {
				color = rl.BLACK
			}
			rl.DrawRectangle(
				x * MAP_BLOCK_SIZE + 1,
				y * MAP_BLOCK_SIZE + 1,
				MAP_BLOCK_SIZE - 2,
				MAP_BLOCK_SIZE - 2,
				color,
			)
			x += 1
		}
		x = 0
		y += 1
	}
}

draw_rays_3d :: proc() {
	screen_width := VIEW_PORT_WIDTH //rl.GetScreenWidth()
	screen_pixel_rad := math.to_radians(f32(FOV)) / f32(screen_width)
	mx, my: int = ---, ---
	dist_t, rx, ry, xo, yo: f32

	our_map := MAP

	color: rl.Color


	ra := pa - screen_pixel_rad * f32(screen_width / 2)
	if ra < 0 {
		ra += 2 * PI
	}
	if ra > 2 * PI {
		ra -= 2 * PI
	}

	for r in 0 ..< screen_width {
		dist_h: f32 = 1000000
		hx := px
		hy := py
		dof: int = --- // depth of field
		// --- Check Horizonzal Lines ---
		{
			dof = 0
			a_tan := -1 / math.tan(ra)

			// looking up
			if ra > PI {
				// bitshifting by 6 to match the 64 wide map blocks (2^6=64)
				ry = f32((int(py) >> 6) << 6) - 0.0001
				rx = (py - ry) * a_tan + px
				yo = -MAP_BLOCK_SIZE
				xo = -yo * a_tan
			}
			// looking down
			if ra < PI {
				// bitshifting by 6 to match the 64 wide map blocks (2^6=64)
				ry = f32((int(py) >> 6) << 6) + MAP_BLOCK_SIZE
				rx = (py - ry) * a_tan + px
				yo = MAP_BLOCK_SIZE
				xo = -yo * a_tan
			}
			// looking straight left or right
			if ra == 0 || ra == PI {
				rx = px
				ry = py
				dof = MAP_TILES_X
			}

			for dof < 8 {
				mx = int(rx) >> 6 // divide by 64
				my = int(ry) >> 6 // divide by 64
				if mx >= 0 &&
				   mx < MAP_TILES_X &&
				   my >= 0 &&
				   my < MAP_TILES_Y &&
				   our_map[my][mx] == 1 {
					// hit wall
					dof = 8
					hx = rx
					hy = ry
					dist_h = distance(px, py, hx, hy)
				} else {
					// next line
					rx += xo
					ry += yo
					dof += 1
				}
			}

			// rl.DrawLineV({px, py}, {rx, ry}, rl.GREEN)
			// rl.DrawCircleV({rx, ry}, 3.0, rl.GREEN)
		}

		dist_v: f32 = 1000000
		vx := px
		vy := py
		// --- Check Vertical Lines ---
		{
			dof = 0
			n_tan := -math.tan(ra)

			// looking left
			if ra > PI_2 && ra < PI_3 {
				// bitshifting by 6 to match the 64 wide map blocks (2^6=64)
				rx = f32((int(px) >> 6) << 6) - 0.0001
				ry = (px - rx) * n_tan + py
				xo = -MAP_BLOCK_SIZE
				yo = -xo * n_tan
			}
			// looking right
			if ra < PI_2 || ra > PI_3 {
				// bitshifting by 6 to match the 64 wide map blocks (2^6=64)
				rx = f32((int(px) >> 6) << 6) + MAP_BLOCK_SIZE
				ry = (px - rx) * n_tan + py
				xo = MAP_BLOCK_SIZE
				yo = -xo * n_tan
			}
			// looking straight up or down
			if ra == 0 || ra == PI {
				rx = px
				ry = py
				dof = MAP_TILES_X
			}

			for dof < 8 {
				mx = int(rx) >> 6 // divide by 64
				my = int(ry) >> 6 // divide by 64
				if mx >= 0 &&
				   mx < MAP_TILES_X &&
				   my >= 0 &&
				   my < MAP_TILES_Y &&
				   our_map[my][mx] == 1 {
					// hit wall
					dof = 8
					vx = rx
					vy = ry
					dist_v = distance(px, py, vx, vy)
				} else {
					// next line
					rx += xo
					ry += yo
					dof += 1
				}
			}

			// rl.DrawLineV({px, py}, {rx, ry}, rl.BLUE)
			// rl.DrawCircleV({rx, ry}, 3.0, rl.BLUE)
		}

		if dist_v < dist_h {
			rx = vx
			ry = vy
			dist_t = dist_v
			color = {230, 0, 0, 255}
		}
		if dist_h < dist_v {
			rx = hx
			ry = hy
			dist_t = dist_h
			color = {179, 0, 0, 255}
		}

		rl.DrawLineV({px, py}, {rx, ry}, color)

		// Draw 3D Walls
		ca := pa - ra
		if ca < 0 {
			ca += 2 * PI
		}
		if ca > 2 * PI {
			ca -= 2 * PI
		}
		dist_t *= math.cos(ca) // fix fisheye
		line_height := (MAP_BLOCK_SIZE * VIEW_PORT_HEIGHT) / dist_t
		if line_height > VIEW_PORT_HEIGHT {
			line_height = VIEW_PORT_HEIGHT
		}
		line_offset := VIEW_PORT_HEIGHT / 2 - line_height / 2
		rl.DrawRectangleV({f32(r + 530), line_offset}, {1, line_height}, color)

		ra += screen_pixel_rad
		if ra < 0 {
			ra += 2 * PI
		}
		if ra > 2 * PI {
			ra -= 2 * PI
		}
	}
}

distance :: proc(ax, ay, bx, by: f32) -> f32 {
	return math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2))
}

fix_angle :: proc(a: int) -> int {
	return a > 359 ? a - 360 : a < 0 ? a + 360 : a
}
