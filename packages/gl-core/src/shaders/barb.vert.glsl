#defines

attribute vec2 uv;
attribute vec2 position;
attribute vec2 coords;

uniform vec2 arrowSize;
uniform float u_head;

uniform vec2 resolution;
uniform float u_devicePixelRatio;
uniform vec2 pixelsToProjUnit;
uniform vec3 cameraPosition;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;
uniform mat4 projectionMatrix;

uniform vec2 u_extrude_scale;
uniform lowp float u_device_pixel_ratio;
uniform highp float u_camera_to_center_distance;

uniform sampler2D u_texture;
uniform sampler2D u_textureNext;
uniform sampler2D colorRampTexture;
uniform float u_fade_t;

uniform vec2 u_image_res;
uniform vec2 colorRange;
uniform bool useDisplayRange;
uniform bool u_flip_y;
uniform float u_zoomScale;
uniform vec2 displayRange;
uniform vec4 u_bbox;
uniform vec4 u_data_bbox;
uniform vec4 u_tile_bbox;

varying vec2 vUv;
varying float v_speed;
varying float v_speed_t;
varying float v_angle;
varying vec2 v_coords;

// 定义 π 常量
const float PI = 3.141592653589793;
const float DEG_TO_RAD = PI / 180.0;
const float RAD_TO_DEG = 180.0 / PI;

vec4 calcTexture(const vec2 puv) {
    // 检查纹理坐标是否有效
    if (puv.x < 0.0 || puv.x > 1.0 || puv.y < 0.0 || puv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 0.0); // 返回无效值
    }
    vec4 color0 = texture2D(u_texture, puv);
    vec4 color1 = texture2D(u_textureNext, puv);
    return mix(color0, color1, u_fade_t);
}

vec2 decodeValue(const vec2 vc) {
    vec4 rgba = calcTexture(vc);
    return rgba.rg;
}

vec2 bilinear(const vec2 uv) {
    // 首先检查UV是否在有效范围内
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return vec2(0.0, 0.0); // 返回零值
    }
    
    vec2 px = 1.0 / u_image_res;
    vec2 vc = (floor(uv * u_image_res)) * px;
    vec2 f = fract(uv * u_image_res);
    vec2 tl = decodeValue(vc);
    vec2 tr = decodeValue(vc + vec2(px.x, 0.0));
    vec2 bl = decodeValue(vc + vec2(0.0, px.y));
    vec2 br = decodeValue(vc + px);
    return mix(mix(tl, tr, f.x), mix(bl, br, f.x), f.y);
}

float getValue(vec2 rg) {
    return length(rg);
}

// 修正角度计算 - 使用手动转换避免 degrees() 函数
float getAngle(vec2 rg) {
    // UV分量的物理意义：
    // U: 东向为正（从西向东）
    // V: 北向为正（从南向北）
    // 计算风的来向角度
    
    // 使用 atan2 计算弧度
    float angle = atan(-rg.y, -rg.x); // 使用负号计算来向，注意：有些GLSL版本可能不支持 atan(y,x)
    
    // 将弧度转换为角度
    float degrees = angle * RAD_TO_DEG;
    
    // 调整到 0-360 范围
    if (degrees < 0.0) {
        degrees += 360.0;
    }
    
    // 转换回弧度返回
    return degrees * DEG_TO_RAD;
}

// 或者使用更兼容的版本：
float getAngleAlternative(vec2 rg) {
    // 替代方法：直接计算风向，不使用 degrees() 函数
    // 风的来向：atan2(-V, -U)
    
    float u = -rg.x;
    float v = -rg.y;
    
    // 使用标准的 atan(y, x) 计算角度
    float angle = atan(v, u); // 注意：检查你的GLSL版本是否支持两个参数的atan
    
    // 转换为气象角度：从北顺时针
    // 默认 atan 返回的是从正X轴开始的角度
    // 我们需要从正北（Y轴）开始顺时针的角度
    float meteorological_angle = PI / 2.0 - angle;
    
    // 标准化到 [0, 2π]
    if (meteorological_angle < 0.0) {
        meteorological_angle += 2.0 * PI;
    }
    
    return meteorological_angle;
}

void rotate2d(inout vec2 v, float a) {
    mat2 m = mat2(cos(a), -sin(a), sin(a), cos(a));
    v = m * v;
}

void main() {
    vUv = uv;
    v_coords = coords;
    
    vec2 pos = u_tile_bbox.xy + coords.xy * (u_tile_bbox.zw - u_tile_bbox.xy);
    
    // 计算位置
    vec2 worldPosition = (position.xy - vec2(0.5, 0.5)) * arrowSize * u_zoomScale * pixelsToProjUnit * u_devicePixelRatio;
    
    // 获取UV分量
    vec2 textureCoord = (pos.xy - u_data_bbox.xy) / (u_data_bbox.zw - u_data_bbox.xy);
    if (u_flip_y) {
        textureCoord = vec2(textureCoord.x, 1.0 - textureCoord.y);
    }
    
    vec2 rg = bilinear(textureCoord);
    float value = getValue(rg);
    
    // 使用替代方法计算角度，避免 degrees() 函数
    float u = rg.x;
    float v = rg.y;
    
    // 计算风的来向（从北顺时针）
    // 公式：角度 = (270 - atan2(v, u) * 180/π) % 360
    float angle_rad = atan(v, u); // 这是数学角度
    
    // 转换为气象角度（弧度）
    float meteo_angle = (PI * 1.5) - angle_rad; // 1.5π = 270度
    
    // 标准化到 [0, 2π]
    if (meteo_angle < 0.0) meteo_angle += 2.0 * PI;
    if (meteo_angle >= 2.0 * PI) meteo_angle -= 2.0 * PI;
    
    float rotation_angle = meteo_angle;
    
    // 旋转风矢
    rotate2d(worldPosition, rotation_angle);
    
    // 最终位置
    worldPosition += pos;
    
    // 传递变量
    v_speed = value;
    v_speed_t = clamp((value - colorRange.x) / (colorRange.y - colorRange.x), 0.0, 1.0);
    v_angle = meteo_angle;
    
    gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(worldPosition, 0.0, 1.0);
}