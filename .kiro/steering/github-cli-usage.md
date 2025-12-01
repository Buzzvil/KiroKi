# GitHub CLI 사용법

## 인증
```bash
gh auth login
gh auth status
```

## 저장소 관리
```bash
gh repo create <name>
gh repo clone <owner>/<repo>
gh repo view
gh repo fork
```

## 이슈 관리
```bash
gh issue list
gh issue create
gh issue view <number>
gh issue close <number>
```

## PR 관리
```bash
gh pr list
gh pr create
gh pr view <number>
gh pr checkout <number>
gh pr merge <number>
```

## 워크플로우
```bash
gh workflow list
gh workflow run <name>
gh run list
gh run view <id>
```
