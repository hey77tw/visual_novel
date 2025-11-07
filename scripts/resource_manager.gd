extends Node
class_name ResourceManager

# ===== 資源緩存 =====
var background_cache: Dictionary = {}  # 背景圖片緩存
var character_cache: Dictionary = {}  # 角色圖片緩存
var sound_cache: Dictionary = {}  # 音效緩存
var story_resource: StoryResource = null  # 故事資源

# ===== 資源路徑列表 =====
# 背景圖片列表
const BACKGROUND_PATHS = [
	"a-park.png",
	"a-drink-shop.png",
	"a-hospital.png",
	"a-living-room.png",
	"a-sea-wall-by-the-ocean.png",
	"a-small-live-house.png",
	"a-supermarket.png",
	"an-old-house.png",
	"old-bookstore.png",
	"train-station.png"
]

# 結局圖片列表
const ENDING_PATHS = [
	"ending-dog.png",
	"ending-fail.png",
	"ending-home.png",
	"ending-sunshine.png"
]

# 角色圖片列表
const CHARACTER_PATHS = [
	"boy-a-angry.png",
	"boy-a-happy.png",
	"boy-a-normal.png",
	"boy-a-sad.png",
	"boy-a-surprise.png",
	"girl-a-angry.png",
	"girl-a-happy.png",
	"girl-a-normal.png",
	"girl-a-sad.png",
	"girl-a-surprise.png"
]

# 音效列表
const SOUND_PATHS = [
	"アスファルトの上を歩く2.mp3",
	"カーソル移動1.mp3",
	"ドアを開ける1.mp3",
	"公園1.mp3",
	"剣で斬る1.mp3",
	"犬の鳴き声1.mp3",
	"狂犬が連続で吠える.mp3",
	"馬が走る1.mp3"
]

# ===== 載入狀態 =====
var is_loading: bool = false
var loading_progress: float = 0.0
var total_resources: int = 0
var loaded_resources: int = 0

# ===== 初始化 =====
func _ready():
	# 計算總資源數量
	total_resources = BACKGROUND_PATHS.size() + ENDING_PATHS.size() + CHARACTER_PATHS.size() + SOUND_PATHS.size() + 1  # +1 for story
	# 開始預載入資源
	preload_all_resources()

# ===== 載入隊列 =====
var load_queue: Array = []  # 待載入的資源隊列
var current_load_index: int = 0  # 當前載入索引
const RESOURCES_PER_FRAME = 5  # 每幀載入的資源數量（增加以加快載入）

# ===== 預載入所有資源 =====
func preload_all_resources():
	is_loading = true
	loaded_resources = 0
	loading_progress = 0.0
	current_load_index = 0
	
	# 構建載入隊列
	load_queue.clear()
	
	# 優先載入故事資源（最重要）
	load_queue.append({"type": "story", "path": "res://assets/story/my_story.tres"})
	
	# 載入背景圖片
	for bg_name in BACKGROUND_PATHS:
		load_queue.append({"type": "background", "name": bg_name, "path": "res://assets/backgrounds/" + bg_name})
	
	# 載入結局圖片
	for ending_name in ENDING_PATHS:
		load_queue.append({"type": "ending", "name": ending_name, "path": "res://assets/endings/" + ending_name})
	
	# 載入角色圖片
	for char_name in CHARACTER_PATHS:
		load_queue.append({"type": "character", "name": char_name, "path": "res://assets/characters/" + char_name})
	
	# 載入音效
	for sound_name in SOUND_PATHS:
		load_queue.append({"type": "sound", "name": sound_name, "path": "res://assets/sounds/" + sound_name})
	
	# 開始分幀載入
	call_deferred("_load_next_batch")

# ===== 分幀載入資源 =====
func _load_next_batch():
	if current_load_index >= load_queue.size():
		# 所有資源載入完成
		is_loading = false
		print("所有資源預載入完成！")
		return
	
	# 每幀載入指定數量的資源
	var loaded_this_frame = 0
	while current_load_index < load_queue.size() and loaded_this_frame < RESOURCES_PER_FRAME:
		var item = load_queue[current_load_index]
		_load_resource_item(item)
		current_load_index += 1
		loaded_resources += 1
		loaded_this_frame += 1
		loading_progress = float(loaded_resources) / float(total_resources)
	
	# 繼續載入下一批
	call_deferred("_load_next_batch")

# ===== 載入單個資源 =====
func _load_resource_item(item: Dictionary):
	match item["type"]:
		"story":
			story_resource = load(item["path"]) as StoryResource
		"background":
			var texture = load(item["path"])
			if texture:
				background_cache[item["name"]] = texture
		"ending":
			var texture = load(item["path"])
			if texture:
				background_cache[item["name"]] = texture  # 結局圖片也存到背景緩存
		"character":
			var texture = load(item["path"])
			if texture:
				character_cache[item["name"]] = texture
		"sound":
			var sound = load(item["path"])
			if sound:
				sound_cache[item["name"]] = sound

# ===== 獲取背景圖片 =====
func get_background(image: String, is_ending: bool = false) -> Texture2D:
	var cache_key = image
	if background_cache.has(cache_key):
		return background_cache[cache_key]
	
	# 如果緩存中沒有，則載入（不應該發生，但作為後備）
	var path = "res://assets/" + ("endings/" if is_ending else "backgrounds/") + image
	var texture = load(path)
	if texture:
		background_cache[cache_key] = texture
	return texture

# ===== 獲取角色圖片 =====
func get_character(image: String) -> Texture2D:
	if character_cache.has(image):
		return character_cache[image]
	
	# 如果緩存中沒有，則載入（不應該發生，但作為後備）
	var path = "res://assets/characters/" + image
	var texture = load(path)
	if texture:
		character_cache[image] = texture
	return texture

# ===== 獲取音效 =====
func get_sound(sound_name: String) -> AudioStream:
	if sound_cache.has(sound_name):
		return sound_cache[sound_name]
	
	# 如果緩存中沒有，則載入（不應該發生，但作為後備）
	var path = "res://assets/sounds/" + sound_name
	var sound = load(path)
	if sound:
		sound_cache[sound_name] = sound
	return sound

# ===== 獲取故事資源 =====
func get_story_resource() -> StoryResource:
	return story_resource

# ===== 檢查載入狀態 =====
func is_resources_ready() -> bool:
	# 只要故事資源載入完成就可以開始遊戲，其他資源在背景載入
	return story_resource != null

