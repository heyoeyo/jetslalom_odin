package main

import "core:math"

HorizonData :: struct {
	z, distance_to_camera:  f32,
	half_w, pad_w, spawn_w: f32,
}

HorizonData_create :: proc(
	horizon_z: f32,
	player: PlayerData,
	camera_fov: CameraFOV,
	camera_ori: CameraOrientation,
) -> HorizonData {

	// Calculate straight-line distance to camera (assuming camera is 'looking at' the horizon)
	total_cam_y := player.y + camera_ori.y_delta
	total_cam_z := horizon_z - (player.z + camera_ori.z_delta)
	dist: f32 = math.sqrt(math.pow(total_cam_y, 2) + math.pow(total_cam_z, 2))

	// Figure out how width the horizon appears to the camera
	horizon_half_width: f32 = abs(math.tan_f32(camera_fov.fov_x_rad * 0.5) * dist)

	// Compute additional 'width' that accounts for player sideways movement
	// -> including this width as part of the 'horizon' was spawning helps
	//    to give the illusion that obstacles spawn 'everywhere' (not just on the horizon itself)
	horizon_pad_half_w: f32 = abs(camera_ori.z_delta) * math.tan(camera_fov.fov_x_rad * 0.5) * 1.5

	return HorizonData {
		z = horizon_z,
		distance_to_camera = dist,
		half_w = horizon_half_width,
		pad_w = horizon_pad_half_w,
		spawn_w = horizon_half_width + horizon_pad_half_w,
	}
}
