class_name Queries

static func is_item():
	return ECS.world.query.with_all([C_Item])

static func is_weapon():
	return ECS.world.query.with_all([C_Weapon])

static func could_be_weapon_or_item():
	return ECS.world.query.with_any([C_Weapon, C_Item])

static func in_inventory():
	return ECS.world.query.with_all([C_InInventory])

static func is_active_weapon():
	return ECS.world.query.with_all([C_IsActiveWeapon])

static func is_active_item():
	return ECS.world.query.with_all([C_IsActiveItem])

static func is_dead():
	return ECS.world.query.with_any([C_Death])

static func is_not_dead():
	return ECS.world.query.with_none([C_Death])

static func is_players():
	return ECS.world.query.with_all([C_Player])

static func all_items_in_inventory():
	return combine(is_item(), in_inventory())

static func all_weapons_in_inventory():
	return combine(is_weapon(), in_inventory())

static func active_weapons():
	return combine(all_weapons_in_inventory(), is_active_weapon())

static func active_items():
	return combine(all_items_in_inventory(), is_active_item())

## This is a list of all the Status Effect type components
static func is_status_effect():
	return ECS.world.query.with_any([C_Fatigued, C_Frozen])

static func combine(a: QueryBuilder, b: QueryBuilder):
	return a.combine(b)
