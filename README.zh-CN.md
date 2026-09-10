# Brave Free Origin (v1.12)

[English](README.md)

`Brave Free Origin` 是一个 Windows 图形界面工具, 它能把普通的 Brave 变成更精简、更轻量的版本, 而不需要为 Brave Origin 付费。

道理很简单: Brave 把“移除 AI、加密货币、VPN、推广内容”这个想法命名为 Origin, 然后放到了付费升级里。本项目用本地 Windows 策略免费实现了同样的思路, 并在此之上提供了更多以性能为导向的模式。

本项目受 [MulesGaming/brave-debullshitinator](https://github.com/MulesGaming/brave-debullshitinator) 启发, 但重写成了一个更清爽的 WinForms 应用, 带有一键模式、截图、备份, 以及更符合 Windows 用户习惯的操作流程。

![Brave Free Origin 界面](images/screenshot.png)

> **关于本页面的说明**: 本文档是社区翻译, 内容以 [English README](README.md) 为准。
> 如果发现不一致, 请以英文版为准并提交 issue。中文界面文本尚未经过母语使用者审校, 详见下方 [参与翻译](#参与翻译)。

**v1.12 新增:** 界面可翻译 (内置简体中文), 并且新增了一个可以一次性筛选所有设置的搜索框。
如果你想添加自己的语言, 请看 [TRANSLATING.md](TRANSLATING.md) —— 只需要一个 JSON 文件, 不用碰 PowerShell 代码。

自 v1.12 起, 导出的配置文件使用 **schema 2**: 它用与语言无关的稳定 ID (例如 `p3a`、`newTab`、`brave`)
而不是英文界面文字来记录 hosts 分组、搜索引擎、新标签页目标和启动模式, 并把 `schemaVersion` (文件格式)
和 `appVersion` (应用版本) 分成两个字段。**v1.5-v1.11 导出的配置仍然可以正常导入** —— 旧的英文名称会在导入时被映射。
因此在中文界面导出的配置, 在英文界面导入后结果完全相同, 反之亦然。

---

## 快速上手 (请先读这里)

**1. 先把整个文件夹从 ZIP 中解压出来。** 不要直接在压缩包里运行 —— Windows 会阻止从压缩包中启动 PowerShell 脚本。

**2. 双击 `Brave-Free-Origin.bat`。**

这是启动器。它会用正确的执行策略参数打开 PowerShell, 并向 Windows 申请管理员权限。

> ⚠️ **重要:** 不要直接双击 `Brave-Free-Origin.ps1`。Windows 默认会用记事本打开 `.ps1` 文件 —— 界面**不会**出现, 你会误以为工具坏了。**请始终使用 `.bat`。**

**3. 在 UAC 提示中点击“是”。** 需要管理员权限, 因为工具要写入 `HKEY_LOCAL_MACHINE\Software\Policies\BraveSoftware\Brave` —— 这正是企业 IT 部门下发组策略的位置。没有管理员权限 = 无法写入策略 = 什么都不会发生。

**4. 在界面中点击“读取当前状态”** (左上角), 可以查看本机已有的配置。复选框会亮起, 显示当前已经强制生效的项目。

**5. 在顶部的彩色按钮行中选择一个模式:**

| 按钮 | 作用 |
| --- | --- |
| **快速瘦身** | 最轻度的清理。移除最显眼的附加功能 (Rewards、钱包、VPN、AI、密码管理器)。最安全。 |
| **推荐配置** | 合理的日常使用配置。隐私性好 + 界面更清爽 + 适合播放媒体的默认设置。 |
| **Origin 模式** | 对 Brave 付费版 “Origin” 的免费本地实现。 |
| **隐私 + 提速** | Origin 模式 + 启动和延迟调优。性能方面的默认选择。 |
| **极致性能** | Origin + 提速 + 极致隐私的并集, 外加更多界面精简。较为激进。 |
| **极致隐私** | 硬性锁定 —— 禁用同步、登录、导入和 Brave 更新服务。 |
| **原厂 / 不启用** | 取消所有勾选。之后点击“应用到 Brave”即可还原为默认 Brave。 |

**6. (可选) 在按钮下方的标签页中微调**, 如果你想增删单个策略。

还有一个 `内置 Scriptlet (高级)` 标签页。那是一个独立的可选工具, 用于查看 Brave 内置的广告拦截 scriptlet 规则并手动禁用其中一部分。预设和“应用到 Brave”这个大按钮从不碰它。

**7. 在应用前先点击“预览更改”。** 它会准确显示将要新增、修改、清除、禁用或重置的内容。预览本身不写入任何东西。

**8. 点击“应用到 Brave”** (绿色大按钮)。然后**完全关闭并重新打开 Brave** —— 正在运行的标签页需要重启才能读取新策略。

**8b. (可选) 使用筛选栏** 快速找到某项设置。在标签页上方的搜索框中输入策略名称、说明或分类的任意片段 —— 例如 `密码`、`遥测`、`BraveVPNDisabled` —— 所有标签页都会只保留匹配项, 并在标签标题上显示实时计数。选好一个模式后勾选 **仅显示已选**, 就能只审阅该预设即将强制生效的内容。

筛选 **仅影响显示**: 它只会隐藏和重排行, 绝不会勾选、取消勾选或以其他方式改动任何设置。“清除”会恢复全部行。
筛选覆盖九个策略标签页、“系统 (任务 / 服务)”和“Hosts 屏蔽列表 (DNS 层)”; “搜索与启动”和“内置 Scriptlet (高级)”不在索引范围内
(Scriptlet 标签页有自己的扫描器和搜索框, 针对数千条规则做过优化), 所以这两个标签标题不会显示匹配计数。

**9. (建议) 点击应用内的“校验”按钮。** 它会回读注册表, 确认你的选择确实生效了。你可以复制或保存这份报告。也可以打开 `brave://policy`, 检查每条策略是否显示 `Source: Platform`、`Scope: Machine`、`Status: OK`。

### 切换语言

使用标题栏右上角的 **语言** 下拉框。切换是实时的 —— 不需要重启 —— 并会记录在 `%LOCALAPPDATA%\Brave-Free-Origin\settings.json` 中。

也可以从命令行强制指定, 便于测试:

```powershell
.\Brave-Free-Origin.ps1 -Lang zh-CN
```

如果你从不动这个下拉框, 应用会跟随 Windows 显示语言。解析顺序是: `-Lang` → 已保存的偏好 → Windows 界面语言 → 同语言的语言文件 → 英文。

“同语言”这一步不会跨书写系统匹配: `zh-CN`、`zh-SG`、`zh-Hans-*` 会得到简体中文;
而 `zh-TW`、`zh-HK`、`zh-MO`、`zh-Hant-*` 会保持 **英文**, 除非确实安装了繁体中文语言文件 —— 因为简体文本并不是可用的替代品。
你始终可以从下拉框中手动选择任何已安装的语言。

诊断类输出刻意保持英文: 日志窗格、**预览更改** 报告和 **校验** 报告。这样即使在中文界面下使用, 提交的问题报告维护者也能看懂。

界面上还有一小部分字符串刻意不翻译: 策略名称、计划任务与 Windows 服务名称、注册表路径、域名、URL、原始过滤规则和 scriptlet 标识符。因为这些是你要拿去和 `brave://policy`、`services.msc` 或 Brave 自己的过滤列表逐字比对的东西。

### 文件夹内容

```
Brave-Free-Origin/
├── Brave-Free-Origin.bat   ← 双击这个
├── Brave-Free-Origin.ps1   ← 不要双击 (会用记事本打开)
├── README.md
├── README.zh-CN.md         ← 你正在看这个
├── TRANSLATING.md          ← 如何添加语言
├── LICENSE
├── locales/
│   ├── en-US.json          ← 生成的参考文件, 运行时从不加载
│   └── zh-CN.json          ← 简体中文
└── images/
    ├── screenshot.png
    ├── Brave-before.png
    └── Brave-after.png
```

删除 `locales/` 不会有问题 —— 英文文本内嵌在脚本里, 应用会直接以英文运行。

---

## 它做了什么

应用会把 Brave 企业策略写入:

`HKLM\Software\Policies\BraveSoftware\Brave`

也就是说, 它不只是在视觉上隐藏按钮, 而是使用了各类组织用来管理 Chromium 系浏览器的托管策略机制。

### 关于“由贵组织管理”提示

由于本工具会在 `HKLM\Software\Policies\BraveSoftware\Brave` 下写入真实的企业策略, 只要还有策略生效, Brave 就会在菜单和 `brave://management` 中显示 **“由贵组织管理”**。这是 Chromium 的透明度机制: 任何存在计算机级策略的浏览器都会显示它。**没有**受支持的办法既保留策略又隐藏这条提示 —— Brave 拒绝提供这样的开关, 强行关闭意味着使用可能破坏策略系统的非受支持手段。唯一干净的移除方式就是移除策略 (取消全部勾选后应用, 或使用内置的还原功能)。这是设计如此, 不是缺陷。

它可以禁用或削减:

- Leo / AI 及 Chromium 生成式 AI 功能
- Brave Rewards
- Brave 钱包 / 加密货币 / Web3 附加功能
- Brave VPN
- Brave News
- Brave Talk
- Playlist / Speedreader / Tor / IPFS / WebTorrent
- P3A 分析、统计 ping、Web Discovery、UMA 指标
- 后台模式、预测、Media Router、其他遥测
- 首次运行的导入提示、推广标签页和其他杂项
- 激进模式下的 Brave 更新任务和服务

它也可以为更轻的占用调优 Brave:

- 开启 QUIC / HTTP3
- 硬件加速: 在复选框旁的下拉框中选择启用 (1) 或禁用 (0) (显卡驱动有问题或画面异常时, 禁用会有帮助)
- 开启内存节省
- 更轻量的启动行为
- 性能模式下使用空白主页 / 空白新标签页
- 限制磁盘缓存上限
- 减少浏览器后台活动

---

## 重要的 Windows 说明

### 管理员权限

本应用要写入 `HKLM`, 因此需要管理员权限。这是正常的。PowerShell 脚本会自动提权, BAT 启动器也会提示 UAC 弹窗。

### 执行策略

你**不需要**更改系统的 PowerShell 执行策略。

启动器已经这样调用 PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\Brave-Free-Origin.ps1"
```

这个 bypass 只对该次启动生效, 不会永久削弱本机策略。

脚本接受两个可选参数, 两者都会在 UAC 提权时被转发: `-Lang <locale>` 用于强制指定界面语言, `-BfoSettingsPath <path>` 用于指定不同的设置文件位置。

### SmartScreen / “Windows 已保护你的电脑”

如果因为这是本地脚本而出现 SmartScreen 提示:

1. 点击 `更多信息`
2. 点击 `仍要运行`

只有在你信任这份副本并清楚它的来源时才这样做。

### “此文件来自其他计算机”

如果下载后被 Windows 阻止:

1. 右键点击 `Brave-Free-Origin.bat` 或 `Brave-Free-Origin.ps1`
2. 点击 `属性`
3. 如果看到 `解除锁定`, 勾选它
4. 点击 `应用`

必要时对解压出来的所有文件重复此操作。

### 杀毒软件会不会报警?

有可能。任何工具都无法保证不被报警 —— 一个向 `HKLM` 写入、并且会修改 `hosts` 文件的 PowerShell 脚本, 正是启发式检测最容易盯上的特征, 而启发式报警并不说明代码实际做了什么。本项目能做到的是尽量减少误报, 并且下面每一条你都可以通过阅读源码自行验证:

- 不修改可执行文件, 不改动代码签名, 不做二进制补丁。
- 不做代码混淆, 没有编码过的载荷, 也不会对网络内容执行 `Invoke-Expression`。
- 不内置下载器: 运行时不从网络获取任何东西。
- 不创建计划任务, 不添加自启动项, 没有任何持久化机制。
- 不会尝试禁用、排除自身或绕过任何安全软件。
- 注册表写入指向有公开文档的企业策略路径 `HKLM\Software\Policies\BraveSoftware\Brave` —— 与企业 IT 的做法完全一致。
- hosts 文件修改是显式的: 写入前会在界面中列出, 使用清晰标注的哨兵块 (管理员用记事本就能查看或移除), 并且可以在同一个标签页中撤销。写入采用 Windows 期望的 ASCII 编码, 而不是 UTF-16。
- 每一项破坏性操作前都会先备份到 `Documents\Brave-Free-Origin-Backups\`。
- 整个程序就是一个可以从头读到尾的开源 `.ps1` 文件。

如果杀毒软件确实报警, 它针对的是“PowerShell 脚本正在写入策略注册表值”这个行为本身, 也就是本工具按文档描述在工作。你可以阅读脚本, 或者先点“预览更改” —— 它会列出所有将要进行的写入, 而不会执行其中任何一项。

---

## 如何确认生效

应用设置并重启 Brave 后:

1. 打开 `brave://policy`
2. 找到你选择的策略
3. 检查每条相关策略是否显示:

- `Source: Platform`
- `Scope: Machine`
- `Status: OK`

应用内的“校验”报告可以复制或保存成文本文件。当 Brave 界面看起来仍然不对、但 `brave://policy` 显示策略已正确应用时, 这份报告很有用。

---

## 还原 / 撤销

备份保存在:

`%USERPROFILE%\Documents\Brave-Free-Origin-Backups\`

完全还原为原厂行为:

1. 重新运行应用
2. 选择目标通道, 或选择“所有已安装的通道”
3. 点击“完全还原 / 原厂”

这会移除 Brave 策略键、清除 Brave-Free-Origin hosts 屏蔽块、重新启用已知的 Brave 更新任务, 并把已知被禁用的 Brave 服务重置为手动。

只想还原策略的轻量做法:

1. 选择“原厂 / 不启用”
2. 点击“预览更改”
3. 点击“应用到 Brave”

或者双击某个 `.reg` 备份文件恢复之前的注册表状态; 或者用 Hosts 标签页的“移除 hosts 屏蔽块”按钮只清除 DNS 层屏蔽。

---

## 注意事项

- `Origin 模式` 旨在模仿 Brave Origin 的精简思路, 但它是通过 Windows 策略实现的, 而不是自定义的 Brave 构建。
- `极致性能` 有意较为激进。它会禁用更多便利功能以及 Brave 更新服务/任务, 以进一步降低开销。
- `极致隐私` 在某些方面更严格, 可能影响登录、同步、导入、组件更新和更新流程。
- 关闭组件更新会破坏 Widevine/DRM 播放, 例如 Netflix 或部分 Spotify 网页播放。
- 禁用 Brave 内置 scriptlet 可能破坏广告拦截、反烦扰修复、Cookie 横幅处理、视频播放或网站兼容性。只有在清楚自己在改哪条规则时才使用 scriptlet 管理器。
- Brave 更新时可能替换组件过滤列表的版本。如果你希望更新后重新应用同样的规则禁用, 请导出已禁用的偏好。
- Brave 自身的某些界面缺陷可能导致策略已正确应用但元素仍然可见。这种情况下请以 `brave://policy` 为准。

---

## 参与翻译

界面翻译欢迎贡献, 而且只需要一个 JSON 文件, 完全不用碰 PowerShell 代码。详见 [TRANSLATING.md](TRANSLATING.md)。

简体中文支持是为了响应 [@A81N9](https://github.com/A81N9) 提出的
[#4](https://github.com/TahaHydra/Brave-Free-Origin/issues/4) 而添加的。
中文译文本身并非由该 issue 的提出者提供, 也尚未经过母语使用者审校, 因此
`locales/zh-CN.json` 中 `meta.translators` 为空、`meta.reviewed` 为 `false`,
应用会在语言下拉框下方显示“社区翻译, 未经审核”的小字提示。
如果你能审校中文措辞, 特别是那些警告性文本, 非常欢迎提交 PR。

---

## 平台兼容性

Brave Free Origin 仅支持 Windows —— 它是一个写入 `HKEY_LOCAL_MACHINE\Software\Policies\BraveSoftware\Brave` 的 WinForms 图形界面程序。

macOS 用户可以参考一个非官方的配套项目:

[Johnny-Kao/brave-free-origin-macos](https://github.com/Johnny-Kao/brave-free-origin-macos) —— 它通过 macOS 托管偏好设置 (`/Library/Managed Preferences/com.brave.Browser.plist`) 应用同一类 Brave 企业策略, 而不是写 Windows 注册表。

该项目由他人独立编写和维护, 不是本项目的 fork, 本项目也不为其提供支持 —— 用法和注意事项请查看它自己的 README。

---

## 资料来源

- [Brave 帮助中心 - 组策略](https://support.brave.com/hc/en-us/articles/360039248271-Group-Policy)
- [Brave 帮助中心 - 什么是 Brave Origin?](https://support.brave.app/hc/en-us/articles/38561489788173-What-is-Brave-Origin)
- [brave-core 策略定义](https://github.com/brave/brave-core/tree/master/components/policy/resources/templates/policy_definitions/BraveSoftware)
- [Chrome 企业策略列表](https://chromeenterprise.google/policies/)
- 原始项目 [MulesGaming/brave-debullshitinator](https://github.com/MulesGaming/brave-debullshitinator)
