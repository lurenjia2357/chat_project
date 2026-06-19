# Chat - 仿微信桌面聊天软件

基于 **Qt 6.8** 全栈独立开发的即时通讯桌面应用，包含客户端与服务端，实现注册登录、邮箱验证、好友管理、实时消息等完整功能闭环。

## 技术栈

客户端使用 **Qt Quick Controls 2 (QML)** 构建界面，C++ 处理文件操作等原生能力，通过 `QQmlContext` 注入 QML 环境。服务端基于 **QHttpServer** 搭建 RESTful API，**MySQL** 存储数据，自实现基于 `QSslSocket` 的 SMTP 状态机完成邮件验证码投递。两端通过 HTTP + JSON 通信，采用 `after_id` 增量轮询实现消息同步。

## 项目结构

chat_project/  
├── client/qt_client/ # QML 客户端（登录/注册/重置/聊天 4 个页面）  
├── server/qt_server/ # HTTP 服务端（16 个 API 端点 + SMTP 邮件）

服务端核心模块：`VerifyServer` 路由 API 并管理验证码，`SqlManager` 统一数据库访问，`ChatServer` 处理消息收发与未读追踪，`SmtpClient` 手写 SMTP 协议状态机实现邮件发送。

## 数据库设计

共四张表：`user` 存储用户信息，`friend_relation` 管理双向好友关系（支持申请中/已接受两种状态），`chat_message` 保存所有聊天消息，`conversation` 通过 `last_read_id` 字段实现消息已读/未读计数。

## 核心 API

注册/登录/重置密码 → POST /register_user  /login  /reset_password  
邮箱验证码 → POST /send_email  /verify_code  
头像 → POST /update_avatar  
好友管理 → GET /friend_list  /search_user  /pending_requests  POST /add_friend  /accept_friend  /reject_friend  
聊天 →  POST /send_message  /mark_read  GET /get_messages  /conversations

## 构建与运行

**环境要求**：Qt 6.8（Quick / Network / HttpServer / Sql 模块）、MySQL 8.0 + ODBC 驱动、CMake 3.19+、MSVC 2022 64-bit。

启动前需修改 `verifyserver.h` 中的发件邮箱与 SMTP 授权码。
