#!/bin/bash
# auto_save.sh - 监控文件变化，自动 git add + commit + push
# 用法: bash auto_save.sh [工作目录]
# 依赖: fswatch, git

WORKDIR="${1:-$(cd "$(dirname "$0")" && pwd)}"
cd "$WORKDIR" || exit 1

echo "🔄 自动保存监控已启动: $WORKDIR"
echo "   监控文件: *.html, *.json, *.css, *.js, *.md"
echo "   按 Ctrl+C 停止"
echo ""

DEBOUNCE=3  # 秒，防止短时间内多次提交
LAST_COMMIT=0

commit_and_push() {
    local now
    now=$(date +%s)
    if (( now - LAST_COMMIT < DEBOUNCE )); then
        return
    fi
    LAST_COMMIT=$now

    # 检查是否有变化
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        return
    fi

    # 生成提交信息
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local changed
    changed=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null | head -10)
    local msg="auto-save: ${timestamp}"
    
    # 简短描述变化的文件
    local file_count
    file_count=$(echo "$changed" | grep -v '^$' | wc -l | tr -d ' ')
    if [ "$file_count" -le 3 ]; then
        msg="${msg} | ${changed}"
    else
        msg="${msg} | ${file_count} files changed"
    fi

    git add -A
    git commit -m "$msg" --no-gpg-sign 2>/dev/null
    
    # 推送（如果有远程仓库）
    if git remote get-url origin &>/dev/null; then
        git push origin HEAD 2>/dev/null && echo "✅ pushed: $msg" || echo "⚠️ push failed: $msg"
    else
        echo "📦 committed (no remote): $msg"
    fi
}

# 监控指定扩展名的文件变化
fswatch -r --event Updated --event Created --event Moved --event Removed \
    -e ".git/" \
    --ext "html" --ext "json" --ext "css" --ext "js" --ext "md" \
    "$WORKDIR" | while read -r _; do
    commit_and_push
done
