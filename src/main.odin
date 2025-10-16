package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Convenience
println :: fmt.println
ENABLE_DEBUG_TXT :: false
ENABLE_DEBUG_DRAWING :: false
ENABLE_DEBUG_GODMODE :: false
DEBUG_START_STAGE_IDX :: -1

// Game feel
FRAMERATE: i32 : -1
CAMERA_FOV_Y: f32 : 70
MAX_CAMERA_ROLL_RAD: f32 : 0.55
PLAYER_TURN_MOMENTUM_FACTOR: f32 : 0.15
PLAYER_TURN_RATE_FACTOR: f32 : 3.5
PLAYER_MAX_X_SPEED_FACTOR: f32 : 1.35
TIME_TO_REACT_SEC: f32 : 1.4

// GFX settings
ASPECT_RATIO: f32 : 16.0 / 9.0
RENDER_HEIGHT: f32 : 240
PLAYER_SCREEN_BOTTOM_OFFSET: f32 : 0.2
EXPLOSION_Y_OFFSET: i32 : 18
EXPLOSION_TIME_SEC: f32 : 1

// Player sizing parameters
PLAYER_HALF_WIDTH: f32 : 2
PLAYER_Y: f32 : 2.5
CAMERA_Y_OFFSET: f32 : 5

// Set distance of spawned obstacles as well as the 'travel speed'
// -> Travel speed is set based on how long obstacles take to travel from spawn point to player
HORIZON_Z: f32 = -100
MAX_NUM_SPAWN: i32 : 500

// Setting for floating point error mitigation
// If the player moves too far away from the origin (in x/z), based on this value,
// We reset them (and all obstacles) to reduce floating point errors
RESET_BOUNDS: f32 : 50000

// Helper used to represent left/right direction. Meant to be used as an iterable
X_LEFT_RIGHT: [2]f32 : {-1, 1}

main :: proc() {

	// Create window, otherwise tons of stuff fails unexpectedly...
	rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT} if FRAMERATE <= 0 else {.WINDOW_RESIZABLE})
	rl.InitWindow(100, 100, "JetSlalom (Remake)")
	defer rl.CloseWindow()

	// Figure out display sizing
	curr_monitor := rl.GetCurrentMonitor()
	monitor_width := f32(rl.GetMonitorWidth(curr_monitor))
	monitor_height := f32(rl.GetMonitorHeight(curr_monitor))
	target_display_height: f32 = monitor_height * 0.5
	render_upscale_factor: f32 = math.round(target_display_height / RENDER_HEIGHT)
	render_wh := WHData_create(RENDER_HEIGHT * ASPECT_RATIO, RENDER_HEIGHT)
	display_wh := WHData_create(render_upscale_factor * render_wh.w, render_upscale_factor * render_wh.h)
	font_size: i32 = i32(10 * clamp(math.ceil(math.sqrt(render_upscale_factor)), 1, 4))

	// Properly setup the display window
	rl.SetWindowSize(display_wh.wi, display_wh.hi)
	rl.SetWindowPosition(i32((monitor_width - display_wh.w) * 0.5), i32((monitor_height - display_wh.h) * 0.5))
	rl.SetTargetFPS(FRAMERATE)
	rl.HideCursor()

	// Force 1 frame draw, so first frame time is not zero!
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.EndDrawing()

	// Load player image data
	player_img_texture := load_player_graphics()
	defer rl.UnloadTexture(player_img_texture)

	// Load gameover explosion sound
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	explosion_snd := load_explosion_sound()
	defer rl.UnloadSound(explosion_snd)

	// Create a RenderTexture2D to be used for low-res render
	// *** This texture is closely tied to the window
	//     It must be created after the window init, and must be cleaned up
	//     before closing the window, otherwise we get a seg. fault!
	lowres_render_target: rl.RenderTexture2D = rl.LoadRenderTexture(render_wh.wi, render_wh.hi)
	defer rl.UnloadRenderTexture(lowres_render_target)
	rl.SetTextureFilter(lowres_render_target.texture, rl.TextureFilter.POINT)

	// Set up camera parameters (position is dependent on player to some extent!)
	camfov := CameraFOV_create(fov_y_deg = CAMERA_FOV_Y, screen_aspect_ratio = ASPECT_RATIO)
	cam3d := rl.Camera3D {
		fovy       = camfov.fov_y_deg,
		projection = rl.CameraProjection.PERSPECTIVE,
	}
	camori := CameraOrientation {
		y_delta      = CAMERA_Y_OFFSET,
		z_delta      = compute_camera_z_delta(CAMERA_Y_OFFSET, PLAYER_SCREEN_BOTTOM_OFFSET, camfov),
		max_roll_rad = MAX_CAMERA_ROLL_RAD,
	}

	// Set up player position & movement parameters
	z_speed := (HORIZON_Z / TIME_TO_REACT_SEC)
	player := PlayerData {
		y            = PLAYER_Y,
		vz           = z_speed,
		accel_x      = PLAYER_TURN_RATE_FACTOR * abs(z_speed),
		decel_factor = PLAYER_TURN_MOMENTUM_FACTOR,
		max_vx       = PLAYER_MAX_X_SPEED_FACTOR * abs(z_speed) * (camfov.fov_y_deg / 60.0),
		half_w       = PLAYER_HALF_WIDTH,
	}

	// Set up auto-controlled version of player (with similar movement dynamics)
	// -> Used for producing safe travel regions, based on player's allowed movement
	leader := PlayerData {
		x       = player.x,
		y       = player.y,
		z       = player.z,
		vx      = 0,
		vz      = player.vz,
		accel_x = player.accel_x * 0.925,
		max_vx  = player.max_vx * 1.1,
		half_w  = PLAYER_HALF_WIDTH,
	}

	// Set up obstacles!
	bank := ObstacleBank {
		active_idx = 0,
		num_active = 0,
		max_idx    = MAX_NUM_SPAWN,
	}

	// Set up horizon-related distances
	horizon := HorizonData_create(HORIZON_Z, player, camfov, camori)

	// Set up sequence of stages
	stages := make_stages(horizon)
	stage_idx: int = 0


	// ******************************************************************************************************************
	// GAME LOOP

	// Storage for keeping track of playing/stopped state
	gamestate := GameStateTimes {
		state       = .Stopped,
		is_god_mode = ENABLE_DEBUG_GODMODE,
	}

	// Helper variables for adjusting quantities over time
	next_color: OBCOLOR
	next_color_update_sec: f32
	next_leader_update_sec: f32
	next_spawn_time: f32
	leader_x_move_amt: f32

	hide_obstacles_early := false
	request_reset_game := true
	curr_stage: Stage
	time := TimeData{}
	lifetime_score_sec: i32 = -1
	display_offset := [2]f32{0, 0}
	for !rl.WindowShouldClose() {

		// Update display sizing if window size changes
		if rl.IsWindowResized() {
			screen_width := rl.GetScreenWidth()
			screen_height := rl.GetScreenHeight()
			new_ar: f32 = f32(screen_width) / f32(screen_height)
			new_width, new_height: i32
			if new_ar > ASPECT_RATIO {
				new_width = i32(f32(screen_height) * ASPECT_RATIO)
				new_height = screen_height
			} else {
				new_height = i32(f32(screen_width) / ASPECT_RATIO)
				new_width = screen_width
			}
			display_offset.x = max(0, f32(screen_width - new_width) * 0.5)
			display_offset.y = max(0, f32(screen_height - new_height) * 0.5)
			display_wh = WHData_create(new_width, new_height)
		}


		// **************************************************
		// State update

		// Get timing information
		time.total = f32(rl.GetTime())
		time.delta = rl.GetFrameTime()
		time.stage = time.total - stages[stage_idx].start_time


		// **************************************************
		// Stage update

		// Trigger stage change over time or from keypress when game isn't playing
		need_stage_change := time.total > stages[stage_idx].end_time
		if gamestate.state == .Stopped && rl.IsKeyPressed(.SPACE) {
			need_stage_change = true
			gamestate.state = .Playing
			gamestate.time = time.total
		}

		// Special condition, used to reset the game when player crashes
		if request_reset_game {
			request_reset_game = false
			need_stage_change = true
			stage_idx = -1
			if DEBUG_START_STAGE_IDX > 1 {
				stage_idx = DEBUG_START_STAGE_IDX - 2
			}
		}

		// Handle stage changes
		if need_stage_change {
			stage_idx = clamp(stage_idx + 1, 0, len(stages) - 1)

			stages[stage_idx].start_xyz = {player.x, player.y, player.z}
			stages[stage_idx].start_time = time.total
			stages[stage_idx].end_time = time.total + stages[stage_idx].duration
			next_spawn_time = stages[stage_idx].start_time + stages[stage_idx].init_delay_sec
			curr_stage = stages[stage_idx]

			// Reset the leader
			leader.vx = 0
			leader.x = player.x
			leader.z = player.z
		}

		// For convenience
		curr_stage = stages[stage_idx]


		// **************************************************
		// Player state update

		// Reset for floating point error mitigation
		// The consecutive number 'gap' around z = 1E6 is roughly 0.1 for f32!
		// -> This would lead to issues with obstacle placement if the player 'travels too far'
		// -> So reset x/z if player gets too far from origin
		if abs(player.z) > RESET_BOUNDS || abs(player.x) > RESET_BOUNDS {
			backtrack_x := player.x
			player.x -= backtrack_x
			leader.x -= backtrack_x
			backtrack_z := player.z
			player.z -= backtrack_z
			leader.z -= backtrack_z
			for idx_offset in 0 ..< bank.num_active {
				idx := get_spawn_item_index(idx_offset, bank)
				bank.items[idx].x -= backtrack_x
				bank.items[idx].z -= backtrack_z
			}
		}

		// Update player, camera and remove obstacles that have gone out of view
		player_x_move: f32
		if gamestate.state == .Playing {
			player_x_move = read_player_inputs(left_keys = {.LEFT, .A}, right_keys = {.RIGHT, .D})
		}
		update_player_xz(&player, player_x_move, time.delta)
		camera_roll_rad := update_camera(&cam3d, camori, player, horizon.z)
		clean_up_obstacles(&bank, player.z + camori.z_delta)

		// Check for player-obstacle collisions
		if gamestate.state == .Playing && !gamestate.is_god_mode {
			if check_for_collision(player, &bank, time, camera_roll_rad) {
				lifetime_score_sec = i32(math.round(time.total - gamestate.time))
				rl.PlaySound(explosion_snd)
				gamestate.state = .Hit
				gamestate.time = time.total

			}
		}


		// **************************************************
		// Leader update
		// -> Leader is invisible 'extra player' that runs ahead of player
		// -> Used to provide valid path for player
		// -> Movement is simulated as series of briefly held turns

		leader_ctrl := stages[stage_idx].leader_ctrl
		if time.total > next_leader_update_sec {

			// Update travel/turn direction of leader
			leader_x_move_amt = -math.sign(leader.vx)
			if abs(leader.vx) < player.max_vx * 0.1 {
				leader_x_move_amt = rand.choice([]f32{-1, 1})
			}

			// Decide how long to hold new direction until next update
			// (also add chance for going straight, for variety)
			t_norm: f32 = rand.float32()
			new_duration: f32 = (leader_ctrl.turn_duration_scale * t_norm * t_norm) + leader_ctrl.min_turn_duration
			if t_norm < leader_ctrl.chance_to_go_straight {
				leader_x_move_amt = 0
			}
			next_leader_update_sec = time.total + new_duration
		}

		// Prevent leader from getting too far away from the player
		// (always want leader close to player, to provide at least one safe path)
		leader_x_diff := leader.x - player.x
		leader_x_diff_threshold := horizon.half_w * leader_ctrl.x_reset_threshold
		if abs(leader_x_diff) > leader_x_diff_threshold {
			leader.x = player.x + math.sign(leader_x_diff) * leader_x_diff_threshold
		}

		// Update leader position based on simulated control
		update_player_xz(&leader, leader_x_move_amt, time.delta)


		// **************************************************
		// Spawning update

		// Record starting number of obstacles (used to count spawns for debugging)
		init_num_obstacles := bank.num_active

		spawn_z: f32 = player.z + horizon.z
		hide_obstacles_early = false
		next_x, z_corrected: f32
		tri_wh: [2]f32
		switch data in curr_stage.data {

		case StageEmpty:
		// Do nothing


		case StageHallway:
			hall_x := curr_stage.start_xyz.x
			for time.total > next_spawn_time {

				// IMPORTANT! Don't try to spawn if we max out active items, this will crash the whole computer
				if bank.num_active >= bank.max_idx {
					break
				}

				// Compute 'corrected' spawn point, based on how late we are relative to target spawn time
				z_corrected = spawn_z - (player.vz * (time.total - next_spawn_time))
				next_spawn_time += 1.0 / data.spawns_per_sec

				// Spawn to the left/right of a gap with the 
				rand_sample := rand.float32_range(-1, 1)
				rand_offset := math.sign(rand_sample) * data.width + (horizon.spawn_w - data.width) * rand_sample
				next_x = hall_x + rand_offset
				next_color = get_random_obcolor()
				tri_wh = get_triangle_wh(curr_stage.tris)

				spawn_new_obstacle(&bank, {next_x, z_corrected}, next_color, tri_wh)
			}


		case StageRandom:
			leader_gap := 4 * player.half_w
			for time.total > next_spawn_time {
				// IMPORTANT! Don't try to spawn if we max out active items, this will crash the whole computer
				if bank.num_active >= bank.max_idx {
					break
				}

				// Compute 'corrected' spawn point, based on how late we are relative to target spawn time
				z_corrected = spawn_z - (player.vz * (time.total - next_spawn_time))

				spawn_time_jitter_factor: f32 = 1 + rand.float32_range(-data.max_jitter_factor, data.max_jitter_factor)
				next_spawn_time += (1.0 / data.spawns_per_sec) * spawn_time_jitter_factor

				next_x = rand.float32_range(-1, 1) * horizon.spawn_w + player.x

				// Clear a path near the leader, to ensure the player always has at least 1 viable safe path
				if abs(next_x - leader.x) < leader_gap {
					continue
				}

				next_color = get_random_obcolor()
				tri_wh = get_triangle_wh(curr_stage.tris)
				spawn_new_obstacle(&bank, {next_x, z_corrected}, next_color, tri_wh)

			}


		case StageGrid:
			grid_spawn_loop: for time.total > next_spawn_time {
				z_corrected = spawn_z - (player.vz * (time.total - next_spawn_time))

				grid_x_offset: f32 = f32(i32(math.round(time.total / data.t_spacing)) % 2) * data.x_spacing * 0.5
				n_grid: i32 = i32(math.ceil(horizon.spawn_w / max(data.x_spacing, 1)))
				for dir_x in X_LEFT_RIGHT {

					next_color = get_random_obcolor()
					for n in 0 ..< n_grid {
						if bank.num_active >= bank.max_idx {
							break grid_spawn_loop
						}
						n_dir := f32(n) + max(0, dir_x) // Add 0 or 1 to prevent left/right dupe spawn on n=0
						next_x = (dir_x * data.x_spacing * n_dir) + player.x + grid_x_offset

						tri_wh = get_triangle_wh(curr_stage.tris)
						spawn_new_obstacle(&bank, {next_x, z_corrected}, next_color, tri_wh)

					}
				}
				next_spawn_time += data.t_spacing
			}


		case StageWalls:
			for time.total > next_spawn_time {
				z_corrected = spawn_z - (player.vz * (time.total - next_spawn_time))
				next_spawn_time += data.t_spacing * (1 + rand.float32_range(0, data.max_t_jitter_factor))

				tri_wh = get_triangle_wh(curr_stage.tris)
				wall_gap: f32 = data.gap_width * clamp(4 * (1 - time.stage), 1, 4)

				// Spawn triangles from the gap to the left
				left_space: f32 = (leader.x - wall_gap) - (player.x - horizon.spawn_w)
				n_left_tris: int = int(math.ceil(left_space / tri_wh[0]))
				for i in 0 ..< n_left_tris {
					if bank.num_active >= bank.max_idx {
						break
					}
					next_color = get_random_obcolor()
					next_x = (leader.x - wall_gap) - f32(i) * (1 + tri_wh[0])

					if rand.float32() > 0.1 {
						spawn_new_obstacle(&bank, {next_x, z_corrected}, next_color, tri_wh)
					}
				}

				// Spawn triangles from the gap to the right
				right_space: f32 = (player.x + horizon.spawn_w) - (leader.x + wall_gap)
				n_right_tris: int = int(math.ceil(right_space / tri_wh[0]))
				for i in 0 ..< n_right_tris {
					if bank.num_active >= bank.max_idx {
						break
					}
					next_color = get_random_obcolor()
					next_x = (leader.x + wall_gap) + f32(i) * (1 + tri_wh[0])

					if rand.float32() > 0.1 {
						spawn_new_obstacle(&bank, {next_x, z_corrected}, next_color, tri_wh)
					}
				}

			}


		case StageLeaderCorridor:
			// Special flag: stops drawing triangles a bit earlier, to make it easier to see!
			hide_obstacles_early = true

			// Handle color updates
			if time.total > next_color_update_sec {
				next_color_update_sec = time.total + rand.float32_range(0.1, 0.35)
				next_color = get_cycling_color(next_color)
			}

			t_funnel_intro := clamp(3.5 * (2.5 - time.stage), 1, 9)
			t_corri_spacing := data.t_spacing / t_funnel_intro
			corri_width: f32 = data.width * t_funnel_intro
			for time.total > next_spawn_time {
				if bank.num_active >= bank.max_idx - 2 {
					break
				}
				z_corrected = spawn_z - (player.vz * (time.total - next_spawn_time))
				next_spawn_time += t_corri_spacing

				// Spawn two obstacles around leader to form corridor
				tri_wh = get_triangle_wh(curr_stage.tris)
				for x_offset in X_LEFT_RIGHT {
					next_x = leader.x + x_offset * corri_width
					spawn_new_obstacle(&bank, {next_x, z_corrected}, next_color, tri_wh)
				}
			}


		case StageDebugEdges:
			for time.total > next_spawn_time {
				if bank.num_active >= bank.max_idx {
					break
				}

				// Compute 'corrected' spawn point, based on how late we are relative to target spawn time
				z_corrected = spawn_z - (player.vz * (time.total - next_spawn_time))
				next_spawn_time += 0.1

				next_color = get_random_obcolor()
				for dir_x in X_LEFT_RIGHT {
					next_x = dir_x * horizon.half_w
					if data.follows_player {
						next_x += player.x
					}
					tri_wh = get_triangle_wh(curr_stage.tris)
					spawn_new_obstacle(&bank, {next_x, z_corrected}, next_color, tri_wh)
				}

			}
		}


		// **************************************************
		// Render Update (low-res)
		// - This is the main render update, but produces a low-res result
		// - The low-res result is upscaled to produce a pixelated display effect

		// Figure out background colors
		curr_sky := curr_stage.colors.sky
		curr_gnd := curr_stage.colors.gnd
		need_color_change := ((curr_stage.end_time - time.total) < 1)
		if gamestate.state == .Hit {
			need_color_change = (time.total - gamestate.time) > 0.5
		}
		if need_color_change {
			next_stage_idx := clamp(stage_idx + 1, 0, len(stages) - 1)
			if gamestate.state == .Hit {
				next_stage_idx = 0
			}
			next_sky := stages[next_stage_idx].colors.sky
			next_gnd := stages[next_stage_idx].colors.gnd

			// Average current and next colors
			for i in 0 ..< 3 {
				curr_sky[i] = u8((i32(curr_sky[i]) + i32(next_sky[i])) / 2)
				curr_gnd[i] = u8((i32(curr_gnd[i]) + i32(next_gnd[i])) / 2)
			}
		}

		rl.BeginTextureMode(lowres_render_target)
		rl.BeginMode3D(cam3d)

		// Draw background elements
		rl.ClearBackground(curr_sky)
		rl.DrawPlane({player.x, 0, player.z}, {abs(2 * horizon.half_w), abs(2 * horizon.z)}, curr_gnd)


		// Draw all obstacles
		if hide_obstacles_early {
			draw_all_obstacles_hide_early(bank, player.z)
		} else {
			draw_all_obstacles(bank)
		}

		// Draw player graphics (with initial 'arrival' animation effect)
		if gamestate.state == .Playing {
			arrival_offset: f32 = 0
			player_lifetime := time.total - gamestate.time
			if player_lifetime < 2 {
				arrival_offset_time: f32 = clamp((2 - player_lifetime) / 2, 0, 1)
				arrival_offset = camori.z_delta * (arrival_offset_time * arrival_offset_time)
			}
			draw_player_billboard(cam3d, player, player_img_texture, player_lifetime, z_offset = arrival_offset)
		}

		// Helpful visualizations
		if ENABLE_DEBUG_DRAWING {
			draw_debug_player_box(player, angle = -camera_roll_rad)
			draw_debug_leader_indicator(leader, horizon.z)
		}

		rl.EndMode3D()

		// Draw player exploding if needed
		if gamestate.state == .Hit {

			// Stop game when explosion animation finishes
			t_hit: f32 = (time.total - gamestate.time)
			if t_hit > 2 * EXPLOSION_TIME_SEC {
				gamestate.state = .Stopped
				request_reset_game = true
			}

			// Draw explosion graphics
			if t_hit < EXPLOSION_TIME_SEC {
				t_hit_inv_col: u8 = u8(255 * (1 - t_hit))
				hit_color: rl.Color = {255, t_hit_inv_col, t_hit_inv_col, 255}
				expl_w: f32 = render_wh.half_w * t_hit
				expl_h: f32 = render_wh.half_h * t_hit
				rl.DrawEllipse(render_wh.half_wi, render_wh.hi - EXPLOSION_Y_OFFSET, expl_w, expl_h, hit_color)
			}
		}

		rl.EndTextureMode()


		// **************************************************
		// Hi-res render

		rl.BeginDrawing()

		// Draw upscaled image to screen, for pixelated effect
		rl.ClearBackground(rl.BLACK)
		rl.DrawTexturePro(
			lowres_render_target.texture,
			source = rl.Rectangle{0, 0, render_wh.w, -render_wh.h},
			dest = rl.Rectangle{display_offset.x, display_offset.y, display_wh.w, display_wh.h},
			origin = rl.Vector2{0, 0},
			rotation = 0,
			tint = rl.WHITE,
		)

		// Draw time elapsed text
		if gamestate.state == .Playing {
			time_cstr := rl.TextFormat("%d", int(time.total - gamestate.time))
			text_width: i32 = rl.MeasureText(time_cstr, font_size)
			rl.DrawText(time_cstr, display_wh.wi - text_width - 10 + i32(display_offset.x), 10, font_size, rl.WHITE)
		}

		// Draw start screen text, if needed
		if gamestate.state == .Stopped {
			draw_text_centered("Jet Slalom", display_wh, display_offset, 0.15, 3 * font_size, rl.WHITE)
			draw_text_centered(
				"(remake)", display_wh, display_offset, 0.15, font_size, rl.WHITE, y_offset_px = 2 * font_size
			)

			// Draw score, if available
			if lifetime_score_sec > 0 {
				draw_text_centered(
					rl.TextFormat("Score: %d", lifetime_score_sec),
					display_wh,
					display_offset,
					0.3,
					2 * font_size,
					rl.YELLOW,
				)
			}

			draw_text_centered(
				"Use arrow keys or A/D to avoid obstacles",
				display_wh,
				display_offset,
				0.95,
				font_size,
				rl.BLACK,
				y_offset_px = i32(-1.5 * f32(font_size)),
			)
			draw_text_centered("Push [space] to begin!!", display_wh, display_offset, 0.95, font_size, rl.BLACK)

		}

		// Draw debugging text
		if ENABLE_DEBUG_TXT {
			num_spawn_per_frame := bank.num_active - init_num_obstacles
			rl.DrawText(rl.TextFormat("Active: %d", bank.num_active), 10, 40, font_size, rl.WHITE)
			rl.DrawText(rl.TextFormat("Num spawn: %d", num_spawn_per_frame), 10, 70, font_size, rl.WHITE)
			rl.DrawText(rl.TextFormat("Player X: %d", int(player.x)), 10, 100, font_size, rl.WHITE)
			rl.DrawText(rl.TextFormat("Player Z: %d", int(player.z)), 10, 130, font_size, rl.WHITE)
			rl.DrawText(rl.TextFormat("Leader X: %d", int(leader.x)), 10, 160, font_size, rl.WHITE)
			rl.DrawText(rl.TextFormat("Stage: %d", stage_idx), 10, 190, font_size, rl.WHITE)

			// Debugging drawings
			rl.DrawFPS(10, 10)
		}

		rl.EndDrawing()
	}

}
