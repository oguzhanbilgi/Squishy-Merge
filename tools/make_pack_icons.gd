extends SceneTree
## M8.5-10: Free Casual GUI paketinden secilen ikonlarin turetilmesi.
##
## Kaynak: `_visual_source/unity_free_casual_gui/.../Icons_white_brown/
## White_icon_No_shadow/*.svg` (Unco Games Studio, Unity Asset Store —
## lisans notu assets/visual/CREDITS.md). Runtime bu klasoru HIC okumuyor;
## yalnizca buradan cikan `assets/visual/ui/icons/*.png` dosyalarini okuyor.
##
## Turetme kurali:
##   - SVG, Godot'un kendi yukleyicisiyle (ThorVG) SIZE px yuksekliginde
##     rasterize ediliyor. Kaynak 54x55 civari vektor; 128 px her sekme /
##     buton olcusu icin fazlasiyla yeterli, kucultme runtime'da mipmap ile.
##   - RGB kanali SAF BEYAZA ceviriliyor, alfa aynen kaliyor. Paketin krem
##     tonu (#f4e7d6) `modulate` ile boyandiginda kirli renkler veriyordu;
##     beyaz maske ile ikon paletteki her renge temiz boyaniyor (alt sekme
##     altin, pasif lavanta, ayarlar krem...). Bu yuzden paketin kahverengi
##     ve golgeli varyantlari kullanilmadi — tek kaynak, tek maske.
##   - Kaynagin ic-golge filtresi (feGaussianBlur) ThorVG'de zaten
##     cizilmiyor; maske olarak kullanildigi icin bu bir kayip degil.
##
## Kullanim (headless calisir, Image'dan baska sey kullanmiyor):
##   godot --headless --path . -s res://tools/make_pack_icons.gd

const SRC_DIR: String = "res://_visual_source/unity_free_casual_gui/Free_Casual_GUI/Resource/Free_Casual_GUI/Icons_white_brown/White_icon_No_shadow"
const OUT_DIR: String = "res://assets/visual/ui/icons"
const SIZE: int = 128

## cikti adi -> kaynak dosya (paketin kendi adi, ".svg.svg" uzantisiyla).
## Paketteki bazi adlar yaniltici: `icon_reload` aslinda bir nota isareti
## (muzik), `icon_refresh` ise dairesel ok. Burada ciktilar ISLEVE gore
## adlandiriliyor, kaynak adina gore degil.
const ICONS: Dictionary = {
	"home": "icon_home_white.svg.svg",
	"play": "icon_play_white.svg.svg",
	"badge": "icon_badge_white.svg.svg",
	"cart": "icon_cart_white.svg.svg",
	"settings": "icon_settings_white.svg.svg",
	"volume": "icon_volume_white.svg.svg",
	"volume_mute": "icon_volume_mute_white.svg.svg",
	"close": "icon_close_white.svg.svg",
	"back": "icon_arrow_back_white.svg.svg",
	"info": "icon_info_white.svg.svg",
	"check": "icon_check_white.svg.svg",
	"trophy": "icon_trophy_white.svg.svg",
	"sparkle": "icon_sparkle_white.svg.svg",
	"gift": "icon_gift_white.svg.svg",
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var done: int = 0
	for out_name: String in ICONS:
		var src: String = SRC_DIR.path_join(ICONS[out_name])
		var svg: String = FileAccess.get_file_as_string(src)
		if svg.is_empty():
			printerr("kaynak okunamadi: ", src)
			continue
		var w: float = svg.get_slice("width=\"", 1).get_slice("\"", 0).to_float()
		var h: float = svg.get_slice("height=\"", 1).get_slice("\"", 0).to_float()
		var scale: float = float(SIZE) / maxf(w, h)
		var img := Image.new()
		if img.load_svg_from_string(svg, scale) != OK:
			printerr("rasterize edilemedi: ", src)
			continue
		_whiten(img)
		var out: String = OUT_DIR.path_join(out_name + ".png")
		img.save_png(ProjectSettings.globalize_path(out))
		print("%-14s %dx%d  <- %s" % [out_name, img.get_width(), img.get_height(), ICONS[out_name]])
		done += 1
	print("%d/%d ikon uretildi -> %s" % [done, ICONS.size(), OUT_DIR])
	quit()


## RGB'yi beyaza ceker, alfayi korur — ikon `modulate` ile boyanabilen
## bir maske olur.
func _whiten(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var a: float = img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
