class_name InventoryQuickBar
extends VBoxContainer

@export var c_item: C_Item:
	set(v):
		if not v:
			hide_quick_bar()
			return
		c_item = v
		item_icon.texture = c_item.icon
		show_quick_bar()

@export var quantity := 1:
	set(v):
		quantity = v
		quantity_label.text = str(quantity)


@onready var item_icon: TextureRect = %ItemIcon
@onready var quantity_label: RichTextLabel = %QuantityLabel


func _ready():
	if not c_item:
		hide_quick_bar()
		return
	item_icon.texture = c_item.icon
	quantity_label.text = str(quantity)

func hide_quick_bar():
	item_icon.visible = false
	quantity_label.visible = false
func show_quick_bar():
	item_icon.visible = true
	quantity_label.visible = true
