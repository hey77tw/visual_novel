extends Control

# ===== 常數定義 =====
# 打字效果相關
const TYPING_SPEED = 0.08  # 每個字符的顯示間隔（秒）

# 音量相關
const DEFAULT_VOLUME = 0.8  # 預設音量 (0.0-1.0)
const MUTED_VOLUME_DB = -80  # 靜音時的音量分貝值

# UI 元件尺寸
const CHOICE_BUTTON_WIDTH = 200  # 選項按鈕的最小寬度
const CHOICE_BUTTON_HEIGHT = 40  # 選項按鈕的最小高度

# 字串處理相關
const PASSAGE_PREFIX_LENGTH = 3  # 段落標記 ":: " 的長度
const CHOICE_BRACKET_LENGTH = 4  # 選項標記 "[[" 和 "]]" 的總長度
const CHOICE_ARROW_LENGTH = 2  # 選項箭頭 "->" 的長度
const SPLIT_LIMIT = 1  # 字串分割的最大次數

# ===== 資源管理器 =====
const ResourceManagerScript = preload("res://scripts/resource_manager.gd")
var resource_manager = null  # 資源管理器

# ===== 音效播放器 =====
@onready var bgm_player = AudioStreamPlayer.new()  # 背景音樂播放器
@onready var sfx_player = AudioStreamPlayer.new()  # 音效播放器
@onready var ambient_player = AudioStreamPlayer.new()  # 環境音播放器

# ===== UI 節點引用 =====
@onready var menu_button = $MenuButton
@onready var menu_overlay = $MenuOverlay
@onready var choices_overlay = $ChoicesOverlay
@onready var pause_menu = $PauseMenu
@onready var about_panel = $AboutPanel
@onready var choices_container = $ChoicesContainer
@onready var background = $Background
@onready var character_sprite = $CharacterSprite
@onready var dialogue_bg = $DialogueBg
@onready var character_name = $DialogueBg/CharacterName
@onready var dialogue_text = $DialogueBg/DialogueText

# ===== 暫停選單節點 =====
@onready var resume_button = $PauseMenu/VBoxContainer/ResumeButton
@onready var restart_button = $PauseMenu/VBoxContainer/RestartButton
@onready var about_button = $PauseMenu/VBoxContainer/AboutButton
@onready var bgm_slider = $PauseMenu/VBoxContainer/SoundContainer/BGMSlider/HSlider
@onready var sfx_slider = $PauseMenu/VBoxContainer/SoundContainer/SFXSlider/HSlider

# ===== 關於面板節點 =====
@onready var close_button = $AboutPanel/VBoxContainer/CloseButton

# ===== 音效設定 =====
var bgm_volume = DEFAULT_VOLUME  # 背景音樂音量
var sfx_volume = DEFAULT_VOLUME  # 音效音量

# ===== 遊戲狀態變數 =====
var story_data = {}  # 儲存所有劇情段落的字典
var current_passage = "start"  # 目前的劇情段落名稱
var variables = {}  # 遊戲中的變數儲存
var current_dialogue_lines = []  # 目前的對話內容陣列
var current_dialogue_index = 0  # 目前對話的位置索引
var current_choices = []  # 目前的選項陣列
var current_typing_text = ""  # 正在打字的完整文字
var displayed_text = ""  # 已顯示的文字內容
var is_typing = false  # 是否正在執行打字效果
var typing_timer = 0.0  # 打字效果的計時器

# ===== 內建函式 =====
func _ready():
	# 創建並初始化資源管理器
	resource_manager = ResourceManagerScript.new()
	add_child(resource_manager)
	
	# 將音效播放器加入場景樹
	add_child(bgm_player)
	add_child(sfx_player)
	add_child(ambient_player)
	
	# 連接暫停選單按鈕信號
	menu_button.pressed.connect(_on_menu_button_pressed)
	resume_button.pressed.connect(_on_resume_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	about_button.pressed.connect(_on_about_button_pressed)
	close_button.pressed.connect(_on_about_close_button_pressed)
	
	# 連接音量控制滑桿信號
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# 等待資源載入完成後再開始遊戲
	await _wait_for_resources()
	
	# 載入故事檔案並開始遊戲
	load_story()
	show_passage("start")

# ===== 等待資源載入 =====
func _wait_for_resources():
	# 等待資源管理器載入完成
	while not resource_manager.is_resources_ready():
		await get_tree().process_frame

func _process(delta):
	# 處理打字效果的逐字顯示
	if is_typing:
		typing_timer += delta
		if typing_timer >= TYPING_SPEED:
			typing_timer = 0.0
			if displayed_text.length() < current_typing_text.length():
				displayed_text += current_typing_text[displayed_text.length()]
				dialogue_text.text = displayed_text
				# 每個字都播放打字音效
				play_sfx("カーソル移動1.mp3")
			else:
				is_typing = false

func _input(event):
	# 處理滑鼠點擊事件
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 如果選單或關於面板開啟，不處理點擊事件
		if pause_menu.visible or about_panel.visible or menu_overlay.visible or choices_overlay.visible:
			return
		
		# 檢查是否點擊了選單按鈕
		var mouse_pos = get_viewport().get_mouse_position()
		if menu_button.get_global_rect().has_point(mouse_pos):
			return
		
		if choices_container.get_child_count() == 0:
			if is_typing:
				skip_typing()
			else:
				# 結局段落點擊後重新開始遊戲
				if current_passage in ["dog-happy-end", "feeling-happy-end", "stalker-bad-end"]:
					show_passage("start")
				else:
					show_next_dialogue()

# ===== 故事系統 =====
func load_story():
	# 從資源管理器獲取故事資源
	var story_resource = resource_manager.get_story_resource()
	if not story_resource:
		print("Error: Could not load story file")
		return
		
	var story_text = story_resource.text
	var lines = story_text.split("\n")
	var current_passage_name = ""
	var current_passage_content = []
	
	# 逐行解析故事檔案
	for line in lines:
		line = line.strip_edges()
		if line.begins_with(":: "):
			# 儲存前一個段落的內容
			if current_passage_name != "":
				story_data[current_passage_name] = current_passage_content
			# 開始新段落，提取段落名稱
			current_passage_name = line.substr(PASSAGE_PREFIX_LENGTH).split(" {", true, SPLIT_LIMIT)[0]
			current_passage_content = []
		elif line != "":
			current_passage_content.append(line)
	
	# 儲存最後一個段落的內容
	if current_passage_name != "":
		story_data[current_passage_name] = current_passage_content

func show_passage(passage_name: String):
	# 顯示指定的劇情段落，包含場景更新、對話處理和選項生成
	if not story_data.has(passage_name):
		return
	
	current_passage = passage_name
	
	# 清除舊的選項按鈕和對話內容
	for child in choices_container.get_children():
		child.queue_free()
	choices_overlay.visible = false
	current_dialogue_lines = []
	current_choices = []
	current_dialogue_index = 0
	
	# 更新場景背景和角色
	update_scene(passage_name)
	
	# 處理段落中的每一行內容
	for line in story_data[passage_name]:
		if line.begins_with("[["):  # 處理選項
			var choice_text = line.substr(CHOICE_ARROW_LENGTH, line.length() - CHOICE_BRACKET_LENGTH).strip_edges()
			var parts = choice_text.split("->", true, SPLIT_LIMIT)
			current_choices.append({
				"text": parts[0].strip_edges(),
				"target": parts[1].strip_edges() if parts.size() > 1 else parts[0].strip_edges()
			})
		elif not line.begins_with("$"):  # 處理對話（跳過變數定義行）
			current_dialogue_lines.append(line)
	
	# 顯示第一句對話
	show_next_dialogue()

# ===== 場景管理 =====
func is_ending_scene(passage_name: String) -> bool:
	# 檢查是否為結局場景
	var ending_scenes = ["dog-happy-end", "feeling-happy-end", "stalker-bad-end"]
	return ending_scenes.has(passage_name)

func update_scene(passage_name: String):
	# 根據段落名稱更新場景背景、角色表情和環境音效
	stop_ambient()
	
	# 根據段落名稱設定對應的場景元素
	match passage_name:
		"start":
			set_background("a-park.png")
			set_character("girl-a-normal.png")
			play_ambient("公園1.mp3")
		# 狗狗路線
		"dog-route-1", "dog-route-2a", "dog-route-2b":
			set_character("girl-a-happy.png")
		# 感情路線
		"feeling-route-1":
			set_character("girl-a-normal.png")
		"feeling-route-2", "feeling-route-3":
			set_character("girl-a-sad.png")
		# 跟蹤狂路線
		"stalker-route-1", "stalker-route-2", "stalker-route-3":
			set_character("girl-a-surprise.png")
		# 結局場景
		"dog-happy-end":
			set_background("ending-dog.png", true)
			character_sprite.hide()
			play_sfx("犬の鳴き声1.mp3")
		"feeling-happy-end":
			set_background("ending-sunshine.png", true)
			character_sprite.hide()
		"stalker-bad-end":
			set_background("ending-fail.png", true)
			character_sprite.hide()

func set_background(image: String, is_ending: bool = false):
	# 從資源管理器獲取背景圖片（使用緩存）
	background.texture = resource_manager.get_background(image, is_ending)

func set_character(image: String):
	# 從資源管理器獲取角色圖片（使用緩存）
	character_sprite.texture = resource_manager.get_character(image)
	character_sprite.show()

# ===== 對話系統 =====
func show_next_dialogue():
	# 顯示下一句對話或生成選項按鈕
	if current_dialogue_index >= current_dialogue_lines.size():
		# 檢查是否為結局場景
		if is_ending_scene(current_passage):
			# 結局場景，顯示重新開始按鈕
			choices_overlay.visible = true
			var restart_choice_button = Button.new()
			restart_choice_button.text = "重新開始"
			restart_choice_button.custom_minimum_size = Vector2(CHOICE_BUTTON_WIDTH, CHOICE_BUTTON_HEIGHT)
			restart_choice_button.pressed.connect(_on_restart_button_pressed)
			choices_container.add_child(restart_choice_button)
		else:
			# 一般場景，顯示選項按鈕
			choices_overlay.visible = true
			for choice in current_choices:
				var button = Button.new()
				button.text = choice["text"]
				button.custom_minimum_size = Vector2(CHOICE_BUTTON_WIDTH, CHOICE_BUTTON_HEIGHT)
				button.pressed.connect(_on_choice_button_pressed.bind(choice["target"]))
				choices_container.add_child(button)
		return
	
	# 顯示對話內容
	var line = current_dialogue_lines[current_dialogue_index]
	if "：" in line:
		# 分離角色名稱和對話內容
		var parts = line.split("：", true, SPLIT_LIMIT)
		character_name.text = parts[0]
		start_typing(parts[1].strip_edges())
	else:
		start_typing(line.strip_edges())
	
	current_dialogue_index += 1

# ===== 打字效果 =====
func start_typing(text: String):
	# 開始打字效果，逐字顯示文字
	current_typing_text = text
	displayed_text = ""
	is_typing = true
	typing_timer = 0.0
	dialogue_text.text = ""

func skip_typing():
	# 跳過打字效果，直接顯示完整文字
	if is_typing:
		displayed_text = current_typing_text
		dialogue_text.text = displayed_text
		is_typing = false

# ===== 音效系統 =====
func play_sfx(sound_name: String):
	# 播放音效（使用緩存）
	if sfx_volume <= 0:
		return
	var sound = resource_manager.get_sound(sound_name)
	if sound:
		sfx_player.stream = sound
		sfx_player.play()

func play_ambient(sound_name: String):
	# 播放環境音效（使用緩存）
	if bgm_volume <= 0:
		return
	var sound = resource_manager.get_sound(sound_name)
	if sound:
		ambient_player.stream = sound
		ambient_player.play()

func stop_ambient():
	# 停止環境音效
	ambient_player.stop()

# ===== 信號處理函式 =====
# 選項處理
func _on_choice_button_pressed(target: String):
	# 處理選項按鈕點擊事件
	play_sfx("カーソル移動1.mp3")
	show_passage(target)

# 暫停選單系統
func _on_menu_button_pressed():
	# 開啟暫停選單
	pause_menu.visible = true
	menu_overlay.visible = true
	if is_typing:
		skip_typing()
	
	# 更新音量滑桿的當前值
	bgm_slider.value = bgm_volume
	sfx_slider.value = sfx_volume

func _on_resume_button_pressed():
	# 關閉暫停選單
	pause_menu.visible = false
	menu_overlay.visible = false

func _on_restart_button_pressed():
	# 重新開始遊戲
	pause_menu.visible = false
	menu_overlay.visible = false
	show_passage("start")

func _on_about_button_pressed():
	# 開啟關於面板
	about_panel.visible = true

func _on_about_close_button_pressed():
	# 關閉關於面板
	about_panel.visible = false

# 音量控制
func _on_bgm_volume_changed(value: float):
	# 處理背景音樂音量變更
	bgm_volume = value
	if value > 0:
		bgm_player.volume_db = linear_to_db(value)
		ambient_player.volume_db = linear_to_db(value)
	else:
		bgm_player.volume_db = MUTED_VOLUME_DB
		ambient_player.volume_db = MUTED_VOLUME_DB

func _on_sfx_volume_changed(value: float):
	# 處理音效音量變更
	sfx_volume = value
	if value > 0:
		sfx_player.volume_db = linear_to_db(value)
	else:
		sfx_player.volume_db = MUTED_VOLUME_DB
