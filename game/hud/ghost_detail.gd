class_name GhostDetail
extends VBoxContainer

signal closed()
signal card_inspected(card: CardInstance)
var ghost_id: int = 0
var campaign: Campaign
var preview: ModelPreview
var _details: Label
var _deck: HFlowContainer
var _title: Label
var _back: Button


func _init() -> void:
	add_theme_constant_override("separation", 8)
	var heading := HBoxContainer.new()
	_title = UiTheme.title("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_title)
	_back = Button.new()
	_back.pressed.connect(func() -> void: closed.emit())
	heading.add_child(_back)
	add_child(heading)
	preview = ModelPreview.new()
	preview.custom_minimum_size.y = 145
	add_child(preview)
	_details = ScreenLayout.centre(UiTheme.body(""))
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_details)
	_deck = HFlowContainer.new()
	_deck.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(_deck)


func bind(c: Campaign, id: int) -> void:
	campaign = c
	ghost_id = id
	refresh()


func refresh() -> void:
	var ghost := campaign.ladder.find(ghost_id)
	if ghost == null:
		closed.emit()
		return
	var content := campaign.content
	_title.text = ghost.name
	_back.text = content.text("ui.close")
	preview.show_ghost(ghost)
	var strength := Ladder.effective_strength(ghost, campaign.balance(), campaign.modifiers())
	var output := campaign.ladder.floor_output(ghost.floor, campaign.balance(), campaign.modifiers())
	var state := "restless" if ghost.restless else ("prepared" if ghost.prepared else ghost.kind)
	_details.text = content.text("ui.ghost.detail") \
		.replace("{floor}", str(ghost.floor)).replace("{state}", content.text("ui.ghost.state." + state)) \
		.replace("{strength}", Num.short(strength)).replace("{rate}", Num.short(output))
	if ghost.floor > WellView.MAX_FLOORS:
		_details.text += "\n" + content.text("ui.floor.deeper")
	_details.text += "\n" + GhostLine.doctrine_text(content, ghost)
	for child in _deck.get_children():
		child.free()
	for card in CardInspector.composition(ghost.deck):
		var view := CardView.new()
		view.bind(content, card, -1, true)
		view.pressed.connect(func(_index: int) -> void: card_inspected.emit(card))
		view.inspected.connect(func(record: CardInstance) -> void: card_inspected.emit(record))
		_deck.add_child(view)
