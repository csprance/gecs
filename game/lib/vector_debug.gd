extends Node2D

func draw_vector(vec: Vector2, vector_scale: float):
	draw_line(Vector2(0,0), Vector2(vec.x,0) * vector_scale, Color(0,0,1), 2, true)
	draw_line(Vector2(0,0), Vector2(0,vec.y) * vector_scale, Color(1,0,0), 2, true)
	draw_line(Vector2(0,0),  vec * vector_scale, Color(0.9,0,0.9), 2, true)
