# React 19+ 最佳实践规范

---

## 核心原则

1. **复用优先** — 根据项目已有组件或函数实现，优先复用。没有对应能力也不过度封装或抽象。三行相似代码 > 一个不成熟的抽象。
2. **设计还原** — 有 design.md 遵循 design.md；无 design.md 按 Figma 设计稿或截图一比一还原，不自由发挥。
3. **最小改动** — 只改需要改的，不做额外"优化"或"顺手重构"。

---

## 1. React 19 新特性

### use() Hook

```tsx
// 替代 promise 手动处理
function Comments({ commentsPromise }: { commentsPromise: Promise<Comment[]> }) {
  const comments = use(commentsPromise)
  return (
    <ul>
      {comments.map((c) => (
        <li key={c.id}>{c.text}</li>
      ))}
    </ul>
  )
}
```

### useActionState

```tsx
// 统一 pending + error 状态
const [error, submitAction, isPending] = useActionState(
  async (prevState, formData) => {
    const error = await updateName(formData.get('name') as string)
    return error || null
  },
  null,
)

return (
  <form action={submitAction}>
    <input name="name" />
    <button disabled={isPending}>提交</button>
    {error && <p className="error">{error}</p>}
  </form>
)
```

### useOptimistic

```tsx
// 乐观更新
const [optimisticName, setOptimisticName] = useOptimistic(currentName)

const submitAction = async (formData: FormData) => {
  const newName = formData.get('name') as string
  setOptimisticName(newName) // 立即更新 UI
  await updateName(newName) // 异步提交
}
```

### ref 直接传 props（不需要 forwardRef）

```tsx
// React 19: ref 作为普通 prop
function Input({ ref, ...props }: { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />
}

// 不再需要 forwardRef
```

---

## 2. 组件写法

### 普通函数组件（非 React.FC）

```tsx
// ✅ 推荐
interface ButtonProps {
  onClick: () => void
  children: React.ReactNode
  variant?: 'primary' | 'secondary'
}

export function Button({ onClick, children, variant = 'primary' }: ButtonProps) {
  return (
    <button className={`btn-${variant}`} onClick={onClick}>
      {children}
    </button>
  )
}

// ❌ 不推荐
const Button: React.FC<ButtonProps> = ({ onClick, children }) => { ... }
```

**规则：**
- Props 用 `interface` 定义
- 联合类型和工具类型用 `type`
- 命名导出优先（除非项目约定 default export）
- 泛型组件用普通函数

---

## 3. React Compiler（自动优化）

React Compiler 已稳定（1.0），自动处理 memoization：

```tsx
// ✅ 不需要手动 useMemo/useCallback（Compiler 自动处理）
function ProductList({ products, filter }: Props) {
  const filtered = products.filter((p) => p.category === filter)
  const handleClick = (id: string) => selectProduct(id)

  return (
    <ul>
      {filtered.map((p) => (
        <ProductItem key={p.id} product={p} onClick={handleClick} />
      ))}
    </ul>
  )
}

// ❌ 不需要这样（除非 Profiler 确认有性能问题）
const filtered = useMemo(() => products.filter(...), [products, filter])
const handleClick = useCallback((id: string) => selectProduct(id), [])
```

**规则：**
- 默认不写 `useMemo` / `useCallback`
- 仅在 React Profiler 确认有性能问题时手动添加
- 保持组件为纯函数，Compiler 才能优化

---

## 4. Hooks 规范

### 自定义 Hook

```tsx
export function useUserData(userId: string) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)

    fetchUser(userId)
      .then((data) => {
        if (!cancelled) setUser(data)
      })
      .catch((err) => {
        if (!cancelled) setError(err)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })

    return () => { cancelled = true }
  }, [userId])

  return { user, loading, error }
}
```

**规则：**
- 不在条件 / 循环中调用 Hook
- Hook 内处理清理逻辑（取消请求、清除定时器）
- 能用事件处理的不用 useEffect

---

## 5. 状态管理

### 选择策略

```
局部组件状态 → useState
跨组件共享 → Context（嵌套 <3 层）
复杂全局状态 → Zustand
```

### Zustand 写法

```tsx
import { create } from 'zustand'

interface UserStore {
  user: User | null
  loading: boolean
  fetchUser: () => Promise<void>
}

export const useUserStore = create<UserStore>((set) => ({
  user: null,
  loading: false,
  fetchUser: async () => {
    set({ loading: true })
    const user = await api.getUser()
    set({ user, loading: false })
  },
}))

const user = useUserStore((s) => s.user)
```

**规则：**
- 不存派生状态，用计算得出
- 不把所有状态都塞进全局 store

---

## 6. TypeScript 规范

```tsx
// ✅ 严格模式，不用 any
interface User {
  id: string
  name: string
  role: 'admin' | 'member' | 'viewer'
}

// ✅ 用 unknown 代替 any，然后收窄
function processData(data: unknown) {
  if (typeof data === 'string') {
    return data.toUpperCase()
  }
}

// ❌ 禁止
const data: any = fetchData()
// @ts-ignore
```

---

## 7. CSS 规范

### 项目有 Tailwind → 用 Tailwind

### 项目无 Tailwind → CSS Modules

```tsx
import styles from './Card.module.scss'

export function Card({ title, children }: CardProps) {
  return (
    <div className={styles.card}>
      <h2 className={styles.title}>{title}</h2>
      {children}
    </div>
  )
}
```

**规则：**
- 不用 runtime CSS-in-JS（emotion / styled-components）在 SSR 项目中
- 不引入 Tailwind 到不使用 Tailwind 的项目
- 使用项目已有的设计变量 / CSS 变量

---

## 8. Server Components（Next.js 项目）

```tsx
// 默认 Server Component（不需要标注）
export default async function UsersPage() {
  const users = await fetchUsers()
  return <UserList users={users} />
}

// 需要交互时才加 'use client'
'use client'
export function SearchInput() {
  const [query, setQuery] = useState('')
  return <input value={query} onChange={(e) => setQuery(e.target.value)} />
}
```

---

## 9. 测试规范

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

test('提交表单后显示成功提示', async () => {
  render(<LoginForm />)
  await userEvent.type(screen.getByLabelText('用户名'), 'admin')
  await userEvent.click(screen.getByRole('button', { name: '登录' }))
  expect(await screen.findByText('登录成功')).toBeInTheDocument()
})
```

**规则：**
- 用 `getByRole` / `getByLabelText`，不用 `getByTestId`
- 用 `userEvent` 替代 `fireEvent`
- 行为驱动，不测内部状态

---

## 10. 安全

- **禁止** `dangerouslySetInnerHTML` 使用未经净化的内容
- **禁止** 用户输入直接拼接到 href / src
- **禁止** 硬编码 token / 密钥
- API 调用走项目统一的 request 工具

---

## 11. React 19 兼容性标注

以下 API 为 React 19 新增，在 React 18 项目中不可用。使用前确认项目 React 版本。

### use() Hook

> ⚠️ **React 19+**，React 18 不可用

```tsx
// React 19——直接在组件中读取 Promise
function Comments({ commentsPromise }: { commentsPromise: Promise<Comment[]> }) {
  const comments = use(commentsPromise)
  return <ul>{comments.map((c) => <li key={c.id}>{c.text}</li>)}</ul>
}

// React 18 降级方案——用 useEffect + useState 手动处理
function Comments({ commentsPromise }: { commentsPromise: Promise<Comment[]> }) {
  const [comments, setComments] = useState<Comment[]>([])
  useEffect(() => {
    let cancelled = false
    commentsPromise.then((data) => {
      if (!cancelled) setComments(data)
    })
    return () => { cancelled = true }
  }, [commentsPromise])
  return <ul>{comments.map((c) => <li key={c.id}>{c.text}</li>)}</ul>
}
```

### useActionState

> ⚠️ **React 19+**，React 18 不可用

```tsx
// React 19
const [error, submitAction, isPending] = useActionState(
  async (prevState, formData) => {
    const error = await updateName(formData.get('name') as string)
    return error || null
  },
  null,
)

// React 18 降级方案——手动管理 pending + error 状态
const [error, setError] = useState<string | null>(null)
const [isPending, setIsPending] = useState(false)

const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
  e.preventDefault()
  setIsPending(true)
  const formData = new FormData(e.currentTarget)
  const err = await updateName(formData.get('name') as string)
  setError(err || null)
  setIsPending(false)
}
```

### useOptimistic

> ⚠️ **React 19+**，React 18 不可用

```tsx
// React 19
const [optimisticName, setOptimisticName] = useOptimistic(currentName)

// React 18 降级方案——手动乐观更新
const [displayName, setDisplayName] = useState(currentName)

const submitAction = async (formData: FormData) => {
  const newName = formData.get('name') as string
  setDisplayName(newName) // 乐观更新 UI
  try {
    await updateName(newName)
  } catch {
    setDisplayName(currentName) // 失败回滚
  }
}
```

### ref 作为普通 prop

> ⚠️ **React 19+**，React 18 需要 `forwardRef`

```tsx
// React 19——ref 作为普通 prop
function Input({ ref, ...props }: { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />
}

// React 18 降级方案——使用 forwardRef
const Input = forwardRef<HTMLInputElement, InputProps>((props, ref) => {
  return <input ref={ref} {...props} />
})
```

---

## 12. React Compiler 最佳实践

React Compiler（babel-plugin-react-compiler）已稳定发布 1.0，自动处理 memoization。

### 启用方式

```bash
npm install -D babel-plugin-react-compiler
```

```js
// babel.config.js 或 vite.config.ts
const ReactCompilerConfig = { /* 配置项 */ }

// Vite + React
plugins: [
  react({
    babel: {
      plugins: [['babel-plugin-react-compiler', ReactCompilerConfig]],
    },
  }),
]

// Next.js (next.config.js)
const nextConfig = {
  experimental: {
    reactCompiler: true,
  },
}
```

### 三大优化

1. **自动跳过重渲染** — 组件 props 未变时自动跳过，等价于 `React.memo`
2. **自动缓存计算值** — 自动处理 `useMemo` 场景
3. **自动缓存回调函数** — 自动处理 `useCallback` 场景

```tsx
// ✅ 启用 Compiler 后的写法（不需要手动 memo）
function ProductList({ products, filter }: Props) {
  const filtered = products.filter((p) => p.category === filter)
  const handleClick = (id: string) => selectProduct(id)
  return (
    <ul>
      {filtered.map((p) => (
        <ProductItem key={p.id} product={p} onClick={handleClick} />
      ))}
    </ul>
  )
}
```

### 编译器无法优化的场景

以下场景 Compiler 无法自动优化，需要手动处理：

1. **非纯函数组件** — 组件有副作用（直接修改 DOM、全局变量等）
2. **动态 ref 读取** — 在渲染期间读取 `ref.current`
3. **依赖外部可变状态** — 读取非 React 管理的可变值（如全局对象）
4. **自定义 hooks 的动态调用** — 在条件或循环中调用 hook（这本身违反规则）

```tsx
// ❌ Compiler 无法优化——非纯函数
function BadComponent() {
  document.title = 'Hello' // 副作用
  return <div>Hello</div>
}

// ✅ 正确做法——用 useEffect 处理副作用
function GoodComponent() {
  useEffect(() => {
    document.title = 'Hello'
  }, [])
  return <div>Hello</div>
}
```

---

## 13. Next.js Server Component 最佳实践

### Server vs Client 决策指南

```
需要交互（onClick/onChange/useState）    → Client Component（'use client'）
需要浏览器 API（window/localStorage）  → Client Component
需要 useEffect / 生命周期            → Client Component
只做数据获取 + 展示                    → Server Component（默认）
直接访问后端资源（DB/文件系统）      → Server Component
敏感数据处理（token/密钥）           → Server Component
```

### 组件拆分原则

```tsx
// ✅ 推荐：服务端获取数据，客户端处理交互
export default async function ProductPage({ params }: { params: { id: string } }) {
  const product = await fetchProduct(params.id) // 服务端获取
  return (
    <div>
      <ProductInfo product={product} />       {/* Server Component */}
      <AddToCartButton productId={product.id} /> {/* Client Component */}
    </div>
  )
}

// ❌ 避免：整个页面标记为 'use client'
```

### Hydration Mismatch 避免

```tsx
// ❌ 会导致 hydration mismatch
function Timestamp() {
  return <span>{new Date().toLocaleString()}</span>
}

// ✅ 方案 1：客户端渲染 + useEffect
'use client'
function Timestamp() {
  const [time, setTime] = useState<string>('')
  useEffect(() => {
    setTime(new Date().toLocaleString())
  }, [])
  return <span>{time}</span>
}

// ✅ 方案 2：用 suppressHydrationWarning（仅用于无害差异）
<time suppressHydrationWarning>{new Date().toLocaleString()}</time>
```

**常见 hydration mismatch 原因：**
- 时间戳、随机数（服务端和客户端不同）
- `window` / `navigator` 依赖（服务端不存在）
- 条件渲染依赖客户端状态（如 `localStorage`）

### Auth / Cookie 处理

```tsx
import { cookies } from 'next/headers'

// Server Component 中读取 Cookie
export default async function Dashboard() {
  const cookieStore = await cookies()
  const token = cookieStore.get('auth-token')?.value

  if (!token) {
    redirect('/login')
  }

  const user = await fetchUser(token)
  return <DashboardContent user={user} />
}
```

```tsx
// middleware.ts——统一认证拦截
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('auth-token')?.value

  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*'],
}
```

**规则：**
- 认证逻辑放 middleware，不在每个页面重复判断
- 敏感数据（token、密钥）只在 Server Component / Route Handler 中处理
- 不将 token 传递给 Client Component，改用 Server Action 封装
