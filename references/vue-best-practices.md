# Vue 3 最佳实践规范

---

## 核心原则

1. **复用优先** — 根据项目已有组件或函数实现，优先复用。没有对应能力也不过度封装或抽象。三行相似代码 > 一个不成熟的抽象。
2. **设计还原** — 有 design.md 遵循 design.md；无 design.md 按 Figma 设计稿或截图一比一还原，不自由发挥。
3. **最小改动** — 只改需要改的，不做额外"优化"或"顺手重构"。

---

## 1. Composition API 标准写法

### 全部使用 `<script setup>`

```vue
<script setup>
  import { ref, computed } from 'vue'

  const props = defineProps({
    title: { type: String, required: true },
    count: { type: Number, default: 0 },
  })

  const emit = defineEmits(['update', 'close'])

  const localCount = ref(props.count)
  const doubled = computed(() => localCount.value * 2)
</script>
```

**禁止：**
- 不使用 Options API（data/methods/computed/watch 选项）
- 不使用 `setup()` 函数形式，统一 `<script setup>`
- 不在 `<script setup>` 中 export default

### Props 声明

```vue
<script setup>
  // 简单 Props
  const props = defineProps({
    name: String,
    age: { type: Number, default: 0 },
    list: { type: Array, default: () => [] },
  })

  // Vue 3.5+ 可解构（保持响应性）
  const { name, age = 0 } = defineProps({
    name: String,
    age: Number,
  })
</script>
```

### defineModel（Vue 3.4+）

```vue
<script setup>
  // 替代 prop + emit 的 v-model 模式
  const modelValue = defineModel()
  const title = defineModel('title')
</script>
```

---

## 2. 响应式规范

### ref 和 reactive 的使用场景

```javascript
// ref：基本类型、需要重新赋值的值
const count = ref(0)
const name = ref('')
const visible = ref(false)
const selectedItem = ref(null)

// reactive：复杂对象（表单数据、配置对象等整体使用的场景）
const formData = reactive({
  name: '',
  email: '',
  phone: '',
})

// 大数据集用 shallowRef
const tableData = shallowRef([])
tableData.value = newArray // 替换整个数组
```

**关键规则：**
- 不要解构 `reactive` 对象（会丢失响应性），需要解构时用 `toRefs()`
- 派生数据用 `computed()`，不额外存 state
- 监听器 `watch()` / `watchEffect()` 必须处理清理逻辑

```javascript
// ✅ 正确：toRefs 保持响应性
const state = reactive({ name: '', age: 0 })
const { name, age } = toRefs(state)

// ❌ 错误：直接解构丢失响应性
const { name, age } = reactive({ name: '', age: 0 })
```

---

## 3. 组件设计

### 文件结构

```vue
<template>
  <!-- 模板 -->
</template>

<script setup>
  // 逻辑
</script>

<style lang="scss" scoped>
  // 样式
</style>
```

### 通信规则

- Props 向下，Events（emit）向上
- 不跨组件层级直接通信（不用 provide/inject 做业务数据传递，仅用于主题/配置等场景）
- 可复用逻辑提取为 `composables/useXxx.js`

### 列表渲染

```vue
<!-- ✅ 使用稳定 ID -->
<div
  v-for="item in list"
  :key="item.id"
>
  {{ item.name }}
</div>

<!-- ❌ 不用 index 作为 key（除非列表完全静态） -->
```

---

## 4. Pinia 状态管理

### Setup Store 风格（推荐）

```javascript
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  const user = ref(null)
  const loading = ref(false)

  const isLoggedIn = computed(() => !!user.value)

  const fetchUser = async () => {
    loading.value = true
    try {
      user.value = await api.getUser()
    } finally {
      loading.value = false
    }
  }

  return { user, loading, isLoggedIn, fetchUser }
})
```

### 使用规则

```javascript
import { storeToRefs } from 'pinia'

// ✅ 用 storeToRefs 解构保持响应性
const userStore = useUserStore()
const { user, loading } = storeToRefs(userStore)
const { fetchUser } = userStore // action 直接解构

// ❌ 不要直接解构 state
const { user } = useUserStore() // 丢失响应性
```

### 职责划分

- **UI 状态** → composable（弹窗开关、表单校验状态等）
- **业务状态** → Pinia store（用户信息、权限、全局配置）
- 一个文件一个 store

---

## 5. 性能优化

仅在有性能问题时使用，不要预优化：

```vue
<!-- v-memo：跳过不需要更新的列表项 -->
<div
  v-for="item in list"
  :key="item.id"
  v-memo="[item.id, item.status]"
>
  {{ item.name }}
</div>

<!-- v-once：完全静态内容 -->
<div v-once>
  <h1>{{ appTitle }}</h1>
</div>
```

```javascript
// shallowRef：大数组/大对象
const bigList = shallowRef([])

// 路由级别懒加载
const routes = [
  {
    path: '/users',
    component: () => import('@/views/users/index.vue'),
  },
]

// 异步组件
import { defineAsyncComponent } from 'vue'
const HeavyChart = defineAsyncComponent(() => import('./HeavyChart.vue'))
```

---

## 6. Element Plus 使用规范

- 使用 auto-import（unplugin-vue-components），不手动全局注册
- 表单验证用 `el-form` 的 rules，不自己写验证逻辑
- 弹窗用 `el-dialog` + `v-model`
- 表格用 `el-table` + `el-table-column`
- 日期选择器注意 `value-format` 与后端格式统一

---

## 7. CSS 规范

### 统一使用 SCSS + scoped

```vue
<style lang="scss" scoped>
  .container {
    padding: $spacing-md;
    background: $bg-color;

    .title {
      font-size: $font-size-lg;
      font-weight: 600;
      color: $text-color;
    }
  }
</style>
```

**规则：**
- 所有组件 `<style lang="scss" scoped>`
- 使用项目 `{{stylesDir}}/_variables.scss` 中定义的变量
- 不用内联 style（动态计算值除外，如 `:style="{ width: computedWidth + 'px' }"`)
- 不引入 CSS Modules
- 不引入 Tailwind（除非项目已有）
- 深度选择器用 `:deep()` 而非 `::v-deep`（已废弃）

---

## 8. i18n 规范

```vue
<template>
  <!-- ✅ 走 i18n -->
  <span>{{ $t('user.name') }}</span>
  <el-button>{{ $t('common.submit') }}</el-button>

  <!-- ❌ 硬编码文案 -->
  <span>用户名</span>
</template>
```

**规则：**
- 所有用户可见文案必须通过 `$t()` 或 `t()`
- 新增 key 在所有语言文件中添加对应条目
- 中文开发者填写，英文 AI 翻译，日文/西班牙文 AI 翻译 + 标 TODO 人工复核
- key 命名：`module.feature.label`（如 `credit.recharge.title`）

---

## 9. 安全

- **禁止** `v-html` 渲染未经净化的内容（用户输入、API 返回的 HTML）
- **禁止** 在模板中将用户输入拼接到 `href`、`src` 等属性
- **禁止** 硬编码 token、密钥
- API 调用统一走项目的 request 工具，不直接用 axios/fetch

---

## 10. Vue Router 规范

- 路由使用懒加载 `() => import('@/views/xxx/index.vue')`
- 路由 meta 设置 `title` 和权限标识
- 参数验证不信任 route params，做必要校验
- 按功能模块拆分路由文件（如果项目已有此模式）

---

## 11. 组件通信完整指南

### 通信方式决策树

```
父子组件通信     → Props 向下 + Emit 向上（或 defineModel）
兄弟组件通信     → 父组件中转（提升状态到父组件）
深层嵌套（>3 层） → provide/inject（配置/主题）或 Pinia（业务状态）
跨模块通信       → Pinia Store
```

### 父子通信——defineModel（Vue 3.4+）

```vue
<!-- 父组件 -->
<template>
  <CustomInput v-model="username" />
  <CustomInput v-model:title="pageTitle" />
</template>

<!-- 子组件 CustomInput.vue -->
<script setup>
  // 替代 prop + emit 的 v-model 模式
  const modelValue = defineModel()
  const title = defineModel('title')
</script>

<template>
  <input v-model="modelValue" />
</template>
```

**何时用 defineModel vs props + emit：**
- 双向绑定场景（表单控件、开关）→ `defineModel`
- 单向数据流 + 事件回调 → `props + emit`

### 兄弟通信——父组件中转

```vue
<!-- 父组件 -->
<script setup>
  import { ref } from 'vue'
  const selectedItem = ref(null)
</script>

<template>
  <!-- 兄弟 A：触发选择 -->
  <ItemList @select="selectedItem = $event" />
  <!-- 兄弟 B：显示详情 -->
  <ItemDetail :item="selectedItem" />
</template>
```

**规则：** 不使用 EventBus / mitt 做兄弟通信。状态提升到父组件或用 Pinia。

### 深层嵌套——provide/inject 安全边界

```typescript
// 统一定义 injection key（带类型）
import type { InjectionKey } from 'vue'

export const ThemeKey: InjectionKey<Ref<'light' | 'dark'>> = Symbol('theme')
export const ConfigKey: InjectionKey<AppConfig> = Symbol('config')
```

```vue
<!-- 祖先组件 -->
<script setup>
  import { provide, ref } from 'vue'
  import { ThemeKey } from '@/constants/injection-keys'

  const theme = ref<'light' | 'dark'>('light')
  provide(ThemeKey, theme)
</script>
```

```vue
<!-- 后代组件 -->
<script setup>
  import { inject } from 'vue'
  import { ThemeKey } from '@/constants/injection-keys'

  // 必须提供默认值或做非空检查
  const theme = inject(ThemeKey, ref('light'))
</script>
```

**provide/inject 安全规则：**
- ✅ 适用：主题、全局配置、UI 框架上下文
- ❌ 禁止：业务数据传递（用 Pinia 代替）
- 始终用 `Symbol` 作为 injection key，避免字符串冲突
- inject 时始终提供默认值或做非空校验

### 跨模块——Pinia

参见第 4 节「 Pinia 状态管理」。跨模块通信统一通过 Pinia store，不使用全局事件总线。

---

## 12. 大型项目最佳实践

### Monorepo 共享组件库组织

```
packages/
├── ui/                      ← 共享组件库
│   ├── src/
│   │   ├── components/      ← 通用组件
│   │   ├── composables/     ← 通用 hooks
│   │   └── index.ts         ← 统一导出
│   └── package.json
├── utils/                   ← 共享工具函数
│   ├── src/
│   └── package.json
apps/
├── admin/                   ← 业务应用 A
└── portal/                  ← 业务应用 B
```

**规则：**
- 共享组件库不包含业务逻辑，只做通用 UI 封装
- 共享包通过 workspace 协议引用（如 `"@scope/ui": "workspace:*"`）
- 每个共享包有独立的 `package.json` 和构建配置
- 组件库导出时提供 TypeScript 类型声明

### 循环依赖检测

```bash
# 使用 madge 检测循环依赖
npx madge --circular --extensions ts,vue src/
```

**常见循环依赖场景及解决方案：**

```
A.vue → B.vue → A.vue     → 提取共享逻辑到 composable
store → api → store         → api 层不应依赖 store，改为参数传入
utils → constants → utils   → 拆分为更细粒度的模块
```

**规则：**
- CI 中集成循环依赖检测，发现新增循环依赖时构建失败
- 依赖方向：页面 → 组件 → composables → utils，不反向

### SSR Hydration 处理（Nuxt）

```vue
<!-- ❌ 会导致 hydration mismatch -->
<template>
  <span>{{ new Date().toLocaleString() }}</span>
</template>

<!-- ✅ 使用 <ClientOnly> 包裹客户端专属内容 -->
<template>
  <ClientOnly>
    <span>{{ now }}</span>
    <template #fallback>
      <span>加载中...</span>
    </template>
  </ClientOnly>
</template>

<script setup>
  import { ref, onMounted } from 'vue'
  const now = ref('')
  onMounted(() => {
    now.value = new Date().toLocaleString()
  })
</script>
```

**常见 hydration mismatch 原因：**
- 时间戳、随机数（服务端和客户端不同）
- `window` / `document` 依赖（服务端不存在）
- 条件渲染依赖客户端状态（如 `localStorage`）
- 浏览器插件修改 DOM

**规则：**
- 客户端专属内容用 `<ClientOnly>` 包裹
- 提供 `#fallback` 插槽作为服务端占位
- `onMounted` 中访问浏览器 API

### 路由懒加载

```javascript
// 基础懒加载
const routes = [
  {
    path: '/dashboard',
    component: () => import('@/views/dashboard/index.vue'),
  },
]

// 分组懒加载（同一模块的页面打包到同一 chunk）
const routes = [
  {
    path: '/settings',
    component: () => import(/* webpackChunkName: "settings" */ '@/views/settings/index.vue'),
    children: [
      {
        path: 'profile',
        component: () => import(/* webpackChunkName: "settings" */ '@/views/settings/profile.vue'),
      },
      {
        path: 'security',
        component: () => import(/* webpackChunkName: "settings" */ '@/views/settings/security.vue'),
      },
    ],
  },
]
```

**规则：**
- 所有路由页面使用懒加载，不直接 import
- 相关页面用 chunk name 分组，减少请求数
- 大型组件用 `defineAsyncComponent` 加载提示
