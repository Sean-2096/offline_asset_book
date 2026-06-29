# offline_asset_book

离线资产账本 Flutter 应用。

## 开发

VS Code 已配置 Flutter debug 启动项和保存时热重载：

- `offline_asset_book: Chrome (hot reload)`
- `offline_asset_book: macOS (hot reload)`

也可以直接用命令启动：

```sh
flutter run -d chrome
```

启动后修改 `lib/` 下的 Dart 文件并保存，Flutter 会执行 hot reload；终端里也可以按 `r` 手动热重载，按 `R` 热重启。

也可以使用启动脚本固定端口启动 Web Server：

```sh
./start_web.sh
```

默认访问地址是 `http://127.0.0.1:8090`。CLI 模式下修改文件后，在运行脚本的终端按 `r` 触发 hot reload。

脚本每次启动前会先检查端口是否被占用；如果端口已被占用，会打印占用进程并强制结束后继续启动。

常用参数：

```sh
./start_web.sh --port 8091
./start_web.sh --chrome
```
