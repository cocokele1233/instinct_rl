#!/usr/bin/env bash
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/publish.sh
work=$(mktemp -d "$(dirname "$0")/test.XXXXXX")
trap 'rm -rf "$work"' EXIT
repo="$work/repo"
git init -q "$repo"
git -C "$repo" config user.name Test
git -C "$repo" config user.email test@example.com
printf 'base\n' > "$repo/task.txt"
git -C "$repo" add task.txt
git -C "$repo" commit -qm base
git -C "$repo" checkout -qb agent/test
printf 'changed\n' > "$repo/task.txt"
printf 'unrelated\n' > "$repo/unrelated.txt"
base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" remote add origin https://github.com/project-instinct/instinctlab.git
if bash "$script" "$repo" instinctlab 'test commit' true -- task.txt; then echo 'FAIL: upstream accepted'; exit 1; fi
[[ $(git -C "$repo" rev-parse HEAD) == "$base" ]]
git -C "$repo" remote set-url origin https://github.com/cocokele1233/instinctlab.git
if bash "$script" "$repo" instinctlab 'test commit' false -- task.txt; then echo 'FAIL: failing test committed'; exit 1; fi
[[ $(git -C "$repo" rev-parse HEAD) == "$base" ]]
[[ -z $(git -C "$repo" diff --cached --name-only) ]]
git -C "$repo" config remote.origin.pushurl disabled://push-blocked
if bash "$script" "$repo" instinctlab 'test commit' true -- task.txt; then echo 'FAIL: disabled push accepted'; exit 1; fi
[[ $(git -C "$repo" rev-parse HEAD) == "$base" ]]
git -C "$repo" config --unset remote.origin.pushurl
git -C "$repo" add unrelated.txt
if bash "$script" "$repo" instinctlab 'test commit' true -- task.txt; then echo 'FAIL: existing index accepted'; exit 1; fi
[[ $(git -C "$repo" diff --cached --name-only) == unrelated.txt ]]
git -C "$repo" restore --staged unrelated.txt
git init --bare -q "$work/remote.git"
git -C "$repo" config url."$(cd "$work/remote.git" && pwd)".insteadOf https://github.com/cocokele1233/instinctlab.git
if bash "$script" "$repo" instinctlab 'test commit' true -- task.txt; then echo 'FAIL: rewritten push accepted'; exit 1; fi
[[ $(git -C "$repo" rev-parse HEAD) == "$base" ]]
git -C "$repo" config --remove-section url."$(cd "$work/remote.git" && pwd)"
if bash "$script" "$repo" instinctlab 'test commit' 'false; echo misleading-success' -- task.txt; then echo 'FAIL: intermediate test failure accepted'; exit 1; fi
[[ $(git -C "$repo" rev-parse HEAD) == "$base" ]]
# 仅模拟网络传输边界，其余操作使用真实 Git；生产远端校验不放宽。
mkdir "$work/bin"
real_git=$(command -v git)
remote=$(cd "$work/remote.git" && pwd)
cat > "$work/bin/git" <<'SHIM'
#!/usr/bin/env bash
if [[ $1 == push ]]; then
  [[ $2 == --set-upstream && $3 == origin && $4 == agent/test ]] || exit 1
  exec "$AGENT_TEST_GIT" push --set-upstream "$AGENT_TEST_REMOTE" "$4"
fi
exec "$AGENT_TEST_GIT" "$@"
SHIM
chmod +x "$work/bin/git"
git -C "$repo" remote set-url origin https://github.com/cocokele1233/InstinctLab.git
AGENT_TEST_GIT="$real_git" AGENT_TEST_REMOTE="$remote" PATH="$(cd "$work/bin" && pwd):$PATH" bash "$script" "$repo" instinctlab 'test commit' true -- task.txt
[[ $(git -C "$repo" diff-tree --no-commit-id --name-only -r HEAD) == task.txt ]]
[[ -f "$repo/unrelated.txt" ]]
[[ $(git --git-dir="$work/remote.git" rev-parse refs/heads/agent/test) == $(git -C "$repo" rev-parse HEAD) ]]
echo 'PASS: upstream rejected; failing test left HEAD/index unchanged; explicit files committed and pushed; unrelated file preserved'
