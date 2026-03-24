# Q: 如果不想渲染球，只想渲染地面，要怎么修改？

## A:

把 `scene` 函数里的球体去掉，只保留平面：

```glsl
vec2 scene(vec3 p) {
    float dPlane = sdPlane(p, 0.0);
    return vec2(dPlane, 2.0);  // 只有平面，ID = 2
}
```

着色部分不用改——命中 ID 不等于 1.0 就会走 `else` 分支（棋盘格）。

这也体现了 SDF 场景组织的灵活性：**添加/删除物体只需要在 `scene` 函数里增删一行 SDF + 比较，其余代码（Ray Marching、法线、光照）完全不用动。**
