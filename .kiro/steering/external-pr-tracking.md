# 외부 저장소 PR 추적 프로세스

## 목적
제3의 저장소(terraform-resource 등)에 PR을 올릴 때 변경 내역과 PR URL을 기록하여 추적성을 확보

## 중요: 적용 범위
- 이 프로세스는 **외부 저장소**에만 적용
- **KiroKi 저장소 자체**의 PR에는 이 프로세스를 진행하지 않음
- KiroKi는 작업 기록과 컨텍스트를 관리하는 저장소이므로 별도 추적 불필요

## 기록 위치
`.kiro/pr-history/` 디렉토리에 저장

## 기록 형식
파일명: `YYYY-MM-DD-{repository-name}-{short-description}.md`

```markdown
# PR: {PR 제목}

- Repository: {owner}/{repo}
- PR URL: {GitHub PR URL}
- Created: {YYYY-MM-DD}
- Status: {open|merged|closed}

## 변경 목적
{왜 이 변경이 필요한지}

## Diff
\`\`\`diff
{git diff 내용}
\`\`\`
```

## 작업 프로세스
1. 외부 저장소에서 브랜치 생성 및 작업
2. 변경 사항 커밋
3. PR 생성 전 diff 저장: `git diff master > /tmp/changes.diff`
4. PR 생성: `gh pr create`
5. PR 기록 파일 생성 (위 형식 사용)
6. KiroKi 저장소에 기록 파일 커밋

## 예시
```bash
# terraform-resource에서 작업 후
cd /path/to/terraform-resource
git diff master > /tmp/changes.diff

# PR 생성
gh pr create --title "Add S3 bucket for new service" --body "..."

# 기록 파일 생성
cd /workspaces/KiroKi
mkdir -p .kiro/pr-history
# 기록 파일 작성 후
git add .kiro/pr-history/
git commit -m "Track PR: terraform-resource S3 bucket addition"
```

## 조회
```bash
# 모든 PR 기록 확인
ls -la .kiro/pr-history/

# 특정 저장소 PR 검색
grep -r "Repository: Buzzvil/terraform-resource" .kiro/pr-history/
```
