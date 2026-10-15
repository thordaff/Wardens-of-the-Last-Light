class_name BattleTypes
## Tipe kelemahan: 6 senjata + 6 elemen (konsep-cerita.md, "Cakupan kelemahan").

enum Type { PEDANG, TOMBAK, BELATI, KAPAK, BUSUR, TONGKAT, API, ES, PETIR, ANGIN, CAHAYA, GELAP }

const NAMES: Array[String] = [
	"Pedang", "Tombak", "Belati", "Kapak", "Busur", "Tongkat",
	"Api", "Es", "Petir", "Angin", "Cahaya", "Gelap",
]
## Tanpa tipe (serangan musuh ke party).
const NONE := -1


static func is_element(type: int) -> bool:
	return type >= Type.API


static func type_name(type: int) -> String:
	if type < 0 or type >= NAMES.size():
		return "-"
	return NAMES[type]
