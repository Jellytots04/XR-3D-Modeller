extends Node3D

# Viewport
@onready var viewport = $Viewport/Viewport

# Reference to TabContainer
@onready var tab_container = viewport.get_node("Panel/Container/ControllerDisplay")
@onready var buttons = viewport.get_node("Panel/Container/Buttons")

# References to buttons
@onready var prev_tab_btn = buttons.get_node("BackTab")
@onready var back_btn = buttons.get_node("BackPage")
@onready var exit_btn = buttons.get_node("Exit")
@onready var next_btn = buttons.get_node("NextPage")
@onready var next_tab_btn = buttons.get_node("NextTab")

# Track current page within each tab
var current_page_per_tab = {}  # {tab_index: page_index}
var tabs_pages = []  # Array of page arrays

func _ready():
	print("Manual script starting...")
	print("Tab count: ", tab_container.get_tab_count())
	
	# Build tabs_pages array (each tab's pages)
	for i in range(tab_container.get_tab_count()):
		var tab = tab_container.get_tab_control(i)
		var pages_container = tab.get_child(0)  # e.g., IntroPages
		print("Tab ", i, ": ", tab.name)
		print("  Children count: ", tab.get_child_count())
		var pages = pages_container.get_children()
		tabs_pages.append(pages)
		
		print("Tab ", i, " has ", pages.size(), " pages")
		
		# Initialize page index for this tab
		current_page_per_tab[i] = 0
		
		# Hide all pages except first
		for j in range(pages.size()):
			pages[j].visible = (j == 0)
	
	# Connect buttons
	prev_tab_btn.pressed.connect(_on_prev_tab_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	next_tab_btn.pressed.connect(_on_next_tab_pressed)
	
	# Connect tab changes (built-in signal)
	tab_container.tab_changed.connect(_on_tab_changed)
	
	# Update buttons initially
	update_buttons()
	
	print("Manual script ready!")

func _on_tab_changed(tab_idx: int):
	# User clicked a tab - show that tab's current page
	AudioManager.play_icon_click()
	show_current_page_of_tab(tab_idx)
	update_buttons()

func show_current_page_of_tab(tab_idx: int):
	var pages = tabs_pages[tab_idx]
	var current_page_idx = current_page_per_tab[tab_idx]
	
	# Hide all pages in this tab
	for page in pages:
		page.visible = false
	
	# Show current page
	pages[current_page_idx].visible = true

func get_current_tab_index() -> int:
	return tab_container.current_tab

func get_current_page_index() -> int:
	return current_page_per_tab[get_current_tab_index()]

func set_current_page(page_idx: int):
	var tab_idx = get_current_tab_index()
	current_page_per_tab[tab_idx] = page_idx
	show_current_page_of_tab(tab_idx)

# PREV TAB - Jump to last page of previous tab
func _on_prev_tab_pressed():
	AudioManager.play_icon_click()
	var current_tab = get_current_tab_index()
	if current_tab > 0:
		var prev_tab = current_tab - 1
		tab_container.current_tab = prev_tab
		
		# Jump to last page of previous tab
		var last_page = tabs_pages[prev_tab].size() - 1
		current_page_per_tab[prev_tab] = last_page
		show_current_page_of_tab(prev_tab)
		update_buttons()

# BACK - Previous page
func _on_back_pressed():
	AudioManager.play_icon_click()
	var tab_idx = get_current_tab_index()
	var page_idx = get_current_page_index()
	
	if page_idx > 0:
		# Previous page in same tab
		set_current_page(page_idx - 1)
	else:
		# First page - go to previous tab's last page
		if tab_idx > 0:
			var prev_tab = tab_idx - 1
			tab_container.current_tab = prev_tab
			var last_page = tabs_pages[prev_tab].size() - 1
			current_page_per_tab[prev_tab] = last_page
			show_current_page_of_tab(prev_tab)
	
	update_buttons()

# NEXT - Next page
func _on_next_pressed():
	AudioManager.play_icon_click()
	var tab_idx = get_current_tab_index()
	var page_idx = get_current_page_index()
	var max_pages = tabs_pages[tab_idx].size()
	
	if page_idx < max_pages - 1:
		# Next page in same tab
		set_current_page(page_idx + 1)
	else:
		# Last page - go to next tab's first page
		if tab_idx < tab_container.get_tab_count() - 1:
			tab_container.current_tab = tab_idx + 1
			current_page_per_tab[tab_idx + 1] = 0
			show_current_page_of_tab(tab_idx + 1)
		else:
			# Last page of last tab - close
			_on_exit_pressed()
			return
	
	update_buttons()

# NEXT TAB - Jump to first page of next tab
func _on_next_tab_pressed():
	AudioManager.play_icon_click()
	var current_tab = get_current_tab_index()
	if current_tab < tab_container.get_tab_count() - 1:
		tab_container.current_tab = current_tab + 1
		current_page_per_tab[current_tab + 1] = 0
		show_current_page_of_tab(current_tab + 1)
		update_buttons()

# EXIT
func _on_exit_pressed():
	AudioManager.play_icon_click()
	print("Manual closed")
	queue_free()

func update_buttons():
	var tab_idx = get_current_tab_index()
	var page_idx = get_current_page_index()
	var total_tabs = tab_container.get_tab_count()
	
	# Disable Prev Tab on first tab
	prev_tab_btn.disabled = (tab_idx == 0)
	
	# Disable Back on first page of first tab
	back_btn.disabled = (tab_idx == 0 and page_idx == 0)
	
	# Disable Next Tab on last tab
	next_tab_btn.disabled = (tab_idx == total_tabs - 1)
	
	# Change Next to "Finish" on last page of last tab
	var is_last = (tab_idx == total_tabs - 1 and page_idx == tabs_pages[tab_idx].size() - 1)
	next_btn.text = "Finish" if is_last else "Page >"
