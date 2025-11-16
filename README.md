# 瞬间

这是一个能让你发动态的网页项目

具体功能:
- 1.你可以通过网页或者客户端(安卓)进行管理在服务端的动态
- 2.实现md语法与渲染
- 3.支持嵌入HTML
- 4.网页前后端一体,实时渲染

## 项目架构

```
├── flutter_moments/          # 安卓客户端
├── posts/                    # 动态（md格式）
│   ├── 2025-11-15-1.md
│   ├── 2025-11-15-2.md
│   └── 2025-11-16-1.md
├── status/                   # 状态（md格式）
│   ├── 2025-11-15-1.md
│   └── 2025-11-15-2.md
├── templates/                # 前端
│   ├── css/                  # 样式
│   │   └── style.css
│   ├── script/               # 脚本
│   │   ├── api.js
│   │   ├── index.js
│   │   ├── interaction.js
│   │   ├── post.js
│   │   ├── search.js
│   │   ├── search_input.js
│   │   ├── search_page.js
│   │   ├── status.js
│   │   └── status_view.js
│   ├── index.html            # 主页（显示动态）
│   ├── post.html             # 动态/状态详细显示页
│   ├── search.html           # 搜索页面
│   ├── status.html           # 状态显示页面
│   └── status_view.html
├── upload/                   # 附件上传
│   └── avatar.png
├── config.yaml               # 配置文件
├── README.md 
└── server.py                 # 后端，使用flask
```

## 存储

### 配置文件

```
server:
  host: 127.0.0.1   # 服务器地址
  port: 5000        # 端口

nickname: Ruibin_Ningh   # 昵称
avatar: avatar.png        # 头像文件名

api_key: your-api-key-here   # API Key
view_time_limit_days: 7      # 可见天数
comment: false               # 是否开启评论

```

### 动态

动态文件示例

`posts/2025-01-20-1.md`

```
---
time: "2025-01-20 10:00:00"
tags: ["微信"]
---

今天继续开发动态系统，优化了状态管理模块，整合了 Markdown 支持。  
在实现后台功能时遇到了一些小问题，但成功解决了。

正在思考如何优化 API 性能，未来可能会采用缓存机制来提高响应速度。

```

### 状态

状态文件示例

`status/2025-01-20-1.md`

```
---
time: "2025-01-20 10:00:00"
name: "coding(自定义)"
background: "/upload/bg_20250120_1.png"
---

正在编写动态系统代码，忙碌而充实！

```

## 标签系统

为了鉴别一些动态来源之类的,我计划添加标签系统

一般标签例如"微信"表示这个动态是和你的微信朋友圈同步的,前端渲染时应该提示"来自微信朋友圈"

## 后端相关变量/API

### 获取基础信息

`GET /api/user/info`

示例返回

```
{
  "nickname": "Ruibin_Ningh",
  "avatar": "avatar.jpg",
  "post_count": 42,
  "status_count": 8,
  "latest_post_time": "2025-01-20 10:00:00",
  "latest_status_time": "2025-01-19 22:31:05"
}
```

### 获取动态列表

`GET /api/posts`

会返回动态的列表,超过期限的内容不会显示(可配置)

示例返回

```
{
  "count": 2, //动态的总数
  "posts": [
    {
      "meta": {
        "time": "2025-01-20 10:00:00",
        "tags": ["微信"]
      },
      "html": "<p>渲染后的正文 HTML……</p>",
      "raw": "---\n...原 Markdown...\n",
      "filename": "2025-01-20-1.md"
    },//第一个动态
    {
      "meta": {
        "time": "2025-01-20 10:00:00",
        "tags": ["微信"]
      },
      "html": "<p>渲染后的正文 HTML……</p>",
      "raw": "---\n...原 Markdown...\n",
      "filename": "2025-01-20-1.md"
    }//第二个动态
  ]
}
```

### 获取单个动态详情

`GET /api/post/<post_id>`

(例如`/api/post/2025-01-20-1`)

```
{
  "meta": {
    "time": "2025-01-20 10:00:00",
    "tags": ["微信"]
  },
  "html": "<p>今天继续开发动态系统，优化了状态管理模块。</p>",
  "raw": "---\ntime: \"2025-01-20 10:00:00\"\ntags: [\"微信\"]\n---\n今天继续开发动态系统，优化了状态管理模块。",
  "filename": "2025-01-20-1.md"
}
```

### 获取当前状态

`GET /api/status/current`

返回示例

```
{
  "filename": "2025-11-15-1.md",
  "meta": {
    "time": "2025-11-15 10:00:00",
    "name": "coding(自定义)",
    "background": "/upload/bg_20251115_1.png"
  },
  "raw": "---\ntime: \"2025-11-15 10:00:00\"\nname: \"coding(自定义)\"\nbackground: \"/upload/bg_20251115_1.png\"\n---\n\n今天正在写动态系统，忙碌而充实！",
  "html": "<p>今天正在写动态系统，忙碌而充实！</p>"
}
```

### 发送动态

```
POST /api/post/new
X-API-KEY: your-api-key
Content-Type: application/json

{
    "content": "今天测试 API 新功能",
    "tags": ["测试","API"],
    "time": "2025-11-15 15:00:00"
}
```

### 设置状态

```
POST /api/status/new
X-API-KEY: your-api-key
Content-Type: application/json

{
    "content": "正在开发 API 认证功能",
    "name": "coding(自定义)",
    "background": "/upload/bg_20251115_2.png",
    "time": "2025-11-15 15:30:00"
}
```


## 运行
```
python server.py
```
启动服务器