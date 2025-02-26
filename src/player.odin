package main

import "core:math"
import rl "vendor:raylib"


PlayerData :: struct {
	x, y, z:                       f32,
	vx, vz:                        f32,
	accel_x, decel_factor, max_vx: f32,
	half_w:                        f32,
}

update_player_xz :: proc(player: ^PlayerData, x_direction, delta_time: f32) -> (f32, f32) {

	/* Updates the player x & z location. Returns the amount moved in (x,z) for the given delta time */

	// Update player x location
	is_steering: bool = abs(x_direction) > 0.01
	if is_steering {
		x_accel_amt: f32 = x_direction * player.accel_x * delta_time
		player.vx = clamp(player.vx + x_accel_amt, -player.max_vx, player.max_vx)
	} else {
		player.vx = player.vx * math.pow_f32(player.decel_factor, delta_time)
	}
	x_move_amount: f32 = player.vx * delta_time
	player.x += player.vx * delta_time

	// Update player z location
	z_move_amount: f32 = player.vz * delta_time
	player.z += z_move_amount

	return x_move_amount, z_move_amount
}

read_player_inputs :: proc(left_keys: []rl.KeyboardKey, right_keys: []rl.KeyboardKey) -> f32 {

	/*
    Read keyboard inputs to control player movement.
    Returns -1 if player should move left, +1 if player moves right,
    and 0 if player doesn't move (all as floating point values!)
    */

	is_left := false
	for keycode in left_keys {
		is_left |= rl.IsKeyDown(keycode)
	}

	is_right := false
	for keycode in right_keys {
		is_right |= rl.IsKeyDown(keycode)
	}

	return f32(i32(is_right) - i32(is_left))
}


draw_player_billboard :: proc(
	camera: rl.Camera3D,
	player: PlayerData,
	player_texture: rl.Texture,
	total_time_sec: f32,
	scale: f32 = 1.0,
	z_offset: f32 = 0,
) {

	/*
	Draws player as 2D texture in 3D space.
	Handles 'unrotation' of graphics, so that player does not appear
	to rotate with camera during turns
	*/

	show_flames: bool = (i32(total_time_sec * 6)) % 2 == 0
	bill_rect := rl.Rectangle{0, 0, f32(player_texture.width), f32(player_texture.height / 2)}
	if show_flames {
		bill_rect.y += bill_rect.height
	}
	bboard_size := rl.Vector2{bill_rect.width / bill_rect.height, 1} * scale

	origin_x: f32 = bboard_size.x * 0.5
	origin_y: f32 = bboard_size.y * 0.5 + math.round(math.cos(total_time_sec * 4)) * 0.15
	rl.DrawBillboardPro(
		camera,
		player_texture,
		source = bill_rect,
		position = {player.x, player.y, player.z + z_offset},
		up = camera.up,
		size = bboard_size,
		origin = {origin_x, origin_y},
		rotation = 0,
		tint = rl.WHITE,
	)

	return
}


draw_debug_player_box :: proc(player: PlayerData, angle: f32 = 0) {

	/* Helper used to indicate player positioning/size in game world, without loaded textures */

	color := rl.Color{0, 0, 100, 255}

	// // Draw anti-rotated player indicator (debugging)
	tl := rl.Vector2{-player.half_w, 0.25}
	tr := rl.Vector2{player.half_w, 0.25}
	br := rl.Vector2{player.half_w, -0.25}
	bl := rl.Vector2{-player.half_w, -0.25}
	rot_tl := rl.Vector2Rotate(tl, angle)
	rot_tr := rl.Vector2Rotate(tr, angle)
	rot_br := rl.Vector2Rotate(br, angle)
	rot_bl := rl.Vector2Rotate(bl, angle)
	player_xy := rl.Vector2{player.x, player.y}
	rot_tl += player_xy
	rot_tr += player_xy
	rot_br += player_xy
	rot_bl += player_xy
	rl.DrawTriangle3D(
		{rot_tl.x, rot_tl.y, player.z},
		{rot_bl.x, rot_bl.y, player.z},
		{rot_tr.x, rot_tr.y, player.z},
		color,
	)
	rl.DrawTriangle3D(
		{rot_br.x, rot_br.y, player.z},
		{rot_tr.x, rot_tr.y, player.z},
		{rot_bl.x, rot_bl.y, player.z},
		color,
	)
}


draw_debug_leader_indicator :: proc(leader: PlayerData, z_offset: f32) {
	/* Helper used to show current location of the leader */
	pt_a := rl.Vector3{leader.x - 5, leader.y, leader.z + z_offset}
	pt_b := rl.Vector3{leader.x + 5, leader.y, leader.z + z_offset}
	rl.DrawLine3D(pt_a, pt_b, rl.ORANGE)
}


check_for_collision :: proc(player: PlayerData, bank: ^ObstacleBank, time: TimeData, camera_roll_rad: f32) -> bool {

	// Initialize output
	is_hit: bool = false

	prev_player_z: f32 = player.z - (player.vz * time.delta)
	for idx_offset in 0 ..< bank.num_active {
		idx := get_spawn_item_index(idx_offset, bank^)
		obs_ref := bank.items[idx]

		// Don't bother checking for any more collisions, because the obstacles will be too far away
		if obs_ref.z < player.z {
			break
		}

		// Check if the obstacle has just passed 'through' the player forward-to-backward
		is_overlapping_player_in_z: bool = (obs_ref.z > player.z) && (obs_ref.z < prev_player_z)

		// If check if the obstacle in overlaping the player left-to-right
		adjusted_obs_w: f32 = obs_ref.w * (obs_ref.h - player.y) / obs_ref.h
		combined_half_hit_area: f32 = player.half_w * math.cos(camera_roll_rad) + adjusted_obs_w
		is_overlapping_player_in_x: bool = abs(obs_ref.x - player.x) < combined_half_hit_area

		// Trigger hit state
		is_hit = is_overlapping_player_in_x && is_overlapping_player_in_z
		if is_hit {
			break
		}
	}

	return is_hit
}
