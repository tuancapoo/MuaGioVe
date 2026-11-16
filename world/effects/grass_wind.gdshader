shader_type canvas_item;
// Cỏ lay theo gió kiểu pixel art cho lớp ảnh cỏ (Sprite2D phủ cả map).
// - Lay nhẹ liên tục theo sóng sin.
// - Thêm "cơn gió": dải gió chạy ngang qua cánh đồng, cỏ trong dải ngả mạnh hơn.
// Độ lệch làm tròn theo pixel, chạy theo nhịp `fps` để giữ nét pixel art.

// Nhịp khung hình (khung/giây)
uniform float fps = 8.0;
// Chỉ lay từ hàng pixel này trở xuống (phía trên giữ nguyên)
uniform float grass_top = 0.0;

// Lay nhẹ (px), bước sóng (px), tốc độ
uniform float sway = 1.0;
uniform float sway_length = 48.0;
uniform float sway_speed = 1.6;

// Cơn gió: độ ngả thêm (px), độ rộng dải gió (px), tốc độ chạy (px/giây, dương = gió thổi sang phải)
uniform float gust = 1.0;
uniform float gust_width = 260.0;
uniform float gust_speed = 70.0;

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = floor(UV * tex_size);
	float t = floor(TIME * fps) / fps;

	if (p.y < grass_top) {
		COLOR = texture(TEXTURE, UV);
	} else {
		// Lay nhẹ hai chiều, hơi lệch pha theo hàng để ngọn cỏ không cứng như một khối
		float s = sin(p.x * 6.2831 / sway_length + p.y * 0.05 + t * sway_speed) * sway;
		// Dải gió chạy ngang: chỉ ngả theo chiều gió
		float g = sin((p.x - t * gust_speed) * 6.2831 / gust_width);
		g = pow(max(g, 0.0), 4.0) * gust * sign(gust_speed);
		float dx = round(s + g);
		vec2 src = vec2(p.x - dx, p.y);
		COLOR = texture(TEXTURE, (src + 0.5) / tex_size);
	}
}
