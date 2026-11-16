shader_type canvas_item;
// Nước chảy kiểu pixel art cho các lớp ảnh mặt nước (Sprite2D phủ cả map).
// Mọi độ lệch đều làm tròn theo pixel và chạy theo nhịp `fps` để giữ nét pixel art.
//
// Dùng 2 kiểu:
//  - Lớp sóng / ánh sáng (vd 10_Bong_va_song_nuoc): flow_speed ≠ 0, row_wave > 0, sparkle > 0
//    → gợn trôi theo dòng, mỗi hàng lắc ngang, đốm sáng lấp lánh.
//  - Lớp mặt nước (vd 09_Mat_nuoc_muong): col_wave > 0
//    → mép giữa vùng bóng tối và vùng nước xanh nhấp nhô lên xuống.

// Nhịp khung hình của hiệu ứng (khung/giây)
uniform float fps = 8.0;
// Hàng pixel bắt đầu có nước (phía trên giữ nguyên)
uniform float water_top = 303.0;

// Trôi ngang (px/giây, âm = sang trái)
uniform float flow_speed = 0.0;
// Lắc ngang từng hàng (px)
uniform float row_wave = 0.0;
// Nhấp nhô dọc theo cột (px)
uniform float col_wave = 0.0;
// Bước sóng (px) và tốc độ sóng
uniform float wave_length = 14.0;
uniform float wave_speed = 2.5;
// 0..1: tỉ lệ đốm sáng tắt / bật luân phiên
uniform float sparkle = 0.0;
// Kích thước khối đốm lấp lánh (px)
uniform float sparkle_block = 6.0;
// Tốc độ lấp lánh (lần đổi / giây)
uniform float sparkle_rate = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = floor(UV * tex_size);
	float t = floor(TIME * fps) / fps;

	if (p.y < water_top) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float depth = p.y - water_top;
		vec2 src = p;
		// Trôi theo dòng
		float flow = floor(t * flow_speed);
		src.x -= flow;
		// Lắc ngang theo hàng (hàng sâu hơn lắc chậm hơn một chút)
		src.x += round(sin(p.y * 0.9 + t * wave_speed) * row_wave);
		// Nhấp nhô dọc theo cột, mép trên cùng đứng yên để không hở khe
		float dy = round(sin(p.x * 6.2831 / wave_length + t * wave_speed) * col_wave);
		src.y = max(water_top, src.y + dy * clamp(depth / 3.0, 0.0, 1.0));
		src.x = mod(src.x, tex_size.x);

		vec4 c = texture(TEXTURE, (src + 0.5) / tex_size);
		if (sparkle > 0.0) {
			// Khối đốm đi theo dòng nước, mỗi khối bật / tắt ngẫu nhiên
			vec2 cell = floor(vec2(src.x, p.y) / sparkle_block);
			float phase = hash(cell * 1.7);
			float n = hash(cell + floor(TIME * sparkle_rate + phase) * 13.0);
			c.a *= n < sparkle ? 0.0 : 1.0;
		}
		COLOR = c;
	}
}
