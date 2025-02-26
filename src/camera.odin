package main

import "core:math"
import rl "vendor:raylib"


CameraFOV :: struct {
	fov_x_deg, fov_y_deg: f32,
	fov_x_rad, fov_y_rad: f32,
}

CameraOrientation :: struct {
	y_delta, z_delta, max_roll_rad: f32,
}

CameraFOV_create :: proc(fov_y_deg, screen_aspect_ratio: f32) -> CameraFOV {
	/* Constructor for CameraFOV struct. Holds pre-computed copies of angles in degrees */

	fov_y_rad: f32 = fov_y_deg * math.RAD_PER_DEG
	fov_x_rad: f32 = 2.0 * math.atan(math.tan_f32(fov_y_rad * 0.5) * screen_aspect_ratio)
	fov_x_deg: f32 = fov_x_rad * math.DEG_PER_RAD

	return CameraFOV{fov_x_deg, fov_y_deg, fov_x_rad, fov_y_rad}
}

compute_camera_z_delta :: proc(camera_height_delta, bottom_offset: f32, camera_fov: CameraFOV) -> f32 {
	/*
    Helper used to compute how far back the camera needs to be so that the player
    appears near the bottom of the screen with some offset/padding
    */

	return camera_height_delta * (1 + bottom_offset) / math.tan_f32(camera_fov.fov_y_rad * 0.5)
}

update_camera :: proc(cam3d: ^rl.Camera3D, camera: CameraOrientation, player: PlayerData, horizon_z: f32) -> f32 {

	// Compute current roll state (depends on player movement)
	roll_per_vx: f32 = camera.max_roll_rad / player.max_vx
	camera_roll_rad := player.vx * roll_per_vx

	// Compute intermediate values
	sin_roll: f32 = math.sin(camera_roll_rad)
	cos_roll: f32 = math.cos(camera_roll_rad)
	cam_x: f32 = player.x + camera.y_delta * sin_roll
	cam_y: f32 = player.y + camera.y_delta * cos_roll
	cam_z: f32 = player.z + camera.z_delta
	targ_z: f32 = horizon_z + player.z

	// Compute updated camera vectors
	new_position := rl.Vector3{cam_x, cam_y, cam_z}
	new_target := rl.Vector3{cam_x, cam_y, targ_z}
	new_up_dir := rl.Vector3{sin_roll, cos_roll, 0}

	cam3d.position = new_position
	cam3d.target = new_target
	cam3d.up = new_up_dir

	return camera_roll_rad
}
