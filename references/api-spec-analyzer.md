# api-spec-analyzer — API 文档解析

## 用途

将后端 API 文档解析为前端可用的结构化接口清单，并标注项目中是否已有对应 API 函数。

## 输入

- API 文档目录路径（包含一个或多个 .md / .json / .yaml 文件）
- 或单个 API 文档文件路径

## 输出

1. 接口清单表格（合并所有文件的接口）
2. 复用/新建标注
3. 新建接口的函数签名建议

## 执行步骤

### Step 0: 扫描 api 目录

读取目标路径：
- 如果是目录 → 扫描目录下所有 `.md`、`.json`、`.yaml`、`.yml` 文件（排除 README.md）
- 如果是单个文件 → 直接处理该文件

对多个文件，逐个解析后合并为统一接口清单。

### Step 1: 检测文档格式

- `.md` → Markdown 格式，解析表格和代码块
- `.json` → OpenAPI/Swagger 格式
- `.yaml` / `.yml` → OpenAPI YAML 格式

### Step 2: 提取接口信息

对每个接口提取：
- HTTP 方法（GET / POST / PUT / DELETE）
- 请求路径（含 API 前缀）
- 请求参数（query / body / path，含类型、是否必填、默认值）
- 返回值结构（字段名、类型、嵌套关系）
- 错误码和错误信息
- 分页参数（如有）

### Step 3: 匹配项目现有 API 层

1. 搜索 `{{apiDir}}` 目录下所有文件（从 `.harness-env.json` 读取路径）
2. 对每个接口，使用三级匹配策略逐级搜索：

**第一级：精确匹配**
- 搜索 URL 路径中的关键词（资源名）
- 例如：`/api/team/points` → 搜索 `team/points`、`/team/points`
- 命中 → 置信度 100%

**第二级：语义匹配**（精确匹配未命中时）
- 提取 API 语义，映射为函数命名约定：
  - `GET /xxx/list` → 搜索 `getXxxList`、`fetchXxxList`、`queryXxxList`
  - `GET /xxx/:id` → 搜索 `getXxx`、`getXxxDetail`、`getXxxById`
  - `POST /xxx` → 搜索 `createXxx`、`addXxx`、`postXxx`
  - `PUT /xxx/:id` → 搜索 `updateXxx`、`editXxx`、`putXxx`
  - `DELETE /xxx/:id` → 搜索 `deleteXxx`、`removeXxx`
- 命中 → 置信度 80%~95%（根据命名匹配程度）

**第三级：上下文匹配**（前两级均未命中时）
- 提取接口用途中的中文关键词（如「获取积分」「订阅套餐」）
- 搜索代码中的中文注释、变量命名
- 命中 → 置信度 50%~75%（根据上下文关联度）

3. 根据匹配结果标注：
   - 已有 → 标注 `✅ 可复用` + 文件路径和函数名
   - 没有 → 标注 `🆕 需新建`
   - 置信度 < 95% → 输出预警 `⚠️ 匹配置信度较低，建议人工确认`

### Step 4: 生成函数签名建议

对需新建的接口，参照项目现有 API 函数风格生成签名建议：

```javascript
// 参照项目现有风格生成
export function getTeamPoints(params) {
  return request({
    url: '/api/team/points',
    method: 'get',
    params,
  })
}
```

### Step 5: 输出

```markdown
## 接口清单

| # | 方法 | 路径 | 用途 | 状态 | 位置 | 匹配置信度 |
|---|------|------|------|------|------|------------|
| 1 | GET | /api/team/points | 获取积分 | ✅ 可复用 | src/api/credit.js:getTeamPoints | 100% |
| 2 | GET | /api/team/members | 获取成员 | ✅ 可复用 ⚠️ | src/api/team.js:fetchMembers | 85%（语义匹配，建议人工确认） |
| 3 | POST | /api/team/plan | 订阅套餐 | 🆕 需新建 | - | - |

> ⚠️ 置信度 < 95% 的接口已标注预警，建议用户人工确认匹配结果。

## 新建接口函数签名

### subscribePlan（订阅套餐）
...
```
