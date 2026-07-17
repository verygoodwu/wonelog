# Wonelog Flutter 桌面客户端

这是 Wonelog 管理后台的 Flutter 桌面客户端雏形。它不是网页后台，而是 Windows 桌面应用工程，界面入口在 `lib/main.dart`。

当前实现先复用已有 Flask 后台能力：

- 默认连接 `http://127.0.0.1:5000`
- 读取个人信息、城市、友链、文章、版本
- 提供发布、同步、创建版本快照入口
- 后台未运行时，客户端会尝试自动拉起 `Wonelog管理后台.exe`

## 为什么先复用 Flask 后台

这样可以先把“客户端体验”做出来，不用一次性重写发布、SSH、图床、版本管理这些高风险逻辑。后续可以逐步把 Python 后端拆成独立 core，或者改写为 Dart/Go/Rust。

## 开发运行

```powershell
cd D:\openclaw\wonelog-admin\flutter_client
$env:Path='D:\dev\flutter\bin;' + $env:Path
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
flutter run -d windows
```

## Windows 构建

```powershell
flutter build windows
```

如果提示 Visual Studio toolchain 缺失，需要在 Visual Studio Installer 里安装“使用 C++ 的桌面开发”，并包含 MSVC、C++ CMake tools for Windows、Windows 10 SDK。

## 后台核心查找

客户端会先访问 `http://127.0.0.1:5000/api/health`。如果连接失败，会在当前目录、应用目录及上级目录中查找：

```text
Wonelog管理后台.exe
release\Wonelog管理后台.exe
core\Wonelog管理后台.exe
..\release\Wonelog管理后台.exe
..\core\Wonelog管理后台.exe
```

找到后会以独立进程启动，再重新连接本地 API。
