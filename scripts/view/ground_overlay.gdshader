// Lays an image over parts of the ground: worn paths (path_layer.gd) and moss (moss_layer.gd).
// TEXTURE is the mask: one pixel per map cell, white = fully covered, smoothed between cells,
// so the covered areas get soft, rounded edges instead of square cells.
shader_type canvas_item;

uniform sampler2D overlay_texture : repeat_enable, filter_nearest;  // e.g. tiles/path.png
uniform vec2 tiles_on_map = vec2(1.0);   // map size in tiles: the image repeats once per tile
uniform bool use_texture = true;         // false = flat color (debug view)
uniform vec4 flat_color : source_color = vec4(1.0);
uniform float edge_softness = 0.25;      // how gradually a path fades out at its edge

void fragment() {
	float covered = texture(TEXTURE, UV).r;
	float amount = smoothstep(1.0 - edge_softness, 1.0, covered);
	vec4 ground = use_texture ? texture(overlay_texture, UV * tiles_on_map) : flat_color;
	COLOR = vec4(ground.rgb, ground.a * amount);
}
