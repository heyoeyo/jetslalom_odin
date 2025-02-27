package main

import rl "vendor:raylib"

SKY_1 :: rl.Color{30, 200, 250, 255}
SKY_2 :: rl.Color{230, 150, 155, 255}
SKY_3 :: rl.Color{0, 0, 0, 255}
SKY_4 :: rl.Color{45, 255, 255, 255}
SKY_5 :: rl.Color{190, 190, 190, 255}
SKY_6 :: rl.Color{70, 70, 70, 255}
SKY_7 :: rl.Color{95, 0, 145, 255}
SKY_8 :: rl.Color{210, 240, 245, 255}

GND_1 :: rl.Color{25, 165, 55, 255}
GND_2 :: rl.Color{75, 155, 60, 255}
GND_3 :: rl.Color{75, 155, 60, 255}
GND_4 :: rl.Color{40, 210, 65, 255}
GND_5 :: rl.Color{75, 155, 60, 255}
GND_6 :: rl.Color{74, 125, 70, 255}
GND_7 :: rl.Color{120, 130, 45, 255}
GND_8 :: rl.Color{160, 221, 175, 255}

make_stages :: proc(horizon: HorizonData) -> [15]Stage {

	// Some shared stage setup
	hallway_width: f32 = horizon.spawn_w * 0.1
	random_leader_ctrl := LeaderControl {
		min_turn_duration     = 0.25,
		turn_duration_scale   = 0.5,
		chance_to_go_straight = 0.1,
		x_reset_threshold     = 0.8,
	}

	stages := [15]Stage {
		Stage {
			duration = 10000,
			tris = TFixed{2, 12},
			data = StageHallway{width = hallway_width, spawns_per_sec = 75},
			colors = StageColors{SKY_1, GND_1},
		},
		// Guide-in hallway (gives player a chance to ready them selves)
		Stage {
			duration = 3,
			tris = TFixed{2, 12},
			data = StageHallway{width = hallway_width, spawns_per_sec = 75},
			colors = StageColors{SKY_1, GND_1},
		},
		// First random area
		Stage {
			duration = 15,
			tris = TFixed{2, 12},
			data = StageRandom{spawns_per_sec = 20, max_jitter_factor = 0.15},
			leader_ctrl = random_leader_ctrl,
		},
		// Easy grid area, to warm up
		Stage {
			duration = 10,
			tris = TFixed{2, 12},
			data = StageGrid{x_spacing = 20, t_spacing = 0.35},
			colors = StageColors{SKY_2, GND_2},
		},
		// Simple hallway to break up areas
		Stage {
			duration = 3,
			tris = TMixed{2, 12, 6, 8},
			data = StageHallway{width = hallway_width * 1.5, spawns_per_sec = 100},
		},
		// Dark random area
		Stage {
			duration = 20,
			tris = TFixed{2, 12},
			data = StageRandom{spawns_per_sec = 30, max_jitter_factor = 0.15},
			colors = StageColors{SKY_3, GND_3},
			leader_ctrl = random_leader_ctrl,
		},
		// Snaking corridor!
		Stage {
			duration = 30,
			tris = TFixed{4, 8},
			hide_close_triangles = true,
			data = StageLeaderCorridor{width = 0.14 * horizon.half_w, t_spacing = 0.075},
			colors = StageColors{SKY_4, GND_4},
			leader_ctrl = LeaderControl {
				min_turn_duration = 0.25,
				turn_duration_scale = 0.75,
				chance_to_go_straight = 0.2,
				x_reset_threshold = 10,
			},
		},
		// Halway to help get out of corridor
		Stage {
			duration = 3,
			tris = TFixed{2, 12},
			data = StageHallway{width = hallway_width * 1.5, spawns_per_sec = 35},
		},
		// Wall area, slightly more difficult to survive
		Stage {
			duration = 10,
			init_delay_sec = 1.5,
			tris = TFixed{6, 8},
			data = StageWalls{gap_width = 12, t_spacing = 1.25, max_t_jitter_factor = 0.25},
			leader_ctrl = LeaderControl {
				min_turn_duration = 0.25,
				turn_duration_scale = 0.75,
				chance_to_go_straight = 0.2,
				x_reset_threshold = 0.75,
			},
			colors = StageColors{SKY_5, GND_5},
		},
		Stage {
			duration = 25,
			tris = TMixed{2, 12, 4, 8},
			data = StageRandom{spawns_per_sec = 50, max_jitter_factor = 0.15},
			leader_ctrl = random_leader_ctrl,
			colors = StageColors{SKY_6, GND_6},
		},
		Stage {
			duration = 20,
			init_delay_sec = 1.5,
			tris = TFixed{6, 8},
			data = StageWalls{gap_width = 12, t_spacing = 1.25, max_t_jitter_factor = 0.15},
			leader_ctrl = LeaderControl {
				min_turn_duration = 0.25,
				turn_duration_scale = 0.85,
				chance_to_go_straight = 0.05,
				x_reset_threshold = 0.75,
			},
		},
		Stage {
			duration = 3,
			tris = TFixed{4, 8},
			data = StageHallway{width = hallway_width * 1.25, spawns_per_sec = 75},
		},
		// Skinny/tall field
		Stage {
			duration = 60,
			tris = TRange{1, 2, 7, 18},
			data = StageRandom{spawns_per_sec = 65},
			leader_ctrl = random_leader_ctrl,
			colors = StageColors{SKY_7, GND_7},
		},
		// Mixed field
		Stage {
			duration = 60,
			tris = TMixed{2, 12, 6, 6},
			data = StageRandom{spawns_per_sec = 60},
			leader_ctrl = random_leader_ctrl,
		},
		// End mixed stage
		Stage {
			duration = 10000,
			tris = TMixed{2, 12, 4, 8},
			data = StageRandom{spawns_per_sec = 70},
			leader_ctrl = random_leader_ctrl,
			colors = StageColors{SKY_8, GND_8},
		},
	}

	// Fill in any missing stage colors (repeat from previous stage)
	for idx in 1 ..< len(stages) {
		if stages[idx].colors.sky[3] == 0 {
			stages[idx].colors = stages[idx - 1].colors
		}
	}

	return stages
}
