class_name HUD 
extends Ui


@onready var health_bars: HealthBars = %HealthBars
@onready var radar :Radar= %Radar
@onready var weapon_quick_bar : InventoryQuickBar = %WeaponQuickBar
@onready var item_quick_bar : InventoryQuickBar = %ItemQuickBar
@onready var score : RichTextLabel = %Score


func on_ready() -> void:
    score.text = str(GameState.score)
    GameState.inventory_item_added.connect(update_from_game_state)
    GameState.inventory_item_removed.connect(update_from_game_state)
    GameState.weapon_changed.connect(update_from_game_state)
    GameState.item_changed.connect(update_from_game_state)
    GameState.item_used.connect(update_from_game_state)
    GameState.weapon_fired.connect(update_from_game_state)


func update_from_game_state(item: Entity) -> void:
    weapon_quick_bar.c_item = GameState.active_weapon.get_component(C_Weapon) if GameState.active_weapon else null
    weapon_quick_bar.quantity = InventoryUtils.get_item_quantity(GameState.active_weapon)
    
    item_quick_bar.c_item = GameState.active_item.get_component(C_Item) if GameState.active_item else null
    item_quick_bar.quantity = InventoryUtils.get_item_quantity(GameState.active_item)