shader_type canvas_item;
// Hiệu ứng sáng viền + nâng sáng nhẹ kiểu pixel art khi Minh lại gần vật tương tác (balo, tủ áo quần, cửa).

uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.93, 0.62, 1.0);
uniform float brighten : hint_range(0.0, 0.5) = 0.20;
uniform float pulse_speed = 3.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (highlight <= 0.001) {
		COLOR = tex;
	} else {
		float pulse = 0.80 + 0.20 * sin(TIME * pulse_speed);
		float h = highlight * pulse;
		if (tex.a < 0.1) {
			vec2 px = TEXTURE_PIXEL_SIZE;
			float n = 0.0;
			n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
			n = max(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
			n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
			n = max(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
			if (n > 0.1) {
				COLOR = vec4(outline_color.rgb, outline_color.a * h);
			} else {
				COLOR = tex;
			}
		} else {
			vec3 lit = mix(tex.rgb, tex.rgb + vec3(brighten) * outline_color.rgb, h);
			COLOR = vec4(lit, tex.a);
		}
	}
}
