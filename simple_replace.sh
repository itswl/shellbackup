#!/bin/bash

# 获取当前脚本所在目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# 设置源文件夹路径为脚本目录下的 source 文件夹
SOURCE_DIR="$SCRIPT_DIR/source"

# 生成带日期的目标文件夹名
DATE=$(date +%Y%m%d)
TARGET_DIR="$SCRIPT_DIR/source_$DATE"

# 原始值和替换值文件
ORIGINALS_FILE="$SCRIPT_DIR/originals.txt"
REPLACEMENTS_FILE="$SCRIPT_DIR/replacements.txt"

# 确保替换规则文件存在
if [ ! -f "$ORIGINALS_FILE" ] || [ ! -f "$REPLACEMENTS_FILE" ]; then
    echo "替换规则文件缺失：请检查 $ORIGINALS_FILE 和 $REPLACEMENTS_FILE"
    exit 1
fi

# 确保源文件夹存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "源文件夹不存在: $SOURCE_DIR"
    exit 1
fi

# 拷贝文件夹
echo "正在复制文件夹 $SOURCE_DIR 到 $TARGET_DIR..."
cp -r "$SOURCE_DIR" "$TARGET_DIR"

# 检查拷贝是否成功
if [ $? -eq 0 ]; then
    echo "文件夹复制成功。目标路径：$TARGET_DIR"
else
    echo "文件夹复制失败。"
    exit 1
fi


# 替换文件内容
echo "正在递归替换文件内容..."

# 直接使用 awk 处理每行替换
while IFS=$'\n' read -r line_old <&3 && IFS=$'\n' read -r line_new <&4; do
    if [ -n "$line_old" ] && [ -n "$line_new" ]; then
        echo "正在替换: $line_old -> $line_new"
        
        # 在整个目录中递归查找所有不是隐藏文件或目录的文件
        find "$TARGET_DIR" -type f -not -path "*/\.*" -not -name "*.jpg" -not -name "*.png" \
            -not -name "*.gif" -not -name "*.pdf" -not -name "*.zip" -not -name "*.tar" \
            -not -name "*.gz" -exec grep -l "$line_old" {} \; 2>/dev/null | while read -r file; do
            
            echo "  处理文件: $file"
            
            # 使用 awk 进行替换，更可靠地处理特殊字符
            awk -v old="$line_old" -v new="$line_new" '{
                gsub(old, new);
                print;
            }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        done
    fi
done 3<"$ORIGINALS_FILE" 4<"$REPLACEMENTS_FILE"

echo "替换完成。"

# 输出替换完成提示
echo "目标文件夹：$TARGET_DIR" 
