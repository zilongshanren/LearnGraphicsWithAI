// Step 2: SDF 布尔运算 — 用数学"雕刻"3D 形状
// 基于 Step 1，新增：并集、交集、差集运算 + smooth 版本
//
// 核心顿悟：传统建模需要顶点和三角面，但 SDF 的世界里
// 你可以用 min/max 这样简单的数学运算来"雕刻"任意形状
// 这就是为什么 SDF 在游戏中被广泛使用的原因之一

// ============================================================
// 1. SDF 基础图元
// ============================================================

float sdSphere(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
}

float sdPlane(vec3 p, float height) {
    return p.y - height;
}

// 新增：圆角长方体 SDF
// b = 半尺寸（长宽高各一半），r = 圆角半径
float sdRoundBox(vec3 p, vec3 center, vec3 b, float r) {
    vec3 q = abs(p - center) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// ============================================================
// 2. SDF 布尔运算 — 这是 SDF 最优雅的地方
//
// 直觉理解：
//   SDF(p) > 0 意味着 p 在物体外面
//   SDF(p) < 0 意味着 p 在物体里面
//
// 并集（Union）：min(a, b)
//   → 只要在任意一个物体"里面"（< 0），结果就 < 0
//   → 等价于：把两个物体放在一起
//
// 交集（Intersection）：max(a, b)
//   → 必须同时在两个物体"里面"，结果才 < 0
//   → 等价于：只保留两个物体重叠的部分
//
// 差集（Subtraction）：max(a, -b)
//   → 在 a 里面，但不在 b 里面
//   → 等价于：从 a 里面"挖掉" b 的形状
// ============================================================

// 硬边并集
float opUnion(float a, float b) {
    return min(a, b);
}

// 硬边交集
float opIntersect(float a, float b) {
    return max(a, b);
}

// 硬边差集
float opSubtract(float a, float b) {
    return max(a, -b);
}

// Smooth 并集 — 两个物体平滑地"融合"在一起，像液态金属
// k 控制融合的范围：k 越大，融合区域越大
// 这个公式叫 "polynomial smooth min"，是 Inigo Quilez 发明的经典技巧
float opSmoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// ============================================================
// 3. 场景：用布尔运算构建有趣的形状
//    用 iTime 驱动动画，让效果更直观
// ============================================================
vec2 scene(vec3 p) {
    // --- 第一组：Smooth Union 演示 ---
    // 两个球体平滑融合，像水滴汇聚
    float t = iTime;
    float dBall1 = sdSphere(p, vec3(-0.6 + 0.3 * sin(t), 0.5, 0.0), 0.4);
    float dBall2 = sdSphere(p, vec3( 0.6 - 0.3 * sin(t), 0.5, 0.0), 0.4);
    float dSmooth = opSmoothUnion(dBall1, dBall2, 0.3);

    // --- 第二组：差集演示 ---
    // 从一个圆角盒子里"挖出"一个球形的洞
    float dBox    = sdRoundBox(p, vec3(3.0, 0.5, 0.0), vec3(0.5, 0.5, 0.5), 0.05);
    float dCutSphere = sdSphere(p, vec3(3.0, 0.5, 0.0), 0.55);
    float dSubtract = opSubtract(dBox, dCutSphere);

    // --- 第三组：交集演示 ---
    // 球体和盒子的交集 = 圆角立方体的另一种做法
    float dIntBox    = sdRoundBox(p, vec3(-3.0, 0.5, 0.0), vec3(0.45, 0.45, 0.45), 0.0);
    float dIntSphere = sdSphere(p, vec3(-3.0, 0.5, 0.0), 0.55);
    float dIntersect = opIntersect(dIntBox, dIntSphere);

    // 地面
    float dPlane = sdPlane(p, 0.0);

    // 找出距离最小的物体
    vec2 result = vec2(dSmooth, 1.0);                               // ID 1: smooth union（红色）
    if (dSubtract < result.x) result = vec2(dSubtract, 2.0);       // ID 2: subtraction（蓝色）
    if (dIntersect < result.x) result = vec2(dIntersect, 3.0);     // ID 3: intersection（绿色）
    if (dPlane < result.x) result = vec2(dPlane, 4.0);             // ID 4: 地面

    return result;
}

// ============================================================
// 4. Ray Marching（和 Step 1 相同）
// ============================================================
vec2 rayMarch(vec3 ro, vec3 rd) {
    float t = 0.0;
    for (int i = 0; i < 128; i++) {
        vec3 p = ro + rd * t;
        vec2 d = scene(p);
        if (d.x < 0.001) return vec2(t, d.y);
        t += d.x;
        if (t > 100.0) break;
    }
    return vec2(-1.0, 0.0);
}

// ============================================================
// 5. 法线计算（和 Step 1 相同）
// ============================================================
vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        scene(p + e.xyy).x - scene(p - e.xyy).x,
        scene(p + e.yxy).x - scene(p - e.yxy).x,
        scene(p + e.yyx).x - scene(p - e.yyx).x
    ));
}

// ============================================================
// 6. 阴影：Soft Shadow
//    从击中点向光源发射一条射线，如果中途接近其他物体，就产生阴影
//    "接近程度"决定阴影的软硬——这就是 soft shadow
// ============================================================
float softShadow(vec3 ro, vec3 rd, float tmin, float tmax, float k) {
    float result = 1.0;
    float t = tmin;
    for (int i = 0; i < 64; i++) {
        float d = scene(ro + rd * t).x;
        if (d < 0.001) return 0.0;  // 完全在阴影中
        // d/t 越小，说明射线越"擦过"物体表面，阴影越浓
        result = min(result, k * d / t);
        t += d;
        if (t > tmax) break;
    }
    return result;
}

// ============================================================
// 7. 光照（增强版：加入 soft shadow）
// ============================================================
vec3 lighting(vec3 pos, vec3 normal, vec3 rd, vec3 baseColor) {
    vec3 lightPos = vec3(2.0, 4.0, -2.0);
    vec3 lightDir = normalize(lightPos - pos);

    // Soft shadow
    float shadow = softShadow(pos + normal * 0.01, lightDir, 0.02, 10.0, 16.0);

    // 环境光
    vec3 ambient = 0.15 * baseColor;

    // 漫反射 + 阴影
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * baseColor * shadow;

    // 镜面反射
    vec3 halfDir = normalize(lightDir - rd);
    float spec = pow(max(dot(normal, halfDir), 0.0), 32.0);
    vec3 specular = spec * vec3(0.4) * shadow;

    return ambient + diffuse + specular;
}

// ============================================================
// 8. 摄像机：绕场景旋转，可以看到三组物体
// ============================================================
mat3 setCamera(vec3 ro, vec3 ta) {
    vec3 cw = normalize(ta - ro);
    vec3 cu = normalize(cross(cw, vec3(0.0, 1.0, 0.0)));
    vec3 cv = cross(cu, cw);
    return mat3(cu, cv, cw);
}

// ============================================================
// 9. 主函数
// ============================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // 摄像机绕原点旋转，可以看到三组演示
    float angle = iTime * 0.3;
    vec3 ro = vec3(5.0 * sin(angle), 2.5, 5.0 * cos(angle));
    vec3 ta = vec3(0.0, 0.3, 0.0);  // 看向原点
    mat3 cam = setCamera(ro, ta);
    vec3 rd = cam * normalize(vec3(uv, 1.5));

    // Ray March!
    vec2 hit = rayMarch(ro, rd);

    vec3 color;
    if (hit.x > 0.0) {
        vec3 pos = ro + rd * hit.x;
        vec3 nor = calcNormal(pos);

        // 根据物体 ID 着色
        vec3 baseColor;
        if (hit.y == 1.0) baseColor = vec3(0.9, 0.2, 0.1);       // Smooth Union: 红色
        else if (hit.y == 2.0) baseColor = vec3(0.1, 0.4, 0.9);   // Subtraction: 蓝色
        else if (hit.y == 3.0) baseColor = vec3(0.2, 0.8, 0.3);   // Intersection: 绿色
        else {
            float checker = mod(floor(pos.x) + floor(pos.z), 2.0);
            baseColor = mix(vec3(0.9), vec3(0.4), checker);
        }

        color = lighting(pos, nor, rd, baseColor);

        // 简单的距离雾（远处的物体颜色渐变为天空色）
        float fog = 1.0 - exp(-0.02 * hit.x * hit.x);
        color = mix(color, vec3(0.5, 0.7, 1.0), fog);
    } else {
        color = mix(vec3(0.5, 0.7, 1.0), vec3(0.1, 0.2, 0.5), uv.y + 0.5);
    }

    // Gamma 校正（让画面亮度更符合人眼感知）
    color = pow(color, vec3(1.0 / 2.2));

    fragColor = vec4(color, 1.0);
}
