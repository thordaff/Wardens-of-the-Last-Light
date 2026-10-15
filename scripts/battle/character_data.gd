class_name CharacterData
extends Resource
## Data dasar satu anggota party. Disimpan sebagai .tres di data/characters/.

enum Weapon { PEDANG, TOMBAK, BELATI, KAPAK, BUSUR, TONGKAT }
enum Element { API, ES, PETIR, ANGIN, CAHAYA, GELAP }

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 100
@export var max_sp: int = 30
@export var weapons: Array[Weapon] = []
@export var elements: Array[Element] = []
