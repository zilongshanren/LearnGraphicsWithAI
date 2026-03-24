// Step 3: 综合场景 — "诞生"（The Emergence）
// 一个完整的 Ray Marching 场景，综合运用前两步学到的所有技巧
// 场景概念：一个球体从液态地面中"浮现"出来，带有倒影和环境光遮蔽
//
// 新增技巧：
//   - Ambient Occlusion（环境光遮蔽）
//   - 更复杂的 SDF 组合
//   - 材质系统（不同物体不同光泽度）
//   - 重复/对称运算
//   - 更精致的光照

// ============================================================
// SDF 图元
// ============================================================

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdPlane(vec3 p) {
    return p.y;
}

// 胶囊体：两个端点之间的圆柱 + 圆头
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 ab = b - a;
    vec3 ap = p - a;
    float t = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
    return length(p - (a + t * ab)) - r;
}

// 圆环
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// ============================================================
// SDF 运算
// ============================================================

float opSmoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float opSmoothSubtract(float a, float b, float k) {
    float h = clamp(0.5 - 0.5 * (a + b) / k, 0.0, 1.0);
    return mix(a, -b, h) + k * h * (1.0 - h);
}

// 空间重复：让一个物体在空间中无限重复
// c = 重复间距，每隔 c 个单位重复一次
vec3 opRepeat(vec3 p, vec3 c) {
    return mod(p + 0.5 * c, c) - 0.5 * c;
}

// ============================================================
// 场景
// ============================================================

vec2 scene(vec3 p) {
    float t = iTime;

    // --- 主体：从地面"浮现"的球体 ---
    // 球体上下浮动
    float bobHeight = 0.8 + 0.3 * sin(t * 0.8);
    float dMainSphere = sdSphere(p - vec3(0.0, bobHeight, 0.0), 0.6);

    // 液态地面：用 smooth union 让球体和地面融合
    float dGround = sdPlane(p);
    float dMerge = opSmoothUnion(dMainSphere, dGround, 0.5);

    // --- 装饰：围绕主体的小球 ---
    // 6 个小球围绕中心旋转
    float dOrbiters = 1e10;
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * 3.14159 / 3.0 + t * 0.5;
        float radius = 1.5 + 0.3 * sin(t + float(i));
        float h = 0.4 + 0.2 * sin(t * 1.3 + float(i) * 2.0);
        vec3 orbPos = vec3(radius * cos(angle), h, radius * sin(angle));
        float dOrb = sdSphere(p - orbPos, 0.12);
        dOrbiters = min(dOrbiters, dOrb);
    }

    // 小球也和地面融合
    dMerge = opSmoothUnion(dMerge, dOrbiters, 0.2);

    // --- 环形结构 ---
    vec3 torusP = p - vec3(0.0, bobHeight, 0.0);
    // 让圆环缓慢倾斜旋转
    float a = t * 0.3;
    mat2 rot = mat2(cos(a), sin(a), -sin(a), cos(a));
    torusP.xy = rot * torusP.xy;
    float dTorus = sdTorus(torusP, vec2(1.0, 0.03));

    // 组合场景
    vec2 result = vec2(dMerge, 1.0);   // ID 1: 融合体
    if (dTorus < result.x) result = vec2(dTorus, 2.0);  // ID 2: 圆环

    return result;
}

// ============================================================
// Ray Marching
// ============================================================
vec2 rayMarch(vec3 ro, vec3 rd) {
    float t = 0.0;
    for (int i = 0; i < 150; i++) {
        vec3 p = ro + rd * t;
        vec2 d = scene(p);
        if (d.x < 0.0005) return vec2(t, d.y);
        t += d.x * 0.8;  // 稍微保守一点，避免过冲
        if (t > 50.0) break;
    }
    return vec2(-1.0, 0.0);
}

// ============================================================
// 法线
// ============================================================
vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.0005, 0.0);
    return normalize(vec3(
        scene(p + e.xyy).x - scene(p - e.xyy).x,
        scene(p + e.yxy).x - scene(p - e.yxy).x,
        scene(p + e.yyx).x - scene(p - e.yyx).x
    ));
}

// ============================================================
// Ambient Occlusion（环境光遮蔽）
// 原理：从表面沿法线方向采样几个点，如果附近有其他物体遮挡，
// 那么这些采样点的 SDF 值会比"预期距离"小 → 说明被遮挡了
// 这给凹陷处添加了自然的暗角，大大提升真实感
// ============================================================
float calcAO(vec3 pos, vec3 nor) {
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;   // 采样距离递增
        float d = scene(pos + h * nor).x;            // 实际 SDF 距离
        occ += (h - d) * sca;                         // 差值 = 被遮挡程度
        sca *= 0.95;                                  // 远处的遮挡权重递减
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

// ============================================================
// Soft Shadow
// ============================================================
float softShadow(vec3 ro, vec3 rd, float tmin, float tmax, float k) {
    float res = 1.0;
    float t = tmin;
    for (int i = 0; i < 64; i++) {
        float d = scene(ro + rd * t).x;
        if (d < 0.001) return 0.0;
        res = min(res, k * d / t);
        t += clamp(d, 0.01, 0.2);
        if (t > tmax) break;
    }
    return clamp(res, 0.0, 1.0);
}

// ============================================================
// 光照系统
// ============================================================
vec3 render(vec3 ro, vec3 rd) {
    vec2 hit = rayMarch(ro, rd);

    // 天空
    vec3 skyColor = mix(
        vec3(0.4, 0.6, 0.9),
        vec3(0.7, 0.8, 1.0),
        rd.y * 0.5 + 0.5
    );
    // 太阳光晕
    vec3 sunDir = normalize(vec3(1.0, 0.5, -0.5));
    float sunGlow = pow(max(dot(rd, sunDir), 0.0), 32.0);
    skyColor += vec3(1.0, 0.8, 0.5) * sunGlow * 0.5;

    if (hit.x < 0.0) return skyColor;

    vec3 pos = ro + rd * hit.x;
    vec3 nor = calcNormal(pos);

    // 材质
    vec3 baseColor;
    float metallic = 0.0;
    float roughness = 0.5;

    if (hit.y == 1.0) {
        // 融合体：根据高度渐变颜色
        float heightBlend = smoothstep(0.0, 1.5, pos.y);
        baseColor = mix(
            vec3(0.15, 0.15, 0.2),   // 地面：深灰蓝
            vec3(0.95, 0.3, 0.15),    // 球体：温暖的橙红
            heightBlend
        );
        metallic = mix(0.0, 0.3, heightBlend);
        roughness = mix(0.8, 0.3, heightBlend);
    } else {
        // 圆环：金属质感
        baseColor = vec3(0.9, 0.8, 0.6);
        metallic = 0.9;
        roughness = 0.1;
    }

    // 光照
    vec3 lightDir = sunDir;
    vec3 lightColor = vec3(1.0, 0.95, 0.85);

    // Diffuse
    float NdotL = max(dot(nor, lightDir), 0.0);
    float shadow = softShadow(pos + nor * 0.005, lightDir, 0.01, 5.0, 16.0);
    vec3 diffuse = NdotL * lightColor * shadow;

    // Specular (GGX-like 简化版)
    vec3 halfVec = normalize(lightDir - rd);
    float NdotH = max(dot(nor, halfVec), 0.0);
    float specPow = mix(8.0, 256.0, 1.0 - roughness);
    float spec = pow(NdotH, specPow) * (1.0 - roughness);

    // 环境光 + AO
    float ao = calcAO(pos, nor);
    vec3 ambient = skyColor * 0.15 * ao;

    // 菲涅尔反射（边缘更亮，模拟真实材质行为）
    float fresnel = pow(1.0 - max(dot(nor, -rd), 0.0), 5.0);
    fresnel = mix(0.04, 1.0, fresnel);

    // 组合
    vec3 color = ambient
               + diffuse * baseColor * (1.0 - metallic)
               + spec * mix(vec3(0.04), baseColor, metallic) * shadow
               + fresnel * skyColor * 0.2 * ao;

    // 距离雾
    float fog = 1.0 - exp(-0.01 * hit.x * hit.x);
    color = mix(color, skyColor, fog);

    return color;
}

// ============================================================
// 摄像机
// ============================================================
mat3 setCamera(vec3 ro, vec3 ta, float roll) {
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(sin(roll), cos(roll), 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = cross(cu, cw);
    return mat3(cu, cv, cw);
}

// ============================================================
// 主函数
// ============================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // 摄像机缓慢绕场景旋转
    float t = iTime * 0.2;
    vec3 ro = vec3(4.0 * sin(t), 2.0 + 0.5 * sin(t * 0.7), 4.0 * cos(t));
    vec3 ta = vec3(0.0, 0.5, 0.0);

    mat3 cam = setCamera(ro, ta, 0.0);
    vec3 rd = cam * normalize(vec3(uv, 1.8));  // 1.8 = 焦距，数字越大视角越窄

    // 渲染
    vec3 color = render(ro, rd);

    // Tone mapping（HDR → LDR，防止过曝）
    color = color / (1.0 + color);

    // Gamma 校正
    color = pow(color, vec3(1.0 / 2.2));

    // 轻微暗角效果（画面边缘变暗，聚焦视觉中心）
    float vignette = 1.0 - 0.3 * dot(uv, uv);
    color *= vignette;

    fragColor = vec4(color, 1.0);
}
