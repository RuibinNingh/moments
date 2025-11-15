# 瞬间

这是一个能让你发动态的网页项目

具体功能:
1.你可以通过网页或者客户端(安卓)进行管理在服务端的动态
2.实现md语法与渲染
3.支持嵌入HTML
4.网页前后端一体,实时渲染

## 项目架构

```
/
│
├── server.py                     # 服务端（Flask）
│
├── config.yaml                   # 配置文件  
│
├── templates/                    # 网页文件目录
│     ├── index.html              # 动态展示页面
│     ├── status.html             # 状态历史查看
│     ├── post.html               # 发布动态页面
│     ├── css/
│     ├── js/
│     └── img/
│
├── posts/                        # 动态正文（Markdown 格式）
│     ├── 2025-01-20-1.md         # 动态文件
│     ├── 2025-01-20-2.md         # 动态文件
│     └── ...                     # 更多动态文件
│
├── status/                       # 状态记录（Markdown 格式）
│     ├── 2025-01-20-1.md         # 每天一条或每次更新一条状态
│     ├── 2025-01-20-2.md         # 状态记录文件
│     └── ...                     # 更多历史状态文件
│
└── upload/                       # 上传图片或背景
      ├── bg_20250120_1.png
      └── ...
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
python -m http.server 5000
```
启动静态服务器