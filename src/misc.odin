package main

import "core:math"
import rl "vendor:raylib"


TimeData :: struct {
	total: f32,
	delta: f32,
	stage: f32,
}

GameStateEnum :: enum {
	Stopped,
	Playing,
	Hit,
}

GameStateTimes :: struct {
	state:       GameStateEnum,
	time:        f32,
	is_god_mode: bool,
}

LeaderControl :: struct {
	min_turn_duration, turn_duration_scale, chance_to_go_straight, x_reset_threshold: f32,
}

draw_text_centered :: proc(
	text: cstring,
	display_wh: WHData,
	y_norm: f32,
	fontSize: i32,
	color: rl.Color,
	y_offset_px: i32 = 0,
) {

	/*
    Helper used to draw text that is both centered, in terms of 'text alignment' as well
    as being horizontally centered on the screen. Y positions are given in normalized
    coords, so text can be placed consistently even on smaller display sizes
    */

	text_width: i32 = rl.MeasureText(text, fontSize)
	half_w := text_width / 2
	half_h := fontSize / 2

	x_px := display_wh.half_wi
	y_px := i32(math.round(display_wh.h * y_norm)) + y_offset_px

	rl.DrawText(text, x_px - half_w, y_px - half_h, fontSize, color)
}
