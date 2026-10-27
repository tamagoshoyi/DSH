# -*- coding: utf-8 -*-
"""Build the 2026-10-27 machine audit workbook (program list + junk + zombies)."""
import csv
import os
from datetime import datetime

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

WS = r"C:\Users\WINDOWS\Documents\deepseek-harness\default-workspace"
TMP = os.path.join(WS, ".tmp")
OUT = os.path.join(WS, "docs", "program-audit-2026-10-27.xlsx")

HEADER_FILL = PatternFill("solid", fgColor="1F3864")
HEADER_FONT = Font(name="微软雅黑", size=10, bold=True, color="FFFFFF")
BODY_FONT = Font(name="微软雅黑", size=10)
TITLE_FONT = Font(name="微软雅黑", size=16, bold=True, color="1F3864")
SUB_FONT = Font(name="微软雅黑", size=11, bold=True, color="1F3864")
THIN = Side(style="thin", color="D9D9D9")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
FILL_DEL = PatternFill("solid", fgColor="FCE4E4")
FILL_MAYBE = PatternFill("solid", fgColor="FFF2CC")
FILL_KEEP = PatternFill("solid", fgColor="E2EFDA")

CAT_CN = {
    "runtime": "运行库", "driver": "驱动/硬件组件", "system": "系统组件",
    "game": "游戏/平台", "dev": "开发工具", "app": "应用软件",
    "productivity": "办公", "utility": "工具", "other": "其他",
}

ADVICE = [
    ("AntiCheatExpert", "保留", "ACE 反作弊运行库（腾讯系游戏依赖）。删了对应游戏起不来。"),
    ("Epic Games Launcher", "待定", "Epic 平台。只在玩 Epic 游戏时需要；连同 OES/UE4 前置一起卸可回收约 0.7 GB。"),
    ("Epic Online Services", "待定", "Epic 联机服务组件，随 Epic 平台一起卸载。"),
    ("UE4 Prerequisites", "待定", "虚幻 4 运行前置，Epic 游戏需要。"),
    ("Launcher Prerequisites (x64)", "待定", "Epic 启动器前置。"),
    ("Paradox Launcher v2", "待定", "Paradox 游戏启动器（群星/CK3 等）。不玩可删。"),
    ("Steam", "保留", "游戏平台，装着大部分游戏库。"),
    ("Xbox Service", "保留", "Xbox 服务组件，XGP 与手柄支持要用。"),
    ("Microsoft GameInput", "保留", "游戏输入组件，很小。"),
    ("腾讯QQ", "待定", "QQ 客户端 314 MB；另有 4.1 GB 数据在 Roaming\\Tencent。"),
    ("迅雷", "待定", "1.38 GB。之前发现它的 WFP 驱动文件已丢失、服务已被禁用，属于半卸载状态；不用建议卸掉，卸载器 D:\\Thunder\\Program\\ThunderUninstall.exe 还在。"),
    ("火绒安全软件", "待定", "当前进程没在跑、Defender 也关着 —— 这台机器现在等于没有实时防护。要么恢复火绒常驻，要么卸载并开回 Defender。"),
    ("RivaTuner Statistics Server", "可删", "RTSS：帧率叠加与限帧工具，通常随 MSI Afterburner 一起装。不监控帧率可删。"),
    ("Process Lasso", "待定", "进程优先级/CPU 亲和性调优。不是必需品。"),
    ("Imaging Edge", "保留", "索尼相机联机/看图，你在处理 ARW 素材，保留。"),
    ("KOOK", "待定", "语音开黑软件 267 MB。"),
    ("CCtalk", "待定", "沪江 CCtalk 在线课堂客户端；注册表没写体积，实际目录未找到。"),
    ("UU加速器", "待定", "网易 UU 游戏加速器，玩外服才需要。"),
    ("ToDesk", "待定", "远程控制，会常驻服务。不用可删。"),
    ("百度网盘", "待定", "897 MB，另有 325 MB 缓存在 Roaming\\baidu。"),
    ("网易云音乐", "待定", "音乐客户端。"),
    ("必剪", "待定", "B 站剪辑工具 589 MB，功能与剪映重叠，二选一即可。"),
    ("剪映专业版", "待定", "LocalAppData\\JianyingPro 里还压着 6.1 GB 草稿与缓存，不用就一起清。"),
    ("搜狗输入法", "保留", "当前输入法，982 MB（含词库与组件）。"),
    ("BitComet", "待定", "比特彗星 BT 客户端，与迅雷功能重叠。"),
    ("TRAE CN", "待定", "字节 TRAE AI IDE 1.68 GB，另有 Roaming\\TRAE SOLO CN 338 MB。不写代码可删。"),
    ("DeepSeek Harness", "保留", "就是当前这个桌面客户端。"),
    ("潘多拉的玩具盒", "待定", "未识别的第三方小工具，先看一眼安装位置再决定。"),
    ("Microsoft Teams Meeting Add-in", "可删", "Outlook 的 Teams 会议插件，没装 Teams 就没用。"),
    ("Windows 电脑健康状况检查", "可删", "Win11 升级兼容性检查工具，用完就没价值。"),
    ("Microsoft Update Health Tools", "保留", "Windows 更新修复组件，很小。"),
    ("OneDrive", "待定", "562 MB。不用云同步可直接卸载，不影响系统。"),
    ("WPS Office", "保留", "办公套件。"),
    ("Microsoft Visual C++", "保留", "VC++ 运行库，很多软件依赖，绝对别删。"),
    ("Microsoft Visual Basic for Applications", "保留", "VBA 运行时，Office/WPS 宏需要。"),
    (".NET Sdk", "待定", "只做 Windows 桌面开发可卸（MAUI/iOS/tvOS/MacCatalyst 这些 manifest 基本没用上）。"),
    ("Microsoft .NET", "待定", "只在不跑 .NET 程序时可卸；多数游戏/工具仍依赖 .NET 8/6 运行时。"),
    ("Python 3.14.5 Test Suite", "可删", "Python 自带的测试套件 36.8 MB，个人使用不需要。"),
    ("Python 3.14.5 Documentation", "可删", "离线文档 64 MB，网上能查。"),
    ("Python 3.14.5 Tcl/Tk Support", "待定", "只有用 tkinter 图形界面才需要。"),
    ("Python Launcher", "保留", "py 启动器，很小。"),
    ("灰区战争", "待定", "Gray Zone Warfare 本体（Steam 库）25.7 GB。"),
    ("无敌号", "待定", "The Invincible 本体 38.8 GB。"),
    ("威赫战线 MENACE", "待定", "MENACE 本体 11 GB。"),
    ("Barotrauma", "待定", "潜渊症 1.18 GB。"),
    ("Mount & Blade", "待定", "骑砍战团 4.7 GB。"),
    ("鹰角启动器", "保留", "鹰角启动器 + 终末地本体，体积列算的是整个安装目录（99.6 GB）。"),
    ("Update for Windows 10", "保留", "系统更新记录，不要动。"),
    ("Dynamic Application Loader", "保留", "Intel ME 组件。"),
    ("Microsoft Edge", "保留", "系统自带浏览器，也是 WebView2 的宿主，卸了会连带一批应用异常。"),
    ("OpenAL", "保留", "OpenAL 音频库，部分游戏依赖。"),
    ("CertsUpdater", "可删", "Saber Interactive 游戏遗留的证书更新器，很小但已无用。"),
    ("Adobe", "可删", "Creative Cloud 卸载后剩下的空壳（PF 87 MB + PF(x86) 37 MB）。"),
    ("Interhaptics", "可删", "Razer 触觉反馈组件 338 MB，安装器没登记卸载项，但自带 Uninstall.exe。"),
]

JUNK_NOTE = {
    "D3DSCache": "DirectX 着色器缓存，删掉会自动重建，只是之后几次进游戏稍卡。",
    "JianyingPro": "剪映草稿与缓存，可能含未导出的工程，删前先开剪映确认。",
    "Larian Studios": "博德之门 3 的存档/配置/mod，存档就在里面，别整目录删。",
    "Tencent": "QQ/微信账号数据与文件缓存，删了要重新登录并丢本地聊天文件。",
    "GZW": "灰区战争缓存。",
    "Wardogs": "MENACE 的存档与配置。",
    "Hujiang": "沪江网校客户端数据。",
    "poi": "舰 C 辅助工具 poi 的数据。",
    "@deepseek-ai/dsh-desktop-updater": "DSH 桌面端更新包缓存，可删。",
    "ElectronicObserver": "舰 C 辅助 ElectronicObserver 数据。",
    "Fatshark": "战锤系列存档/配置。",
    "BCUT": "BCUT 工具数据。",
    "CalabiYau": "某游戏/工具数据，2024 年后未再更新。",
    "PlatformProcess": "平台进程组件数据。",
    "Thunder Network": "迅雷网络组件残留。",
    "TRAE SOLO CN": "TRAE 的数据与缓存。",
    "baidu": "百度网盘缓存。",
    "ichat": "聊天/IM 数据。",
    "pnpm": "pnpm 全局包仓库（我的工具链也在用），删了下次装包会重下。",
    "CEF": "Chromium 内嵌框架缓存。",
    "Programs": "LocalAppData\\Programs 是用户级安装目录（Paradox、VS Code 等都在里面），别整体删。",
    "SogouInput": "搜狗输入法词库与配置。",
}


CAT_OVERRIDE = {
    "无敌号": "game", "Barotrauma 潜渊症": "game", "Mount & Blade: Warband": "game",
    "威赫战线 MENACE": "game", "灰区战争": "game", "鹰角启动器": "game",
    "腾讯QQ": "app", "剪映专业版": "app", "迅雷": "app", "搜狗输入法 16.8.0正式版": "app",
    "火绒安全软件": "utility", "Microsoft Edge": "app",
}


def cat_of(p):
    return CAT_OVERRIDE.get(p["Name"], p["Category"])


def advice_for(name, cat):
    for key, verdict, note in ADVICE:
        if key.lower() in name.lower():
            return verdict, note
    if cat in ("runtime", "driver", "system"):
        return "保留", "运行库/驱动/系统组件，删了会连带影响别的软件。"
    if cat == "game":
        return "待定", "游戏或游戏平台组件。"
    if cat == "dev":
        return "待定", "开发工具。"
    return "待定", "应用软件。"


def norm_date(s):
    s = (s or "").strip()
    if len(s) == 8 and s.isdigit():
        y, m, d = int(s[:4]), int(s[4:6]), int(s[6:])
        if 2000 <= y <= 2035 and 1 <= m <= 12 and 1 <= d <= 31:
            return f"{y:04d}-{m:02d}-{d:02d}"
    return ""


def style_header(ws, row=1, height=26):
    for cell in ws[row]:
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(vertical="center", horizontal="center", wrap_text=True)
        cell.border = BORDER
    ws.row_dimensions[row].height = height


def finish_sheet(ws, widths, freeze="A2", last_col=None):
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.freeze_panes = freeze
    ws.auto_filter.ref = f"A1:{get_column_letter(len(widths))}{ws.max_row}"


def read_csv(name):
    path = os.path.join(TMP, name)
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


progs = read_csv("progs.csv")
junk = read_csv("junk.csv")
zombies = read_csv("zombies.csv")
appdata = read_csv("appdata.csv")

wb = Workbook()

# ---------------- 说明 ----------------
ws = wb.active
ws.title = "说明"
ws.sheet_view.showGridLines = False
ws.column_dimensions["A"].width = 3
ws.column_dimensions["B"].width = 26
ws.column_dimensions["C"].width = 110

ws["B2"] = "本机软件与空间体检"
ws["B2"].font = TITLE_FONT
ws["B3"] = f"生成时间：{datetime.now():%Y-%m-%d %H:%M}　|　范围：C: 与 D: 　|　工具：PowerShell 注册表/文件系统扫描"
ws["B3"].font = Font(name="微软雅黑", size=9, color="808080")

size_known = [float(p["SizeMB"]) for p in progs if p["SizeMB"] not in ("", "-1")]
total_mb = sum(size_known)
safe_junk = sum(float(j["SizeMB"]) for j in junk if j["Verdict"] == "safe" and float(j["SizeMB"]) > 0)
appdata_mb = sum(float(a["SizeMB"]) for a in appdata)
sugg_del = sum(float(p["SizeMB"]) for p in progs
               if p["SizeMB"] not in ("", "-1")
               and advice_for(p["Name"], p["Category"])[0] == "可删")

rows = [
    ("一、这次扫了什么", ""),
    ("已安装程序", f"{len(progs)} 条（含 Microsoft Store 应用），覆盖 HKLM 64/32 位、HKCU 与 MSI 产品库"),
    ("程序总体积", f"约 {total_mb/1024:.1f} GB（仅统计注册表或安装目录能给出体积的 {len(size_known)} 项）"),
    ("垃圾与缓存", f"{len(junk)} 项，其中标记“安全可删”的约 {safe_junk/1024:.1f} GB"),
    ("疑似残留数据目录", f"{len(appdata)} 个，合计约 {appdata_mb/1024:.1f} GB（多数需你确认后再动）"),
    ("僵尸注册表项", f"{len(zombies)} 条（服务 1、孤儿目录 11）；卸载记录、启动项、快捷方式、App Paths 均已复查，未再发现死链"),
    ("", ""),
    ("二、怎么读这份表", ""),
    ("程序清单", "每条都给了“建议”和“解析”。你只需要在最后一列“你的决定”里选 保留/删除/待定"),
    ("垃圾与残留", "按体积从大到小，标了“安全 / 需确认 / 保留勿动”，同样留了“你的决定”列"),
    ("僵尸项", "注册表里指向已不存在文件的条目，附了成因和处置建议"),
    ("", ""),
    ("三、几个重要提醒", ""),
    ("不要删的", "WinSxS、C:\\Windows\\Installer、pagefile/hiberfil、VC++ 运行库、驱动组件、EasyAntiCheat"),
    ("最大的一块", "D3DSCache 10.1 GB + ASUS 诊断日志 2.3 GB + 剪映 6.1 GB + 迅雷下载 25.3 GB"),
    ("火绒 vs Defender", "两个防护都没在跑，建议二选一恢复，否则等于裸奔"),
    ("没覆盖到的", "计划任务需要管理员权限；DISM 组件清理（WinSxS 可再收 3–8 GB）也要管理员终端"),
    ("", ""),
    ("四、下一步", ""),
    ("你填完“你的决定”", "把表发回给我（或直接说“删掉标记为删除的那些”），我出执行脚本，先 dry-run 再真删"),
]
r = 5
for label, value in rows:
    if value == "" and label:
        ws.cell(row=r, column=2, value=label).font = SUB_FONT
    else:
        ws.cell(row=r, column=2, value=label).font = Font(name="微软雅黑", size=10, bold=True)
        c = ws.cell(row=r, column=3, value=value)
        c.font = BODY_FONT
        c.alignment = Alignment(wrap_text=True, vertical="top")
    r += 1

# ---------------- 重点程序（先看这张） ----------------
ws = wb.create_sheet("重点程序")
cols = ["#", "名称", "类别", "发布者", "版本", "安装日期", "体积(MB)", "建议", "解析", "你的决定"]
ws.append(cols)
style_header(ws)

focus = []
order = {"可删": 0, "待定": 1, "保留": 2}
for p in progs:
    if cat_of(p) in ("runtime", "driver", "system"):
        continue
    verdict, note = advice_for(p["Name"], cat_of(p))
    focus.append((verdict, p, note))
focus.sort(key=lambda x: (order.get(x[0], 3), -float(x[1]["SizeMB"] or -1)))

for i, (verdict, p, note) in enumerate(focus, start=1):
    size = p["SizeMB"]
    size_val = None if size in ("", "-1") else round(float(size), 1)
    ws.append([i, p["Name"], CAT_CN.get(cat_of(p), cat_of(p)), p["Publisher"],
               p["Version"], norm_date(p["InstallDate"]), size_val, verdict, note, ""])

for row in ws.iter_rows(min_row=2, max_row=ws.max_row, max_col=len(cols)):
    for cell in row:
        cell.font = BODY_FONT
        cell.border = BORDER
        cell.alignment = Alignment(vertical="center", wrap_text=cell.column in (2, 4, 9))
    row[7].fill = {"可删": FILL_DEL, "待定": FILL_MAYBE, "保留": FILL_KEEP}[row[7].value]
    row[6].number_format = "#,##0.0"

dv0 = DataValidation(type="list", formula1='"保留,删除,待定"', allow_blank=True)
ws.add_data_validation(dv0)
dv0.add(f"J2:J{ws.max_row}")
finish_sheet(ws, [5, 46, 15, 30, 20, 12, 11, 8, 66, 10], freeze="C2")

# ---------------- 程序清单 ----------------
ws = wb.create_sheet("程序清单")
cols = ["#", "名称", "类别", "发布者", "版本", "安装日期", "体积(MB)", "安装位置", "建议", "解析", "你的决定"]
ws.append(cols)
style_header(ws)

order = {"可删": 0, "待定": 1, "保留": 2}
prepared = []
for p in progs:
    verdict, note = advice_for(p["Name"], cat_of(p))
    prepared.append((order.get(verdict, 3), p, verdict, note))
prepared.sort(key=lambda x: (x[0], cat_of(x[1]), -float(x[1]["SizeMB"] or -1)))

for i, (_, p, verdict, note) in enumerate(prepared, start=1):
    size = p["SizeMB"]
    size_val = None if size in ("", "-1") else round(float(size), 1)
    ws.append([
        i, p["Name"], CAT_CN.get(cat_of(p), cat_of(p)), p["Publisher"],
        p["Version"], norm_date(p["InstallDate"]), size_val,
        p["Location"], verdict, note, "",
    ])

for row in ws.iter_rows(min_row=2, max_row=ws.max_row, max_col=len(cols)):
    for cell in row:
        cell.font = BODY_FONT
        cell.border = BORDER
        cell.alignment = Alignment(vertical="center", wrap_text=cell.column in (2, 4, 8, 10))
    fill = {"可删": FILL_DEL, "待定": FILL_MAYBE, "保留": FILL_KEEP}[row[8].value]
    row[8].fill = fill
    row[6].number_format = "#,##0.0"

dv = DataValidation(type="list", formula1='"保留,删除,待定"', allow_blank=True)
ws.add_data_validation(dv)
dv.add(f"K2:K{ws.max_row}")
finish_sheet(ws, [5, 46, 15, 30, 20, 12, 11, 46, 8, 62, 10], freeze="C2")

# ---------------- 垃圾与残留 ----------------
ws = wb.create_sheet("垃圾与残留")
cols = ["类型", "路径 / 名称", "体积(MB)", "安全等级", "说明", "建议", "你的决定"]
ws.append(cols)
style_header(ws)

items = []
verdict_map = {"safe": ("安全", "可删"), "review": ("需确认", "待定"), "keep": ("保留勿动", "保留")}
group_cn = {"temp": "临时文件", "cache": "缓存", "log": "日志", "update": "更新缓存",
            "install": "安装/组件库", "junk": "系统垃圾", "sysfile": "系统文件", "installer": "安装包", "user": "用户数据"}
for j in junk:
    if float(j["SizeMB"]) < 0:
        continue
    lvl, adv = verdict_map.get(j["Verdict"], ("需确认", "待定"))
    items.append((float(j["SizeMB"]), group_cn.get(j["Group"], j["Group"]), j["Path"], lvl, j["Note"], adv))
for a in appdata:
    name = a["Name"]
    note = JUNK_NOTE.get(name, "未匹配到任何已安装程序的数据目录，可能是卸载残留；删前请确认里面没有存档或配置。")
    lvl, adv = ("需确认", "待定")
    if name == "D3DSCache" or "updater" in name:
        lvl, adv = ("安全", "可删")
    elif name in ("Thunder Network",):
        lvl, adv = ("安全", "可删")
    items.append((float(a["SizeMB"]), "残留数据目录", f"{a['Path']}（{a['Modified']} 最后修改）", lvl, note, adv))

items.sort(key=lambda x: -x[0])
for size, typ, path, lvl, note, adv in items:
    ws.append([typ, path, round(size, 1), lvl, note, adv, ""])

for row in ws.iter_rows(min_row=2, max_row=ws.max_row, max_col=len(cols)):
    for cell in row:
        cell.font = BODY_FONT
        cell.border = BORDER
        cell.alignment = Alignment(vertical="center", wrap_text=cell.column in (2, 5))
    lvl = row[3].value
    row[3].fill = {"安全": FILL_KEEP, "需确认": FILL_MAYBE, "保留勿动": PatternFill("solid", fgColor="DDEBF7")}[lvl]
    row[2].number_format = "#,##0.0"

dv2 = DataValidation(type="list", formula1='"删除,保留,待定"', allow_blank=True)
ws.add_data_validation(dv2)
dv2.add(f"G2:G{ws.max_row}")
finish_sheet(ws, [14, 74, 11, 11, 66, 8, 10], freeze="C2")

# ---------------- 僵尸项 ----------------
ws = wb.create_sheet("僵尸项")
cols = ["类型", "名称", "证据", "路径", "判定", "处置建议"]
ws.append(cols)
style_header(ws)

ZOMBIE_NOTE = {
    "cpuz159": ("非幽灵", "微软电脑管家调用 CPU-Z 签名驱动做硬件检测，每次开机自动重建。保留。"),
    "Adobe": ("残留", "没有任何 Adobe 卸载记录 → Creative Cloud 卸载后剩下的空壳，可删（共 124 MB）。"),
    "EasyAntiCheat": ("现役", "游戏反作弊，现役游戏在用，保留。"),
    "EasyAntiCheat_EOS": ("现役", "Epic 版反作弊，10-25 还在更新，保留。"),
    "Interhaptics": ("残留", "Razer 触觉反馈组件 338 MB，自带 Uninstall.exe 但安装器没登记卸载项。不用可删。"),
    "Kingsoft": ("正常", "WPS 的 office6 组件目录，保留。"),
    "LightingService": ("正常", "ASUS Aura 灯效服务，LastProfile.xml 今天仍在更新，保留。"),
    "NVIDIA Corporation": ("部分可清", "主目录保留；Installer2 里 333 MB 旧安装包缓存，2023–2025 的旧条目可清。"),
    "Paradox Interactive": ("正常", "Paradox 启动器的实际程序目录，随启动器一起保留或删除。"),
    "SogouInput": ("正常", "搜狗输入法主目录（卸载记录名字对不上导致误报），保留。"),
    "Tencent": ("部分可清", "QQ 组件；Qzone 7.1 MB + QzoneMusic 15.3 MB 是 2024 年的旧组件，可删。"),
}
type_cn = {"service": "服务", "orphan-folder": "孤儿目录", "uninstall-entry": "卸载记录",
           "run-entry": "启动项", "startup-approval": "启动批准项", "app-path": "App Paths", "shortcut": "快捷方式"}
for z in zombies:
    verdict, note = ZOMBIE_NOTE.get(z["Name"], ("待确认", "需要人工确认。"))
    ws.append([type_cn.get(z["Type"], z["Type"]), z["Name"], z["Detail"], z["Path"], verdict, note])

for row in ws.iter_rows(min_row=2, max_row=ws.max_row, max_col=len(cols)):
    for cell in row:
        cell.font = BODY_FONT
        cell.border = BORDER
        cell.alignment = Alignment(vertical="center", wrap_text=cell.column in (3, 4, 6))
finish_sheet(ws, [12, 28, 46, 52, 12, 64], freeze="A2")

# ---------------- 按类别汇总 ----------------
ws = wb.create_sheet("分类汇总")
ws.append(["类别", "条目数", "已知总体积(MB)", "其中“可删”体积(MB)", "说明"])
style_header(ws)
agg = {}
for p in progs:
    cat = CAT_CN.get(cat_of(p), cat_of(p))
    a = agg.setdefault(cat, [0, 0.0, 0.0])
    a[0] += 1
    if p["SizeMB"] not in ("", "-1"):
        a[1] += float(p["SizeMB"])
    if advice_for(p["Name"], cat_of(p))[0] == "可删" and p["SizeMB"] not in ("", "-1"):
        a[2] += float(p["SizeMB"])
CAT_NOTE = {
    "运行库": "别动，删了别的软件会崩",
    "驱动/硬件组件": "主板灯效、声卡、芯片组，删了功能会异常",
    "系统组件": "系统自带，保留",
    "游戏/平台": "按需保留，体量最大的部分",
    "开发工具": "Python/.NET/TRAE 等",
    "应用软件": "浏览器、网盘、输入法等",
    "办公": "WPS 与 Office 插件",
    "工具": "更新修复、安全软件",
    "其他": "杂项，多数需要你判断",
}
for cat, (cnt, size, delsize) in sorted(agg.items(), key=lambda x: -x[1][1]):
    ws.append([cat, cnt, round(size, 1), round(delsize, 1), CAT_NOTE.get(cat, "")])

tot_cnt = sum(v[0] for v in agg.values())
tot_size = sum(v[1] for v in agg.values())
tot_del = sum(v[2] for v in agg.values())
ws.append(["合计", tot_cnt, round(tot_size, 1), round(tot_del, 1), "体积只统计注册表/目录能给出的部分"])

for row in ws.iter_rows(min_row=2, max_row=ws.max_row, max_col=5):
    for cell in row:
        cell.font = BODY_FONT
        cell.border = BORDER
    row[2].number_format = "#,##0.0"
    row[3].number_format = "#,##0.0"
last = ws.max_row
for cell in ws[last]:
    cell.font = Font(name="微软雅黑", size=10, bold=True)
    cell.fill = PatternFill("solid", fgColor="EDEDED")
finish_sheet(ws, [18, 10, 18, 20, 50], freeze="A2")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
wb.save(OUT)
print("saved", OUT, "sheets:", wb.sheetnames)
print("progs", len(progs), "junk", len(items), "zombies", len(zombies))
print("suggested-delete MB", round(sugg_del, 1), "safe junk MB", round(safe_junk, 1))
