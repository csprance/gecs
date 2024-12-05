extends GdUnitTestSuite


func test_a():
    var callable = func(): return ECS.world.query.with_all([C_Player, C_Velocity, C_PlayerMovement])
    var static_query = StaticQuery.new(callable)
    ResourceSaver.save(static_query, "res://game/lib/static_queries/my_test_static_query.tres",)