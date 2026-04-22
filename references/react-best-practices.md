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
