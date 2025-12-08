#!/bin/bash

# 构建应用（不签名，保持权限）
echo "Building LivePreview..."
xcodebuild -project LivePreview.xcodeproj \
    -scheme LivePreview \
    -configuration Debug \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | grep "BUILD"

if [ $? -eq 0 ]; then
    echo "Build succeeded!"
    
    # 关闭旧应用
    pkill -x LivePreview
    sleep 2
    
    # 删除旧版本
    rm -rf /Applications/LivePreview.app
    
    # 复制新版本
    cp -R ~/Library/Developer/Xcode/DerivedData/LivePreview-*/Build/Products/Debug/LivePreview.app /Applications/
    
    # 启动应用
    open /Applications/LivePreview.app
    
    echo "LivePreview launched!"
else
    echo "Build failed!"
    exit 1
fi
