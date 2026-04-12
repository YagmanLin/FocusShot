# FocusShot 发布说明

这份说明对应当前工程：

- 项目：`/Users/wxc/Coding/FocusShot/FocusShot.xcodeproj`
- 打包脚本：`/Users/wxc/Coding/FocusShot/Scripts/package_release.sh`

## 1. 图标

我已经把一套可用的应用图标放进了：

- `/Users/wxc/Coding/FocusShot/FocusShot/Assets.xcassets/AppIcon.appiconset`

如果你想重新生成图标，可以运行：

```bash
swift -module-cache-path /tmp/focusshot_swift_cache /Users/wxc/Coding/FocusShot/Scripts/generate_app_icon.swift /Users/wxc/Coding/FocusShot/FocusShot/Assets.xcassets/AppIcon.appiconset
```

## 2. 给别人安装前需要的条件

要让别人双击安装时尽量少遇到系统拦截，你需要：

1. Apple Developer Program 账号
2. Xcode 里登录同一个 Apple ID
3. 一个可用的 `Developer ID Application` 证书
4. 一个 `notarytool` 的 keychain profile

如果只是本机调试，`Apple Development` 就够了。  
如果要发给别人安装，推荐走：

- `Developer ID` 签名
- `notarization` 公证
- `DMG` 分发

## 3. Xcode 里先确认的设置

在 `Target > Signing & Capabilities` 里确认：

1. `Team` 选你的开发者团队
2. `Signing` 为自动管理
3. `Hardened Runtime` 打开
4. `Bundle Identifier` 固定不变

建议先在 Xcode 里用 `Release` 配置跑通一次归档。

## 4. 配置 notarytool

第一次需要创建一个 profile，示例：

```bash
xcrun notarytool store-credentials "FocusShotNotary" \
  --apple-id "你的AppleID邮箱" \
  --team-id "你的TeamID" \
  --password "app专用密码"
```

保存成功后，后面脚本里把 `NOTARY_PROFILE` 设成这个名字即可。

## 5. 一键打包

在项目根目录执行：

```bash
cd /Users/wxc/Coding/FocusShot
chmod +x /Users/wxc/Coding/FocusShot/Scripts/package_release.sh
TEAM_ID="你的TeamID" NOTARY_PROFILE="FocusShotNotary" /Users/wxc/Coding/FocusShot/Scripts/package_release.sh
```

如果你暂时只想先导出不公证的安装包，可以先不传 `NOTARY_PROFILE`：

```bash
cd /Users/wxc/Coding/FocusShot
chmod +x /Users/wxc/Coding/FocusShot/Scripts/package_release.sh
TEAM_ID="你的TeamID" /Users/wxc/Coding/FocusShot/Scripts/package_release.sh
```

生成结果默认在：

- `dist/FocusShot.xcarchive`
- `dist/export/FocusShot.app`
- `dist/FocusShot.dmg`

## 6. 发给别人之后还需要用户自己授权的权限

这是截图软件的正常情况，无法替用户预授权：

1. 屏幕录制
2. 可能的辅助功能权限

所以第一次运行时，用户仍然需要在系统设置里点允许。

## 7. 建议的实际发布顺序

1. 先在你自己机器上用 `Release` 跑一次
2. 用脚本打出 `DMG`
3. 完成 notarization 和 staple
4. 自己双击测试一遍安装包
5. 再发给别人
