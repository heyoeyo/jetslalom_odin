package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"


StageEmpty :: struct {
}

StageHallway :: struct {
	width, spawns_per_sec: f32,
}

StageRandom :: struct {
	spawns_per_sec, max_jitter_factor: f32,
}

StageGrid :: struct {
	x_spacing, t_spacing: f32,
}

StageWalls :: struct {
	gap_width, t_spacing, max_t_jitter_factor: f32,
}

StageLeaderCorridor :: struct {
	width, t_spacing: f32,
}

StageDebugEdges :: struct {
	follows_player: bool,
}

StageColors :: struct {
	sky, gnd: rl.Color,
}

Stage :: struct {
	duration:             f32,
	init_delay_sec:       f32,
	colors:               StageColors,
	start_xyz:            [3]f32,
	start_time, end_time: f32,
	data:                 union {
		StageEmpty,
		StageHallway,
		StageRandom,
		StageGrid,
		StageWalls,
		StageLeaderCorridor,
		StageDebugEdges,
	},
	leader_ctrl:          LeaderControl,
	tris:                 TriangleSizingTypes,
	hide_close_triangles: bool,
}

TFixed :: struct {
	w, h: f32,
}
TMixed :: struct {
	w1, h1, w2, h2: f32,
}
TRange :: struct {
	w1, w2, h1, h2: f32,
}
TriangleSizingTypes :: union {
	TFixed,
	TMixed,
	TRange,
}

get_triangle_wh :: proc(triangle_sizing: TriangleSizingTypes) -> [2]f32 {
	/* Helper used to set appropriate obstacle sizing, based on stage settings */

	wh: [2]f32
	switch sizing in triangle_sizing {

	case TFixed:
		wh = {sizing.w, sizing.h}

	case TMixed:
		use_size_1 := (rand.int31_max(2) == 0)
		wh = {sizing.w1, sizing.h1} if use_size_1 else {sizing.w2, sizing.h2}

	case TRange:
		t_lerp := rand.float32()
		wh = {math.lerp(sizing.w1, sizing.w2, t_lerp), math.lerp(sizing.h1, sizing.h2, t_lerp)}
	}

	return wh
}
