# Noctalia Screen Mirror

[Noctalia](https://noctalia.dev) v5 插件：[`screen-mirror`](screen-mirror/README.md) ——
把 niri 主屏的画面镜像到**每一块新接入的外接显示器**，控制中心/栏一键开关，
插上就镜像、拔掉就清理。设置页里可配 OSD 提示、启动默认开关、镜像源、排除的显示器、缩放。

niri 本身没有 output mirroring（`Mirroring is not yet supported`），镜像由配套的
[`niri-mirror`](https://github.com/Goldppx/niri-mirror) 守护进程用
[wl-mirror](https://github.com/Ferdi265/wl-mirror) 完成；本插件是它的 UI 与设置桥。

本仓库按官方 `/noctalia-dev/official-plugins` 与 `/noctalia-dev/community-plugins`
的目录规范组织，可直接作为 `path` / `git` 源使用，也可提交到社区插件商店。

```
catalog.toml          # 源索引：每个插件一行 [[plugin]]
.luaurc               # Luau languageMode = nonstrict
.github/workflows/    # CI：跑 tests/smoke.sh
install.sh            # 注册本仓库为 path 源并启用插件（无需 root）
uninstall.sh          # 卸载（--purge 连配置一起删）
tests/smoke.sh        # 清单/入口/设置/翻译/目录自检
screen-mirror/        # 目录名 = 插件 id 中 "/" 之后的部分
```

## 安装

```sh
# 1. 引擎
sudo pacman -S wl-mirror
git clone https://github.com/Goldppx/niri-mirror.git
cd niri-mirror && ./install.sh

# 2. 插件
git clone https://github.com/Goldppx/noctalia-screen-mirror.git
cd noctalia-screen-mirror
./install.sh
sh tests/smoke.sh
```

`install.sh` 会做的事：把本目录注册成 Noctalia 插件源、启用 `goldesquemoon/screen-mirror`，
然后打印后续步骤（加控制中心磁贴、可选栏挂件、可选 `Mod+U` 键位）。

## 数据流

```
设置页 ──写入──▶ ~/.config/niri-mirror/config.json ──读取──▶ niri-mirror 守护进程
                                                                    │
控制中心磁贴 / 栏挂件 ◀──状态── $XDG_RUNTIME_DIR/niri-mirror/state ◀──写入──┘
```

* `service.luau` 把插件设置写成守护进程的 JSON 配置，然后 `niri-mirror ensure; reload`
  （`ensure` 顺手把没在跑的守护进程拉起来）
* 守护进程每次状态变化都写一份 `key=value` 状态文件，service 转成 `noctalia.state`
  的 `"status"`，磁贴和挂件只负责渲染
* 点磁贴 → `noctalia.state "command"` → `niri-mirror toggle`，和键位开关共用同一份状态

## 开发

```sh
# 校验清单与设置 schema
noctalia plugins lint screen-mirror

# 自检（CI 同款）
sh tests/smoke.sh

# 编辑 .luau 会自动热重载；改 plugin.toml 后
noctalia msg config-reload

# 直接驱动 service 的命令通道
noctalia msg plugin goldesquemoon/screen-mirror:state all toggle
noctalia msg plugin goldesquemoon/screen-mirror:state all sync
```

编辑器补全（可选，官方 API 类型定义不进仓库）：

```sh
curl -fsSL -o noctalia.d.luau \
  https://raw.githubusercontent.com/noctalia-dev/official-plugins/main/noctalia.d.luau
```

## 许可

MIT
