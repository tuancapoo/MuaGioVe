shader_type canvas_item;
// Đổi màu viền khung thoại (Dialogue Box.aseprite) theo nhân vật đang nói.
// Chỉ thay các pixel tông tím nhạt của viền gốc; nền đen & mũi tên trắng giữ nguyên.
// Giữ độ sáng tương đối của từng pixel nên các chi tiết sáng/tối của viền vẫn còn.

uniform vec4 border_color : source_color = vec4(0.51, 0.49, 0.72, 1.0);

const vec3 BASE = vec3(0.51, 0.49, 0.72); // màu viền gốc trong file aseprite
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, LUMA);
	bool is_border = (c.b - c.r) > 0.12 && lum > 0.25 && lum < 0.85;
	if (is_border) {
		c.rgb = clamp(border_color.rgb * (lum / dot(BASE, LUMA)), 0.0, 1.0);
	}
	COLOR = c * COLOR;
}
