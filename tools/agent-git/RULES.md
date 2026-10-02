# Agent 版本管理约定

适用于 Codex、Claude 及读取项目规则的其他 Agent。用户明确要求优先。

1. 开始任务先检查当前分支、远端、工作区及暂存区。根工作区不是仓库，分别在 instinctlab 和 instinct_rl 中处理。
2. 当前用户已授权本工作流：任务完成后测试、提交并推送至 cocokele1233 的对应个人 Fork；不得推送 project-instinct，也不得 force push。未核验个人 Fork 时保持推送禁用。
3. 每个新任务在 agent/<任务标识> 分支上开发。已有改动不得自动提交或丢弃；存在其他人的未提交改动时先隔离任务或明确逐文件/逐块确认归属。一个文件内混有既有改动时，禁止直接提交整个文件。
4. 首次改动现有文件前，把原文件复制到工作区 .task-backups/<唯一任务标识>/，保留路径结构，并用 cmp 核对。备份留在本地，不能提交。修改 Git 配置也必须备份。新文件无需原内容备份。
5. 实现后先运行与改动匹配的真实检查。Python 运行前检查 conda env list 并按用户确认的环境执行，禁止裸 python。无法运行所需检查时不得假装测试通过或自动提交。
6. instinctlab 涉及源码、脚本、测试或相关验收时，按 AGENTS.md 更新三份会话记录，且先备份。记录实际结果，不改变其他研究结论。
7. 审查最终差异和明确文件清单，确认每个文件只包含本任务改动。索引必须为空；禁止 git add . 或 git add -A。
8. 使用仓库内 tools/agent-git/publish.sh：参数是仓库路径、仓库名、提交说明、真实验证命令、--、逐个任务文件。验证命令由任务确定，不能用 true 绕过实际检查。该工具执行验证、建立 backup/agent-* 恢复分支、只暂存指定文件、提交、推送 agent/ 分支。规则能否自动执行取决于 Agent 是否读取并遵守，工具并非后台自动监听服务。
9. 推送失败时保留提交和恢复点，报告原因；修复认证后只需 git push -u origin <当前任务分支>，不要重复提交。未推送的撤销也先检查后续用户修改；已推送错误优先 git revert <提交>，验证后推送，禁止自动 reset --hard。
10. origin 未启用时，需在根工作区运行 bash tools/agent-git/setup-forks.sh。该工具要求 gh 已登录 cocokele1233，验证两个 Fork 的上游及推送权限后再启用推送。

调用示例（文档配置修改）：

```bash
bash tools/agent-git/publish.sh "$PWD" instinctlab 'chore: update agent git rules' 'bash -n tools/agent-git/publish.sh && git diff --check' -- tools/agent-git/RULES.md
```

代码任务必须换成对应测试命令。root 的 setup-forks.sh 依赖完整工作区；仓库内 publish.sh 可独立运行。

## PR 与主分支保护

- 在个人 Fork 的任务分支提交并推送，通过测试后创建或更新个人仓库内的 PR。目标仓库必须显式指定 `cocokele1233/<仓库名>`，base 为 `main`，不得向上游创建 PR。
- 新任务优先从 `origin/main` 隔离开发。原工作区可能有未提交研究代码或与 main 分叉的历史，不得自动整体合并；只迁移明确归属本任务的差异。
- `main` 要求 PR、来自 GitHub Actions 的 `agent-git` 检查通过、分支与 main 保持最新、讨论已解决。管理员同样受限，禁止强推或删除 main。
- 个人项目不要求另一位审查者批准；创建 PR 后报告 CI 结果和 PR 链接，合并仍需用户明确授权。禁止用管理员绕过、伪造状态或修改保护来规避失败检查。
- 本 CI 仅验证版本管理工具。业务代码必须另外运行适合任务的本地/计算服务器测试并记录真实结果，不能以 agent-git 通过代替业务回归。
- 更新主分支代码时使用 PR；已推送的错误通过 revert 提交和回滚 PR处理，不自动关闭保护。

创建 PR 示例（先核对仓库、分支和正文文件）：

```bash
gh pr create --repo cocokele1233/InstinctLab --base main --head <任务分支> --title '<说明>' --body-file <正文文件>
```
