@echo off
REM ---------------------------------------------------------------------------
REM  轻记 Release 打包脚本
REM
REM  用法（双击直接跑，或在命令行调用）：
REM    build_release.bat                打 Release APK（全 ABI 单包）
REM    build_release.bat --clean        构建前先 flutter clean
REM                                     （改了启动图标 / Android 资源后建议带上）
REM    build_release.bat --split        按 ABI 分包，体积最小
REM                                     （真机一般只要 arm64-v8a 那个）
REM    build_release.bat --check        构建前先跑 flutter analyze，不过就不打包
REM    build_release.bat --appbundle    额外输出 AAB 上架包
REM    build_release.bat --no-pause     跑完不暂停（串联进其它脚本 / CI 用）
REM
REM  参数可组合，例如： build_release.bat --clean --split
REM
REM  成品默认复制到项目根目录：轻记-v1.0.0-release.apk
REM   （同名文件已存在时自动补时间戳后缀，不会覆盖历史产物）
REM
REM  ★ 为什么必须带 --no-tree-shake-icons：
REM    lib/theme/app_icons.dart 用 IconData(codePoint) 动态构造图标，
REM    release 的图标树摇扫不到这些码点，会把字体里的图标全裁掉，
REM    打出来的包界面上所有图标都会变成方块或空白。这个开关务必留着。
REM
REM  ★ 命名：优先从 pubspec.yaml 读版本号；读不到（例如环境禁用了
REM    PowerShell）就退回时间戳命名，不会因为缺版本号而中断打包。
REM ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
chcp 936 >nul 2>nul
title 轻记 Release 打包

REM 本机全局代理会劫持 flutter 工具的本地通信（flutter_tester / devtools 的
REM localhost WebSocket 走代理会握手失败），必须把本机地址排出代理
set "NO_PROXY=localhost,127.0.0.1"
set "no_proxy=localhost,127.0.0.1"

pushd "%~dp0.."
set "ROOT=%CD%"
set "APKDIR=build\app\outputs\flutter-apk"
set "OUTBASE=轻记"

echo.
echo ============================================================
echo   轻记 Release 打包
echo   项目根目录：%ROOT%
echo ============================================================
echo.

REM --------------------------- 参数解析 ---------------------------
set "DOCLEAN=0"
set "DOSPLIT=0"
set "DOCHECK=0"
set "DOAAB=0"
set "PAUSE=1"
for %%P in (%*) do (
    if /i "%%~P"=="--clean"     set "DOCLEAN=1"
    if /i "%%~P"=="--split"     set "DOSPLIT=1"
    if /i "%%~P"=="--check"     set "DOCHECK=1"
    if /i "%%~P"=="--appbundle" set "DOAAB=1"
    if /i "%%~P"=="--no-pause"  set "PAUSE=0"
    if /i "%%~P"=="--help"      goto :usage
    if /i "%%~P"=="-h"          goto :usage
)

REM --------------------------- 环境检查 ---------------------------
where flutter >nul 2>nul
if errorlevel 1 (
    echo [错误] 命令行里找不到 flutter。
    echo        请确认已安装 Flutter SDK，并把 flutter\bin 加进 PATH。
    goto :fail
)
echo [环境] flutter 已就绪

REM --------------------------- 版本号 / 时间戳 ---------------------------
REM %TIME% 小时位早于 10 点时会带前导空格，统一补成 0
set "T=%TIME: =0%"
set "STAMP=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%_%T:~0,2%%T:~3,2%"

set "VERFULL="
set "VER="
set "TMPVER=%TEMP%\lightly_version.txt"
if exist "%TMPVER%" del "%TMPVER%" >nul 2>nul
powershell -NoProfile -Command "$m=[regex]::Match((Get-Content -Raw '%ROOT%\pubspec.yaml'),'(?m)^version:\s*(\S+)'); if($m.Success){ $m.Groups[1].Value }" > "%TMPVER%" 2>nul
if exist "%TMPVER%" set /p VERFULL=<"%TMPVER%"
if exist "%TMPVER%" del "%TMPVER%" >nul 2>nul
if defined VERFULL (
    for /f "tokens=1 delims=+" %%N in ("!VERFULL!") do set "VER=%%N"
)
REM 校验：版本号必须形如 数字.数字…，否则说明解析出来带了脏字符
REM （文件名里混进控制字符会直接导致 copy 失败），退回时间戳命名
if defined VER (
    echo !VER!| findstr /r "^[0-9][0-9.]*[0-9]$" >nul
    if errorlevel 1 set "VER="
)
if defined VER (
    set "PREFIX=%OUTBASE%-v!VER!"
    echo [版本] pubspec 版本 !VERFULL!
) else (
    set "PREFIX=%OUTBASE%-!STAMP!"
    echo [版本] 没读到有效版本号，成品改用时间戳命名
)
echo.

REM --------------------------- 前置动作 ---------------------------
if "%DOCHECK%"=="1" (
    echo [前置] flutter analyze
    call flutter analyze
    if errorlevel 1 (
        echo.
        echo [错误] 静态分析没过，先修完再打包。
        goto :fail
    )
    echo        √ 无问题
    echo.
)

if "%DOCLEAN%"=="1" (
    echo [前置] flutter clean
    call flutter clean
    if errorlevel 1 goto :fail
    echo        √ 已清空
    echo.
)

REM --------------------------- 构建 APK ---------------------------
echo [构建] 正在打 Release 包，首次构建通常要几分钟，请稍候...
if "%DOSPLIT%"=="1" (
    call flutter build apk --release --no-tree-shake-icons --split-per-abi
) else (
    call flutter build apk --release --no-tree-shake-icons
)
if errorlevel 1 goto :fail

REM --------------------------- 收集产物 ---------------------------
echo.
echo [产物] 复制到项目根目录：
set "COUNT=0"
if "%DOSPLIT%"=="1" (
    call :emit "%APKDIR%\app-arm64-v8a-release.apk"   "%PREFIX%-arm64-v8a.apk"   "%PREFIX%-arm64-v8a-!STAMP!.apk"
    call :emit "%APKDIR%\app-armeabi-v7a-release.apk" "%PREFIX%-armeabi-v7a.apk" "%PREFIX%-armeabi-v7a-!STAMP!.apk"
    call :emit "%APKDIR%\app-x86_64-release.apk"      "%PREFIX%-x86_64.apk"      "%PREFIX%-x86_64-!STAMP!.apk"
) else (
    call :emit "%APKDIR%\app-release.apk" "%PREFIX%-release.apk" "%PREFIX%-release-!STAMP!.apk"
)

if "!COUNT!"=="0" (
    echo.
    echo [错误] 一个成品都没产出，请对照上面的构建日志排查。
    goto :fail
)

REM --------------------------- 可选 AAB ---------------------------
if "%DOAAB%"=="1" (
    echo.
    echo [构建] flutter build appbundle --release --no-tree-shake-icons
    call flutter build appbundle --release --no-tree-shake-icons
    if errorlevel 1 goto :fail
    set "AABSRC=build\app\outputs\bundle\release\app-release.aab"
    if exist "!AABSRC!" (
        set "AABNAME=%PREFIX%.aab"
        if exist "%ROOT%\!AABNAME!" set "AABNAME=%PREFIX%-!STAMP!.aab"
        copy /y "!AABSRC!" "%ROOT%\!AABNAME!" >nul
        echo        √ !AABNAME!
    )
)

echo.
echo ============================================================
echo   打包完成，成品在项目根目录
echo ============================================================
goto :end

REM --------------------------- 子过程 ---------------------------
:emit
set "SRC=%~1"
set "DST=%~2"
set "DST2=%~3"
if not exist "%SRC%" (
    echo        × 未找到：%SRC%
    goto :eof
)
if exist "%ROOT%\%DST%" set "DST=%DST2%"
copy /y "%SRC%" "%ROOT%\%DST%" >nul
if errorlevel 1 (
    echo        × 复制失败：%SRC%
    goto :eof
)
for %%F in ("%ROOT%\%DST%") do (
    set /a "MB=%%~zF/1048576"
    set /a "KB=%%~zF/1024"
)
if !MB! GEQ 1 (
    echo        √ %DST% ^(!MB! MB^)
) else (
    echo        √ %DST% ^(!KB! KB^)
)
set /a "COUNT+=1"
goto :eof

:usage
REM 打印帮助时不暂停，避免脚本被外部调用时卡在这里
set "PAUSE=0"
echo   用法： build_release.bat [选项]
echo.
echo     无选项        打 Release APK（全 ABI 单包）
echo     --clean       构建前先 flutter clean
echo     --split       按 ABI 分包，体积最小
echo     --check       构建前先跑 flutter analyze
echo     --appbundle   额外输出 AAB 上架包
echo     --no-pause    跑完不暂停
echo     --help        显示本帮助
echo.
echo   选项可组合，如： build_release.bat --clean --split
goto :end

:fail
echo.
echo [失败] 打包中断，按上面的提示处理后再跑一次。
popd
if "%PAUSE%"=="1" pause
exit /b 1

:end
popd
if "%PAUSE%"=="1" pause
exit /b 0
