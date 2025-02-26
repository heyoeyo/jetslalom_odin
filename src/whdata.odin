package main

import "core:math"


WHData :: struct {
	/*
    Structure used to hold data for screens or similar objects,
    Holds multiple type variants for convenience
    */
	wi:      i32,
	hi:      i32,
	w:       f32,
	h:       f32,
	half_w:  f32,
	half_h:  f32,
	half_wi: i32,
	half_hi: i32,
}

WHData_create_i32 :: proc(width, height: i32) -> WHData {
	/* Constructor for width-height data */

	half_w: f32 = f32(width) * 0.5
	half_h: f32 = f32(height) * 0.5
	return WHData {
		wi = width,
		hi = height,
		w = f32(width),
		h = f32(height),
		half_w = half_w,
		half_h = half_h,
		half_wi = i32(half_w),
		half_hi = i32(half_h),
	}
}


WHData_create_f32 :: proc(width, height: f32) -> WHData {
	/* Proc variant to handle alternate type inputs */
	return WHData_create_i32(i32(math.round(width)), i32(math.round(height)))
}

WHData_create :: proc {
	WHData_create_i32,
	WHData_create_f32,
}
