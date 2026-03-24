# Q: 为什么计算 half 向量用的是 `normalize(lightDir - rayDir)` 而不是加法？

## A: 关键在于 rayDir 的方向

### 各向量方向

```
        💡 光源 (lightPos)
         ╲
          ╲ lightDir（指向光源）
           ╲
            ↘
    ─────────●───────────── 表面
             p ↑ normal
            ↗
           ╱
          ╱  -rayDir（指向摄像机）
         ╱
        📷 摄像机
```

| 向量 | 方向 | 定义 |
|------|------|------|
| `lightDir` | 表面 → 光源 | `normalize(lightPos - pos)` |
| `rayDir` | 摄像机 → 表面 | 射线方向 |
| `-rayDir` | 表面 → 摄像机 | 翻转后的观察方向（viewDir） |

`lightDir` 离开表面，`rayDir` 朝向表面——方向相反。

### Half 向量的定义

半程向量 = lightDir 和观察方向（viewDir = -rayDir）的角平分线：

```
halfDir = normalize(lightDir + viewDir)
        = normalize(lightDir + (-rayDir))
        = normalize(lightDir - rayDir)
```

```
        💡
         ╲ lightDir
          ╲
           ╲   ↑ halfDir（角平分线）
            ╲  │  ╱
             ╲ │ ╱ -rayDir (viewDir)
              ╲│╱
    ───────────●──────────── 表面
               p
```

**减法不是在算"差"，而是向量加法 `lightDir + (-rayDir)`。减号是因为 rayDir 方向反了。**

### 如果写成加法会怎样

```
// ❌ 错误
vec3 wrongHalf = normalize(lightDir + rayDir);
```

用具体数值——光从正上方来，摄像机在正前方（-z 方向）：

```
lightDir = (0, 1, 0)     指向光源（上方）
rayDir   = (0, 0, 1)     从摄像机射向表面（+z 方向）
-rayDir  = (0, 0, -1)    从表面看向摄像机

正确: normalize((0,1,0) + (0,0,-1)) = normalize(0, 1,-1) → 上方偏前 45° ✅
错误: normalize((0,1,0) + (0,0, 1)) = normalize(0, 1, 1) → 指向表面背后 ❌
```

### 一句话总结

减法是因为 `rayDir` 和 `viewDir` 方向相反。`lightDir - rayDir` = `lightDir + viewDir`，这才是正确的半程向量。
