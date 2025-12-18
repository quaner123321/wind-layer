#defines

precision highp float;

uniform sampler2D u_texture;
uniform sampler2D u_textureNext;
uniform sampler2D colorRampTexture;
uniform float u_fade_t;

uniform vec2 u_image_res;
uniform vec2 colorRange;
uniform bool useDisplayRange;
uniform vec2 displayRange;
uniform float opacity;

varying vec2 vUv;
varying float v_speed;
varying float v_speed_t;
varying float v_angle;
varying vec2 v_coords;

float line_distance(vec2 p, vec2 p1, vec2 p2) {
    vec2 center = (p1 + p2) * 0.5;
    float len = length(p2 - p1);
    vec2 dir = (p2 - p1) / len;
    vec2 rel_p = p - center;
    return dot(rel_p, vec2(dir.y, -dir.x));
}

float segment_distance(vec2 p, vec2 p1, vec2 p2) {
    vec2 center = (p1 + p2) * 0.5;
    float len = length(p2 - p1);
    vec2 dir = (p2 - p1) / len;
    vec2 rel_p = p - center;
    float dist1 = abs(dot(rel_p, vec2(dir.y, -dir.x)));
    float dist2 = abs(dot(rel_p, dir)) - 0.5 * len;
    return max(dist1, dist2);
}

vec4 draw_line(float d, vec4 color) {
    float lineWidth = 0.04;
    float aa = 0.01;
    
    if (d < lineWidth + aa) {
        float alpha = 1.0 - smoothstep(lineWidth, lineWidth + aa, abs(d));
        return vec4(color.rgb, color.a * alpha);
    }
    return vec4(0.0);
}

// 绘制风矢 - 从起点（逆风端）开始画风羽
vec4 draw_wind_barb(vec2 uv, float speed) {
    vec4 color = vec4(1.0, 1.0, 1.0, 1.0); // 白色风矢
    vec4 result = vec4(0.0);
    
    // 风向杆（竖线，从上到下表示风的来向）
    float d_pole = segment_distance(uv, vec2(0.0, 0.5), vec2(0.0, -0.5));
    vec4 pole_color = draw_line(d_pole, color);
    result = mix(result, pole_color, pole_color.a);
    
    // 风速计算 - 按照气象标准
    // 短划线：2米/秒
    // 长划线：4米/秒
    // 风三角：20米/秒
    
    // 计算各类型风羽的数量
    int total_units = int(floor(speed / 2.0)); // 每2米/秒一个单位
    
    // 首先计算风三角数量（每20米/秒一个三角）
    int triangles = int(floor(float(total_units) / 10.0));
    // 剩余单位
    int remaining_units = total_units - triangles * 10;
    // 长划线数量（每4米/秒一个）
    int long_lines = int(floor(float(remaining_units) / 2.0));
    // 短划线数量
    int short_lines = remaining_units - long_lines * 2;
    
    float spacing = 0.2; // 风羽间距
    float startY = 0.4; // 起点位置（逆风端）
    
    // === 从起点（逆风端）开始画风羽 ===
    float currentY = startY;
    
    // 1. 先绘制风三角（从起点开始画）
    for (int i = 0; i < 4; i++) {
        if (i < triangles) {
            // 风三角：等腰三角形，底边在风向杆上
            vec2 base_mid = vec2(0.0, currentY);
            vec2 base_left = vec2(-0.08, currentY - 0.1);
            vec2 base_right = vec2(0.08, currentY - 0.1);
            vec2 tip = vec2(0.15, currentY);
            
            // 绘制左边
            float d_left = segment_distance(uv, base_mid, base_left);
            // 绘制右边
            float d_right = segment_distance(uv, base_mid, base_right);
            // 绘制底边
            float d_base = segment_distance(uv, base_left, base_right);
            // 绘制封闭边
            float d_close = segment_distance(uv, base_right, tip);
            float d_close2 = segment_distance(uv, tip, base_left);
            
            float d_tri = min(min(d_left, d_right), min(d_base, min(d_close, d_close2)));
            
            vec4 tri_color = draw_line(d_tri, color);
            result = mix(result, tri_color, tri_color.a);
            
            // 移动到下一个位置
            currentY -= spacing * 0.8; // 风三角间距稍大
        }
    }
    
    // 2. 然后绘制长划线（在三角形之后）
    for (int i = 0; i < 8; i++) {
        if (i < long_lines) {
            vec2 p1 = vec2(0.0, currentY);
            vec2 p2 = vec2(0.4, currentY); // 长划线
            float d_long = segment_distance(uv, p1, p2);
            
            vec4 long_color = draw_line(d_long, color);
            result = mix(result, long_color, long_color.a);
            
            // 移动到下一个位置
            currentY -= spacing;
        }
    }
    
    // 3. 最后绘制短划线
    for (int i = 0; i < 8; i++) {
        if (i < short_lines) {
            vec2 p1 = vec2(0.0, currentY);
            vec2 p2 = vec2(0.2, currentY); // 短划线
            float d_short = segment_distance(uv, p1, p2);
            
            vec4 short_color = draw_line(d_short, color);
            result = mix(result, short_color, short_color.a);
            
            // 移动到下一个位置
            currentY -= spacing;
        }
    }
    
    return result;
}

void main() {
    // 检查是否有有效数据
    if (v_speed <= 0.0) {
        discard;
    }
    
    // 检查显示范围
    bool display = true;
    if (useDisplayRange) {
        display = v_speed >= displayRange.x && v_speed <= displayRange.y;
    }
    
    if (!display) {
        discard;
    }
    
    // 获取颜色（从颜色纹理）
    // vec4 color = texture2D(colorRampTexture, vec2(v_speed_t, 0.5));
    vec4 color = vec4(1.0, 1.0, 1.0, 1.0); // 白色风矢
    
    // 将UV从[0,1]转换到[-0.5,0.5]
    vec2 uv = (vUv - vec2(0.5, 0.5)) * 2.0;
    
    // 绘制风矢
    vec4 barb = draw_wind_barb(uv, v_speed);
    
    if (barb.a < 0.01) {
        discard;
    }
    
    // 应用颜色和不透明度
    gl_FragColor = vec4(color.rgb * barb.rgb, barb.a * opacity);
}