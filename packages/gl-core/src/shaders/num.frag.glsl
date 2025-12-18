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
float drawDigit(vec2 p, float digit) {
    // 字符大小 - 减小线宽让线条变细
    float w = 0.09;  // 宽度
    float h = 0.14;  // 高度
    float t = 0.016; // 减小线宽，从0.018改为0.012，让线条更细
    
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
    
    // 根据数字点亮相应的段 - 使用浮点数比较
    if (digit < 0.5) {  // digit == 0
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
        d = min(d, d_seg);
        d = min(d, e);
        d = min(d, f);
    } else if (digit > 0.5 && digit < 1.5) {  // digit == 1
        d = min(d, b);
        d = min(d, c);
    } else if (digit > 1.5 && digit < 2.5) {  // digit == 2
        d = min(d, a);
        d = min(d, b);
        d = min(d, g);
        d = min(d, e);
        d = min(d, d_seg);
    } else if (digit > 2.5 && digit < 3.5) {  // digit == 3
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
        d = min(d, d_seg);
        d = min(d, g);
    } else if (digit > 3.5 && digit < 4.5) {  // digit == 4
        d = min(d, f);
        d = min(d, g);
        d = min(d, b);
        d = min(d, c);
    } else if (digit > 4.5 && digit < 5.5) {  // digit == 5
        d = min(d, a);
        d = min(d, f);
        d = min(d, g);
        d = min(d, c);
        d = min(d, d_seg);
    } else if (digit > 5.5 && digit < 6.5) {  // digit == 6
        d = min(d, a);
        d = min(d, f);
        d = min(d, g);
        d = min(d, e);
        d = min(d, c);
        d = min(d, d_seg);
    } else if (digit > 6.5 && digit < 7.5) {  // digit == 7
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
    } else if (digit > 7.5 && digit < 8.5) {  // digit == 8
        d = min(d, a);
        d = min(d, b);
        d = min(d, c);
        d = min(d, d_seg);
        d = min(d, e);
        d = min(d, f);
        d = min(d, g);
    } else if (digit > 8.5) {  // digit == 9
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
    p.y += 0.04; // 进一步向下移动小数点，从0.03改为0.04
    return length(p) - 0.04; // 保持点的大小
}

// 绘制完整数字（xx.x格式）
vec4 drawNumber(vec2 uv, float value) {
    // 分解数字
    float integerPart = floor(value);
    float decimalPart = floor(fract(value) * 10.0);
    
    // 字符大小和间距 - 增加间距让小数点更明显
    float charWidth = 0.12;
    float spacing = 0.06; // 增加字符间距，从0.02改为0.03
    float dotSize = 0.02;
    float dotVerticalOffset = -0.05; // 进一步向下移动小数点，从-0.04改为-0.05
    
    // 小数点前后的额外间距
    float dotSpacingBefore = 0.06; // 小数点前的额外间距
    float dotSpacingAfter = 0.06;  // 小数点后的额外间距
    
    // 计算总宽度 - 增加小数点周围的间距
    float totalWidth;
    float startX;
    
    if (integerPart >= 10.0) {
        // 两位数：如"12.3"
        totalWidth = 3.0 * charWidth + 2.0 * spacing + dotSize + dotSpacingBefore + dotSpacingAfter;
        startX = -totalWidth * 0.5;
    } else {
        // 一位数：如"5.2"
        totalWidth = 2.0 * charWidth + spacing + dotSize + dotSpacingBefore + dotSpacingAfter;
        startX = -totalWidth * 0.5;
    }
    
    float minDist = 1000.0;
    float currentX = startX;
    
    // 绘制十位数（如果有）
    if (integerPart >= 10.0) {
        float tens = floor(integerPart / 10.0);
        vec2 charPos = uv - vec2(currentX + charWidth*0.5, 0.0);
        minDist = min(minDist, drawDigit(charPos, tens));
        currentX += charWidth + spacing;
    }
    
    // 绘制个位数
    float ones = mod(integerPart, 10.0);
    vec2 onesPos = uv - vec2(currentX + charWidth*0.5, 0.0);
    minDist = min(minDist, drawDigit(onesPos, ones));
    currentX += charWidth + dotSpacingBefore; // 增加小数点前的间距
    
    // 绘制小数点
    vec2 dotPos = uv - vec2(currentX + dotSize*0.5, dotVerticalOffset);
    minDist = min(minDist, drawDot(dotPos));
    currentX += dotSize + dotSpacingAfter; // 增加小数点后的间距
    
    // 绘制小数位
    vec2 decimalPos = uv - vec2(currentX + charWidth*0.5, 0.0);
    minDist = min(minDist, drawDigit(decimalPos, decimalPart));
    
    // 计算alpha - 减小边缘平滑范围，让细线条更清晰
    float alpha = 1.0 - smoothstep(0.0, 0.006, minDist); // 从0.008改为0.006
    
    // 白色数字
    return vec4(1.0, 1.0, 1.0, alpha);
}

// 简化的数字绘制
vec4 drawSimpleNumber(vec2 uv, float value) {
    // 将UV中心化并放大
    uv = (uv - vec2(0.5, 0.5)) * 4.0;
    
    // 进一步放大数字，使其更清晰
    uv *= 1.5;
    
    // 增加对比度，让数字更清晰
    vec4 number = drawNumber(uv, value);
    number.a = clamp(number.a * 1.3, 0.0, 1.0); // 从1.2改为1.3，增加对比度
    
    return number;
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