shader_type canvas_item;

uniform vec4 brick_color;
uniform float cracked_amt;
uniform sampler2D crack_texture;  // Add this uniform for the texture

float blendOverlayFloat(in float base, in float blend) {
    return (base < .5)? (2.*base*blend): (1. - 2. * (1. - base) * (1. - blend));
}

vec3 blendOverlayVec3(in vec3 base, in vec3 blend) {
    return vec3(blendOverlayFloat(base.r, blend.r),
                blendOverlayFloat(base.g, blend.g),
                blendOverlayFloat(base.b, blend.b));
}

vec3 blendOverlay(in vec3 base, in vec3 blend, in float opacity) {
    return (blendOverlayVec3(base, blend) * opacity + base * (1. - opacity));
}

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
    vec3 og_color = vec3(COLOR.r, COLOR.g, COLOR.b);
    vec3 blend_color = vec3(brick_color.r, brick_color.g, brick_color.b);
    vec3 blended = blendOverlay(og_color, blend_color, 1.);
    
    // Sample the crack texture at the current UV coordinate
    vec4 crack = texture(crack_texture, UV);
    
    COLOR = vec4(blended.r, blended.g, blended.b, 1.0 - cracked_amt*crack.r);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
