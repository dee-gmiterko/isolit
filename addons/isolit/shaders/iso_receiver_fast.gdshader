shader_type canvas_item;
render_mode unshaded; // IsoLit does its own lighting; skip Godot's canvas light() pass

#include "res://addons/isolit/shaders/iso_receiver_common.gdshaderinc"
