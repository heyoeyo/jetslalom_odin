package main

import rl "vendor:raylib"

@(private = "file")
GFX_PATH :: "assets/player_gfx.png"

@(private = "file")
WAV_PATH :: "assets/explosion_sound.wav"


load_player_graphics :: proc() -> rl.Texture2D {

	/* Load player graphics in such a way that the data is bundled into the executable! */

	raw_img := #load(GFX_PATH)
	player_img := rl.LoadImageFromMemory(".png", raw_data(raw_img), i32(len(raw_img)))
	player_img_texture := rl.LoadTextureFromImage(player_img)
	// defer rl.UnloadTexture(player_img_texture)
	rl.UnloadImage(player_img)

	return player_img_texture
}


load_explosion_sound :: proc() -> rl.Sound {

	/* Load explosion sound effect in such a way that the data is bundled into the executable! */

	raw_wav := #load(WAV_PATH)
	explosion_wav := rl.LoadWaveFromMemory(".wav", raw_data(raw_wav), i32(len(raw_wav)))
	explosion_snd := rl.LoadSoundFromWave(explosion_wav)
	// defer rl.UnloadSound(explosion_snd)
	rl.UnloadWave(explosion_wav)

	return explosion_snd
}
