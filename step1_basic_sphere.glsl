// Step 1: 最简 Ray Marching — 一个球体 + 平面 + Phong 光照
// 把这段代码粘贴到 shadertoy.com 的编辑器里，点 Play 即可看到效果
//
// 核心思想：从摄像机发出一条射线，沿射线方向一步步"走"，
// 每一步问："我离场景中最近的物体有多远？"
// 如果足够近（< 0.001），就认为击中了物体。

// ============================================================
// 1. 场景定义：用 SDF（Signed Distance Function）描述几何体
//    SDF 的含义：给定一个空间中的点 p，返回 p 到物体表面的最短距离
//    距离 > 0 表示在物体外面，< 0 表示在物体里面，= 0 表示在表面上
// ============================================================

// 球体的 SDF：点到球心的距离 - 半径
// 这是最直觉的 SDF：你离球心多远，减去半径，就是你离球面多远
float sdSphere(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
}

// 平面的 SDF：点在 Y 方向上离平面的距离
// 平面在 y = height 的位置，所以距离就是 p.y - height
float sdPlane(vec3 p, float height) {
    return p.y - height;
}

// 整个场景的 SDF：取所有物体距离的最小值
// 为什么取最小值？因为我们关心的是"离最近的物体有多远"
// 返回 vec2: x = 距离, y = 物体 ID（用于后续给不同物体不同颜色）
vec2 scene(vec3 p) {
    float dSphere = sdSphere(p, vec3(0.0, 0.5, 0.0), 0.5);  // 球心在 (0, 0.5, 0)，半径 0.5
    float dPlane  = sdPlane(p, 0.0);                           // 平面在 y = 0

    // 返回距离更小的那个物体（离得更近的那个）
    if (dSphere < dPlane) {
        return vec2(dSphere, 1.0);  // ID 1 = 球体
    } else {
        return vec2(dPlane, 2.0);   // ID 2 = 平面
    }
}

// ============================================================
// 2. Ray Marching：沿射线方向一步步前进，直到击中物体
//    这就是"光线步进"——每一步走的距离 = 当前位置到最近物体的距离
//    为什么可以这样走？因为 SDF 保证了在这个距离内不会穿过任何物体
// ============================================================
vec2 rayMarch(vec3 rayOrigin, vec3 rayDir) {
    float totalDist = 0.0;      // 射线已经走了多远

    for (int i = 0; i < 100; i++) {          // 最多走 100 步
        vec3 currentPos = rayOrigin + rayDir * totalDist;  // 当前位置
        vec2 result = scene(currentPos);     // 查询离最近物体的距离
        float dist = result.x;

        if (dist < 0.001) {                  // 足够近，认为击中了！
            return vec2(totalDist, result.y); // 返回总距离和物体 ID
        }

        totalDist += dist;                   // 没击中，继续前进

        if (totalDist > 100.0) break;        // 走太远了，放弃（没击中任何东西）
    }

    return vec2(-1.0, 0.0);  // -1 表示没击中任何物体
}

// ============================================================
// 3. 法线计算：用"微小偏移法"计算表面法线
//    法线 = SDF 的梯度方向（SDF 变化最快的方向就是远离表面的方向）
//    用 6 次 SDF 查询近似梯度（中心差分法）
// ============================================================
vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);  // 微小偏移量
    return normalize(vec3(
        scene(p + e.xyy).x - scene(p - e.xyy).x,  // x 方向的变化率
        scene(p + e.yxy).x - scene(p - e.yxy).x,  // y 方向的变化率
        scene(p + e.yyx).x - scene(p - e.yyx).x   // z 方向的变化率
    ));
}

// ============================================================
// 4. Phong 光照模型：环境光 + 漫反射 + 镜面反射
//    这是最经典的光照模型，游戏开发者应该很熟悉
// ============================================================
vec3 phongLighting(vec3 pos, vec3 normal, vec3 rayDir, vec3 baseColor) {
    vec3 lightPos = vec3(2.0, 3.0, -1.0);       // 光源位置
    vec3 lightDir = normalize(lightPos - pos);    // 指向光源的方向

    // 环境光：即使没有直接光照也不会全黑
    vec3 ambient = 0.15 * baseColor;

    // 漫反射（Lambert）：表面越正对光源越亮
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * baseColor;

    // 镜面反射（Blinn-Phong）：视角接近反射方向时出现高光
    vec3 halfDir = normalize(lightDir - rayDir);  // 半程向量
    float spec = pow(max(dot(normal, halfDir), 0.0), 32.0);
    vec3 specular = spec * vec3(0.5);

    return ambient + diffuse + specular;
}

// ============================================================
// 5. 主函数：ShaderToy 的入口，每个像素调用一次
// ============================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 把像素坐标转换为 [-1, 1] 范围，并修正宽高比
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // 摄像机设置
    vec3 rayOrigin = vec3(0.0, 1.0, -3.0);           // 摄像机位置
    vec3 rayDir = normalize(vec3(uv, 1.0));            // 射线方向（简单透视投影）

    // 发射射线！
    vec2 hit = rayMarch(rayOrigin, rayDir);

    // 根据是否击中物体来确定颜色
    vec3 color;
    if (hit.x > 0.0) {  // 击中了物体
        vec3 hitPos = rayOrigin + rayDir * hit.x;  // 击中点的位置
        vec3 normal = calcNormal(hitPos);           // 击中点的法线

        // 根据物体 ID 给不同颜色
        vec3 baseColor;
        if (hit.y == 1.0) {
            baseColor = vec3(0.9, 0.2, 0.1);  // 球体：红色
        } else {
            // 平面：棋盘格图案（经典的图形学测试图案）
            float checker = mod(floor(hitPos.x) + floor(hitPos.z), 2.0);
            baseColor = mix(vec3(0.8), vec3(0.3), checker);
        }

        color = phongLighting(hitPos, normal, rayDir, baseColor);
    } else {
        // 没击中任何物体：画天空（简单的渐变）
        color = mix(vec3(0.5, 0.7, 1.0), vec3(0.1, 0.2, 0.5), uv.y + 0.5);
    }

    // 输出最终颜色
    fragColor = vec4(color, 1.0);
}
