shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// I want to replace this green color with the a gradient from black to this green
	vec3 green = vec3(0.0, 0.51, 0.0);
	vec3 black = vec3(0.0, 0.0, 0.0);

	vec3 gradient = mix(black, green, 1.0 - UV.y * 2.0);
    
	float similarity = dot(normalize(COLOR.rgb), normalize(green));
	float factor = smoothstep(0.95, 1.0, similarity);
    
	COLOR.rgb = mix(COLOR.rgb, gradient, factor);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
