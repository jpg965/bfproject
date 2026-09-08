#!/bin/bash
# OpenCodeMobile - Git 便捷推送脚本
# 用法:
#   ./scripts/push.sh                    # 提交所有变更并推送
#   ./scripts/push.sh "commit message"   # 指定 commit message
#   ./scripts/push.sh --pull             # 仅拉取远程更新
#   ./scripts/push.sh --status           # 查看状态

set -e

REPO_DIR="/workspace/OpenCodeMobile"
cd "$REPO_DIR" || exit 1

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

case "$1" in
  --pull)
    echo -e "${YELLOW}📥 拉取远程更新...${NC}"
    git pull origin main
    echo -e "${GREEN}✅ 拉取完成${NC}"
    ;;
  --status)
    echo -e "${YELLOW}📋 Git 状态:${NC}"
    git status
    echo ""
    git log --oneline -5
    ;;
  *)
    MESSAGE="${1:-auto: update files}"

    # 检查是否有变更
    if git diff --quiet && git diff --cached --quiet; then
      echo -e "${YELLOW}ℹ️  没有需要提交的变更${NC}"
      exit 0
    fi

    # 暂存
    echo -e "${YELLOW}📦 暂存变更...${NC}"
    git add -A

    # 提交
    echo -e "${YELLOW}💾 提交: $MESSAGE${NC}"
    git commit -m "$MESSAGE"

    # 推送
    echo -e "${YELLOW}🚀 推送到 origin/main...${NC}"
    git push origin main

    echo -e "${GREEN}✅ 推送成功!${NC}"
    echo -e "${GREEN}   仓库: https://github.com/jpg965/bfproject${NC}"
    ;;
esac
