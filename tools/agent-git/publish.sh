#!/usr/bin/env bash
# 显式文件列表和测试命令由 Agent 根据任务确定，禁止整仓暂存。
set -euo pipefail
if (( $# < 6 )) || [[ $5 != -- ]]; then
  echo '用法: publish.sh <仓库路径> <instinctlab|instinct_rl> <提交说明> <测试命令> -- <文件...>' >&2
  exit 2
fi
repo=$(cd "$1" && pwd)
name=$2
message=$3
check=$4
shift 5
case "$name" in instinctlab|instinct_rl) ;; *) echo '不允许的仓库' >&2; exit 2 ;; esac
cd "$repo"
[[ $(git rev-parse --show-toplevel) == "$repo" ]] || { echo '必须指定仓库根目录' >&2; exit 1; }
expected="https://github.com/cocokele1233/$name.git"
[[ $(git config --get-all remote.origin.url) == "$expected" ]] || { echo 'origin 不是已配置的个人 Fork' >&2; exit 1; }
pushurl=$(git config --get-all remote.origin.pushurl || true)
[[ -z $pushurl || $pushurl == "$expected" ]] || { echo 'origin 推送地址未启用或不属于个人 Fork' >&2; exit 1; }
[[ $(git remote get-url --push --all origin) == "$expected" ]] || { echo '实际推送地址被重写或包含多个地址' >&2; exit 1; }
branch=$(git symbolic-ref --short HEAD)
[[ $branch == agent/* ]] || { echo '请先建立 agent/ 任务分支' >&2; exit 1; }
[[ -z $(git diff --cached --name-only) ]] || { echo '索引已有暂存内容，请先审查；脚本不会清除它' >&2; exit 1; }
for path in "$@"; do
  [[ $path != /* && $path != :* && $path != . && $path != ../* && $path != */../* && $path != */.. && $path != .git && $path != .git/* && ! -d $path ]] || { echo "仅接受仓库内单文件路径: $path" >&2; exit 1; }
done
before=$(git rev-parse HEAD)
bash -e -o pipefail -c "$check"
[[ $(git rev-parse HEAD) == "$before" && -z $(git diff --cached --name-only) ]] || { echo '测试期间 HEAD 或索引改变，请审查' >&2; exit 1; }
[[ $(git remote get-url --push --all origin) == "$expected" ]] || { echo '实际推送地址被重写或包含多个地址' >&2; exit 1; }
[[ $(git symbolic-ref --short HEAD) == "$branch" ]] || { echo '测试改变了任务分支' >&2; exit 1; }
git diff --check -- "$@"
backup="backup/agent-$(date -u +%Y%m%dT%H%M%SZ)-$$"
git branch "$backup" "$before"
git --literal-pathspecs add -- "$@"
[[ -n $(git diff --cached --name-only) ]] || { echo '没有可提交的任务改动' >&2; exit 1; }
git diff --cached --check
git commit -m "$message"
[[ $(git remote get-url --push --all origin) == "$expected" ]] || { echo '实际推送地址被重写或包含多个地址' >&2; exit 1; }
git push --set-upstream origin "$branch"
printf '恢复点: %s\n' "$backup"
