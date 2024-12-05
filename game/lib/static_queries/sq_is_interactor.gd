class_name SQ_IsInteractor
extends StaticQuery

func query():
	return ECS.world.query.with_all([C_Interactor])