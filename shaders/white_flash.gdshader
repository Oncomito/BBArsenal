shader_type canvas_item;

uniform bool flash = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (flash) {
		COLOR = vec4(flash_color.rgb, tex_color.a);
	} else {
		COLOR = tex_color;
	}
}
