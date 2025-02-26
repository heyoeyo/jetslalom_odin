package main

import "core:math/rand"
import rl "vendor:raylib"


OBCOLOR :: enum {
	Red,
	Blue,
	Magenta,
	Yellow,
}
OBSTACLE_COLORS := [OBCOLOR]rl.Color {
	.Red     = rl.Color{230, 15, 20, 255},
	.Blue    = rl.Color{5, 70, 250, 255},
	.Magenta = rl.Color{240, 50, 250, 255},
	.Yellow  = rl.Color{245, 180, 50, 255},
}

Obstacle :: struct {
	x:     f32,
	z:     f32,
	h:     f32,
	w:     f32,
	color: OBCOLOR,
}

ObstacleBank :: struct {
	items:                           [MAX_NUM_SPAWN]Obstacle,
	active_idx, num_active, max_idx: i32,
}

get_spawn_item_index :: proc(loop_index: i32, bank: ObstacleBank) -> i32 {
	return (loop_index + bank.active_idx) % bank.max_idx
}

spawn_new_obstacle :: proc(bank: ^ObstacleBank, xz: [2]f32, color: OBCOLOR, wh: [2]f32) {

	/*
    Helper used to handle the 'creation' (or really, resetting) of new obstacles,
    intended for use inside of the game loop. Sets obstacle properties and also
    handles the rolling-index update
    */

	idx: i32 = get_spawn_item_index(bank.num_active, bank^)
	bank.items[idx].x = xz[0]
	bank.items[idx].z = xz[1]
	bank.items[idx].color = color
	bank.items[idx].w = wh[0]
	bank.items[idx].h = wh[1]

	bank.num_active += 1

	return
}

get_random_obcolor :: proc() -> OBCOLOR {
	return rand.choice_enum(OBCOLOR)
}

get_cycling_color :: proc(prev_color: OBCOLOR) -> OBCOLOR {
	return OBCOLOR((int(prev_color) + 1) % len(OBCOLOR))
}

get_different_obstacle_color :: proc(prev_color: OBCOLOR) -> OBCOLOR {
	offset: int = rand.int_max(len(OBCOLOR) - 2) + 1
	return OBCOLOR((int(prev_color) + offset) % len(OBCOLOR))
}

draw_obstacle :: proc(triangle: Obstacle) {
	rl.DrawTriangle3D(
		{-triangle.w + triangle.x, 0, triangle.z},
		{triangle.w + triangle.x, 0, triangle.z},
		{triangle.x, triangle.h, triangle.z},
		OBSTACLE_COLORS[triangle.color],
	)
	return
}

draw_obstacle_outlines :: proc(triangle: Obstacle) {

	color := rl.Color{0, 0, 0, 120}
	v1 := rl.Vector3{-triangle.w + triangle.x, 0, triangle.z}
	v2 := rl.Vector3{triangle.w + triangle.x, 0, triangle.z}
	v3 := rl.Vector3{triangle.x, triangle.h, triangle.z}
	// rl.DrawLine3D(v1, v2, color)
	rl.DrawLine3D(v2, v3, color)
	rl.DrawLine3D(v3, v1, color)
}

draw_all_obstacles :: proc(bank: ObstacleBank) {
	for idx_offset in 0 ..< bank.num_active {
		idx := get_spawn_item_index(idx_offset, bank)
		draw_obstacle(bank.items[idx])
		// draw_obstacle_outlines(obstacles[idx])
	}
}

draw_all_obstacles_hide_early :: proc(bank: ObstacleBank, player_z: f32) {
	/*
	Special variant for drawing obstacles, but hiding them as they pass the player
	This is mainly meant for the leader corridor stage, where it's common for
	obstacles to end up in front of the camera, but behind the player, which
	can hurt visibility
	*/

	for idx_offset in 0 ..< bank.num_active {
		idx := get_spawn_item_index(idx_offset, bank)
		obs_ref := bank.items[idx]
		if obs_ref.z < player_z {
			draw_obstacle(obs_ref)
			// draw_obstacle_outlines(obstacles[idx])
		}
	}
}

clean_up_obstacles :: proc(bank: ^ObstacleBank, cutoff_z: f32) {

	/*
	Function used to 'remove' obstacles that get behind the camera.
	All obstacles are handled via a rolling subset of a fixed array,
	so removal just means updating indexing to stop updating old obstacles!
	*/

	num_to_remove: i32 = 0
	for idx_offset in 0 ..< bank.num_active {

		idx := get_spawn_item_index(idx_offset, bank^)
		obs_ref := bank.items[idx]

		needs_removal := obs_ref.z > cutoff_z
		num_to_remove += i32(needs_removal)
		if !needs_removal {
			// Obstacles are ordered by z distance
			// -> Once we find one obstacle that doesn't need removal,
			//    we can stop checking,
			//    since all other obstacles will be further away!
			break
		}
	}

	// Advance active index foward to 'get rid' of items to be removed
	bank.active_idx = get_spawn_item_index(num_to_remove, bank^)
	bank.num_active -= num_to_remove

	return
}
