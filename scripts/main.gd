extends Node2D
## Uygulamanın giriş noktası. M0 iskeletinde sadece ortamın ayakta olduğunu
## gösterir; oyun sahnesi M1'de buraya bağlanacak.


func _ready() -> void:
	print("Squishy Merge — iskelet ayakta. Godot %s" % Engine.get_version_info().string)
