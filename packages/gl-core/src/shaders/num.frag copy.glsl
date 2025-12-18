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
varying vec2 v_coords;

// 绘制矩形字符
float drawRect(vec2 p, vec2 size) {
    vec2 d = abs(p) - size;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 绘制数字字符（使用线段组合）
float drawDigit(vec2 p, int digit) {
    // 字符大小
    float w = 0.08;  // 宽度
    float h = 0.12;  // 高度
    float t = 0.015; // 线宽
    
    float d = 1000.0;
    
    // 7段数码管布局
    //   a
    // f   b
    //   g
    // e   c
    //   d
    
    // 定义7段的位置
    // 水平段
    float a = drawRect(p - vec2(0.0, h*0.75), vec2(w*0.6, t));  // 上段
    float d_seg = drawRect(p - vec2(0.0, -h*0.75), vec2(w*0.6, t)); // 下段
    float g = drawRect(p - vec2(0.0, 0.0), vec2(w*0.6, t));       // 中段
    
    // 垂直段
    float f = drawRect(p - vec2(-w*0.6, h*0.35), vec2(t, h*0.25)); // 左上
    float b = drawRect(p - vec2(w*0.6, h*0.35), vec2(t, h*0.25));  // 右上
    float e = drawRect(p - vec2(-w*0.6, -h*0.35), vec2(t, h*0.25)); // 左下
    float c = drawRect(p - vec2(w*0.6, -h*0.35), vec2(t, h*0.25));  // 右下
    
    // 根据数字点亮相应的段
    if (digit == 0) {
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
        d = min(d, d_seg);
        d = min(d, e);
        d = min(d, f);
    } else if (digit == 1) {
        d = min(d, b);
        d = min(d, c);
    } else if (digit == 2) {
        d = min(d, a);
        d = min(d, b);
        d = min(d, g);
        d = min(d, e);
        d = min(d, d_seg);
    } else if (digit == 3) {
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
        d = min(d, d_seg);
        d = min(d, g);
    } else if (digit == 4) {
        d = min(d, f);
        d = min(d, g);
        d = min(d, b);
        d = min(d, c);
    } else if (digit == 5) {
        d = min(d, a);
        d = min(d, f);
        d = min(d, g);
        d = min(d, c);
        d = min(d, d_seg);
    } else if (digit == 6) {
        d = min(d, a);
        d = min(d, f);
        d = min(d, g);
        d = min(d, e);
        d = min(d, c);
        d = min(d, d_seg);
    } else if (digit == 7) {
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
    } else if (digit == 8) {
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
        d = min(d, d_seg);
        d = min(d, e);
        d = min(d, f);
        d = min(d, g);
    } else if (digit == 9) {
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
        d = min(d, d_seg);
        d = min(d, f);
        d = min(d, g);
    }
    
    return d;
}

// 绘制小数点
float drawDot(vec2 p) {
    return length(p) - 0.015;
}

// 绘制完整数字（xx.x格式）
vec4 drawNumber(vec2 uv, float value) {
    // 分解数字
    float integerPart = floor(value);
    float decimalPart = floor(fract(value) * 10.0);
    
    // 字符大小和间距
    float charWidth = 0.12;
    float spacing = 0.02;
    float dotSize = 0.01;
    
    // 计算总宽度
    float totalWidth;
    float startX;
    
    if (integerPart >= 10.0) {
        // 两位数：如"12.3"
        totalWidth = 3.0 * charWidth + 2.0 * spacing + dotSize;
        startX = -totalWidth * 0.5;
    } else {
        // 一位数：如"5.2"
        totalWidth = 2.0 * charWidth + spacing + dotSize;
        startX = -totalWidth * 0.5;
    }
    
    float minDist = 1000.0;
    float currentX = startX;
    
    // 绘制十位数（如果有）
    if (integerPart >= 10.0) {
        float tens = floor(integerPart / 10.0);
        vec2 charPos = uv - vec2(currentX + charWidth*0.5, 0.0);
        minDist = min(minDist, drawDigit(charPos, int(tens)));
        currentX += charWidth + spacing;
    }
    
    // 绘制个位数
    float ones = mod(integerPart, 10.0);
    vec2 onesPos = uv - vec2(currentX + charWidth*0.5, 0.0);
    minDist = min(minDist, drawDigit(onesPos, int(ones)));
    currentX += charWidth + spacing*0.5;
    
    // 绘制小数点
    vec2 dotPos = uv - vec2(currentX, 0.0);
    minDist = min(minDist, drawDot(dotPos));
    currentX += dotSize * 2.0;
    
    // 绘制小数位
    vec2 decimalPos = uv - vec2(currentX + charWidth*0.5, 0.0);
    minDist = min(minDist, drawDigit(decimalPos, int(decimalPart)));
    
    // 计算alpha
    float alpha = 1.0 - smoothstep(0.0, 0.005, minDist);
    
    // 白色数字
    return vec4(1.0, 1.0, 1.0, alpha);
}

// 简化的数字绘制（确保可见）
vec4 drawSimpleNumber(vec2 uv, float value) {
    // 将UV中心化并放大
    uv = (uv - vec2(0.5, 0.5)) * 4.0;
    
    // 确保数字不太小
    uv *= 1.2;
    
    return drawNumber(uv, value);
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
    
    // 绘制数字
    vec4 numberColor = drawSimpleNumber(vUv, v_speed);
    
    // 如果数字太淡，则不显示
    if (numberColor.a < 0.01) {
        discard;
    }
    
    // 白色数字
    gl_FragColor = vec4(1.0, 1.0, 1.0, numberColor.a * opacity);
}