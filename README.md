# 轻卷截图

面向 iOS 18 的原生滚动长截图应用。目标手机是 iPhone 16 Pro / iOS 18.7.8；当前为等待真机验收的 0.1.0 预览版。

## 两个安装包

|版本|流程|签名条件|
|---|---|---|
|Standard|系统确认开始采集，切换到其他 App 滚动，停止后返回自动拼接|必须保留 Broadcast 扩展，主程序/扩展都要具有一致且获描述文件授权的 App Group|
|Import|先用系统录屏，再从相册或文件导入，自动拼接|不包含扩展，不使用 App Groups|

CI 产生的 IPA 使用 ad-hoc 签名以保留包结构，**需要用有效证书重新签名才能安装到真实 iPhone**。它们不是 App Store 或 TestFlight 安装包。

使用全能签时，若当前描述文件不能提供 App Groups，请使用 Import 版。具体操作见 [中文签名与使用说明](docs/全能签安装.md)。

## 已实现

- ReplayKit 视频帧采样，最多 5 次分析/秒，使用小图进行重叠测量。
- 正反向位移累计、重复覆盖抑制、不可靠重叠分段、可恢复草稿。
- 原尺寸 JPEG 中间帧；导出 PNG 保持采集宽度，中间 JPEG 有压缩。
- 调整每帧的固定顶底栏，以及最终边界裁剪。
- 按 64 行条带导出，单张超过 60,000 行时分图。
- 相册/文件录屏导入、缩略分段预览、相册添加和文件分享。
- 所有图像处理在本机执行，不含账号、广告或远端处理服务。

## 当前限制

- 首版面向竖屏、向下匀速滚动。跳过整屏、过快滚动、大片动画或低纹理画面可能无法连续拼接，此时分别输出片段。
- 不能录制受系统保护的内容。录屏授权使用 iOS 系统界面。
- 默认顶底栏裁剪只是建议；可调为 0 后重新生成，原始采集帧仍保留。
- 未经目标真机计时前，不承诺 10 屏 5 秒的性能目标已经达到。
- 原始草稿保留在应用存储中，重新生成成功后清理旧结果；使用前留出足够空间。

## 本地构建（Mac）

依赖 Xcode 16.4 或支持 iOS 18 部署目标的后续版本、Swift、Python 3 和 XcodeGen。使用系统框架与系统 zlib，没有第三方运行时 SDK。

```bash
swift test
python3 -m unittest discover -s scripts -p test_verify_ipa.py -v
bash scripts/build.sh
bash scripts/simulator-smoke.sh
```

输出位于 `build/ScrollShot-standard-0.1.0.ipa`、`build/ScrollShot-import-0.1.0.ipa`。`APP_GROUP_ID` 可在构建前设置，必须与实际签名授权一致。

## 结构

- `Core/`：灰度匹配、连续覆盖计划、草稿、视频解码、PNG 条带导出。
- `App/`：SwiftUI 界面、相册选取/保存、系统分享。
- `Broadcast/`：ReplayKit Upload 扩展。
- `Tests/`：真实像素/文件/视频测试。
- `Tools/FixtureGenerator/`：仅供模拟器验收的合成草稿工具，不打入应用。
- `scripts/`：打包、负例校验和模拟器验收。

公开仓库只包含本次新实现，不包含作为分析参考的第三方 IPA、解包二进制、签名材料或用户图像。验收边界见 [真机清单](docs/真机验收.md)。
