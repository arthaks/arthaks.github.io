---
title: "通用技术沉淀 | 第0篇：Linux下轻量化运行企业微信"
date: 2026-06-25 15:55:00 +0800
categories: [Tech, 通用技术沉淀]
tags: [通用技术沉淀, Linux, Docker, RDP, WeCom]
math: false
mermaid: false
---

## 一、 背景、设计与结论

### 1. 背景与问题
在 Linux 环境下运行企业微信（WeCom）一直存在兼容性或资源占用的问题：
- **Wine / Bottles 方案**：容易出现字体发虚、截图失效、以及窗口边缘出现黑框或残留等兼容性问题。
- **Waydroid 方案**：对硬件环境有要求（强依赖 Wayland），且在容器内处理中文输入法切换较为繁琐。
- **全功能 Windows 虚拟机**：资源占用过高（通常需 4核 4GB 内存以上），仅用于运行单一聊天软件性价比较低。
- **RemoteApp 调试折腾**：直接通过 RDP RemoteApp 协议映射单窗口时，由于企业微信基于 Chromium Embedded Framework (CEF) 架构，会产生多个透明的“阴影子窗口”，在 Linux 下会被错误渲染成多个实心蓝色方块；同时，Windows 10/11 的单用户会话限制会导致在网页控制台已登录的情况下，RDP 连接卡死在欢迎界面（`LOGON_MSG_BUMP_OPTIONS` 错误）。

### 2. 思路与目标
通过轻量化配置的虚拟机搭配无边框 RDP 全桌面实现替代。
- **硬件降配**：利用 `dockur/windows` 镜像运行 Tiny10（精简版 Windows 10 LTSC），将容器资源限制在 2核 CPU 和 2GB 内存。
- **视觉去边框**：放弃不稳定的 RemoteApp 协议，直接连接 Windows 桌面。通过 FreeRDP 客户端参数隐去 Linux 窗口边框，同时在 Windows 内部通过注册表强制隐藏任务栏并关闭桌面图标，使整个 RDP 窗口在视觉上等同于一个独立的原生企业微信窗口。

### 3. 结论与进阶
该方案在保证企业微信稳定运行的同时，将内存开销控制在 2GB 左右。如果将此 Docker 容器部署在局域网内的闲置服务器上，本地仅需通过 RDP 脚本连接，可实现本地零性能损耗、24 小时消息挂机接收，且内网延迟基本无感。

---

## 二、 实施步骤与环境配置

> **部署环境说明**
> - **外层容器**：Docker & Docker Compose 容器环境，宿主机需支持 KVM 虚拟化（`/dev/kvm`）。
> - **镜像底座**：`dockurr/windows` 镜像（通过 QEMU 引导运行 Windows）。
> - **本地客户端**：FreeRDP 3 (`xfreerdp3`）客户端，用于支持无边框模式（`-decorations`）及软件 GDI 渲染（`/gdi:sw`）。

### 步骤 1：部署轻量级 Windows 容器
在宿主机创建工作目录并编写 `compose.yaml`。请将配置文件中的 `USERNAME` 和 `PASSWORD` 改为你自定义的凭据。

```yaml
name: "wecom-server"
volumes:
  wecom_data:
services:
  windows:
    image: ghcr.io/dockur/windows:latest
    container_name: WeCom-Server
    environment:
      VERSION: "tiny10"      # 使用精简版 Windows 10
      RAM_SIZE: "2G"         # 物理内存限制 2GB
      CPU_CORES: "2"         # CPU 核心限制 2核
      DISK_SIZE: "32G"       # 磁盘空间限制 32GB
      USERNAME: "qwer"       # 登录用户名
      PASSWORD: "qwer"       # 登录密码
      HOME: "/home/username" # 替换为宿主机实际的家目录
    ports:
      - 8007:8006            # Web VNC 端口（仅用于初期安装与配置）
      - 3391:3389/tcp        # RDP 服务端口
      - 3391:3389/udp
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
    volumes:
      - wecom_data:/storage
      - /home/username:/shared # 宿主机家目录挂载至 Windows 内部的 \\host.lan\Data
    devices:
      - /dev/kvm
      - /dev/net/tun
```
在终端执行 `docker compose up -d` 启动容器。Windows 会执行无人值守自动安装，耗时约 10-20 分钟。

### 步骤 2：Windows 内部配置与隐藏任务栏
1. 通过浏览器访问 `http://127.0.0.1:8007` 进入 Windows 桌面。
2. 安装企业微信并取消勾选“开机自动启动”（避免抢占 RDP 会话）。
3. 隐藏桌面所有图标，并在系统属性中关闭“在窗口下显示阴影”（路径：系统属性 `sysdm.cpl` -> 高级 -> 性能设置 -> 取消勾选“在窗口下显示阴影”）。
4. 由于未激活的 Windows 限制了任务栏设置，需打开 **PowerShell (管理员)** 运行以下命令强制开启任务栏自动隐藏：
   ```powershell
   $p='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
   $v=(Get-ItemProperty -Path $p).Settings
   $v[8]=3
   Set-ItemProperty -Path $p -Name Settings -Value $v
   Stop-Process -f -ProcessName explorer
   ```
5. 完成配置后，在 Windows 开始菜单中选择 **注销 (Sign out)**，退回到系统锁屏界面。直接关闭浏览器网页。

### 步骤 3：配置本地快捷启动与固定至 Dock 栏
1. 在宿主机创建启动脚本 `/home/username/bin/wecom-rdp.sh`（注意替换路径 and 凭据）：
   ```bash
   #!/bin/bash
   # 全桌面无边框模式连接
   xfreerdp3 /v:127.0.0.1:3391 /u:qwer /p:qwer /cert:ignore +clipboard +dynamic-resolution -decorations /size:1200x800
   ```
   执行 `chmod +x /home/username/bin/wecom-rdp.sh` 赋予权限。

2. 在宿主机创建桌面入口文件 `/home/username/.local/share/applications/wecom-rdp.desktop`：
   ```ini
   [Desktop Entry]
   Version=1.0
   Type=Application
   Name=企业微信 (无边框)
   Comment=WeChat Work via Docker RDP
   Exec=/home/username/bin/wecom-rdp.sh
   Icon=/home/username/.local/share/icons/wecom.png
   Terminal=false
   StartupNotify=true
   Categories=Network;Chat;
   ```

3. 将图标图片保存至指定位置后，通过 GNOME 终端或系统命令将该快捷方式添加至 Dock 栏收藏夹中。
   在 Linux 宿主机通过快捷键 `Super (Win) + 鼠标左键` 可以对无边框窗口进行自由拖动，使用 `Super + 鼠标中键` 可实现动态分辨率缩放。

   运行效果参考：

   ![无边框运行效果图](/assets/img/2026-06-25/pic.png)
