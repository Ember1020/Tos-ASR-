---
name: "asr-eval-platform"
description: "Integrates Volcano Engine TOS file upload and Doubao ASR recognition. Invoke when user wants to upload audio/video files to TOS and run ASR transcription."
---

# ASR Evaluation Platform Skill

## 名称
`asr-eval-platform`

## 说明
整合火山引擎 TOS 文件上传和豆包 ASR 语音识别功能。

## 用途
- 上传音视频文件到火山引擎 TOS 对象存储
- 调用豆包 ASR 2.0 API 进行语音识别
- 测试 ASR API 连接

## 触发条件
用户想要：
- 上传音视频文件到 TOS
- 运行 ASR 语音识别
- 测试 ASR API 是否正常工作

## 可执行脚本

| 脚本 | 功能 |
|------|------|
| `scripts/check-env.sh` | 检查 TOS 和 ASR 环境变量配置 |
| `scripts/upload-to-tos.mjs <file_path> [prefix]` | 上传本地文件到 TOS，输出 `{ key, url }` |
| `scripts/upload-or-url-asr.sh --file <path> \| --url <url> [--request-id <id>]` | 本地文件上传到 TOS 或直接用 URL，并执行 ASR |
| `scripts/test-asr.sh <audio_url> [request_id]` | 直接调用豆包 ASR（submit/query）做联通性测试 |

## 推荐用法
- 本地文件 → TOS → ASR：`./scripts/upload-or-url-asr.sh --file /path/to/audio.wav`
- 直接 URL → ASR：`./scripts/upload-or-url-asr.sh --url https://example.com/audio.wav`

## 输出格式
- 默认输出包含 `utterances`：每行包含 `start/end` 时间戳、`speaker`、以及该句文本
- 末尾会额外输出聚合后的 `full_text`

## 快速开始
1. 复制环境变量模板：`cp .env.example .env`
2. 填写 `.env` 里的 ASR/TOS 配置
3. 执行检查：`./scripts/check-env.sh`
4. 执行识别：`./scripts/upload-or-url-asr.sh --file /path/to/input.mp4`

## 环境变量

### TOS 配置
- `VITE_TOS_ACCESS_KEY_ID` - TOS 访问密钥
- `VITE_TOS_SECRET_ACCESS_KEY` - TOS 密钥
- `VITE_TOS_REGION` - TOS 区域
- `VITE_TOS_BUCKET` - TOS Bucket 名称
- `VITE_TOS_ENDPOINT` - TOS 端点

### 可选配置
- `TOS_KEY_PREFIX` - 上传对象 key 前缀（默认 `datasets`）
- `TOS_PRESIGN_EXPIRES` - 预签名 URL 有效期（秒，默认 `3600`）
- `ASR_POLL_INTERVAL_SEC` - 轮询间隔（秒，默认 `2`）
- `ASR_POLL_MAX_ATTEMPTS` - 最大轮询次数（默认 `30`）
- `ASR_PRINT_JSON` - 是否额外输出完整 JSON（`1` 输出，默认 `0`）

### ASR 配置
- `ASR_APPID` - 火山引擎 ASR App ID
- `ASR_TOKEN` - 火山引擎 ASR Access Token
- `ASR_SUBMIT_URL` - ASR 任务提交 URL
- `ASR_QUERY_URL` - ASR 结果查询 URL
