---
date: 2026-07-25
status: reports
files:
  - signoff/hooks/capture-verdict.sh
---

# `capture-verdict.sh` 가 origin 리모트 없는 레포에서 프롬프트를 차단한다

## 요약

`signoff/hooks/capture-verdict.sh` 는 스스로 "This hook never blocks" (7행) 라고
선언하지만, **origin 리모트가 없는 레포에서는 종료 코드 2로 죽어 `UserPromptSubmit`
을 차단한다.** 사용자의 프롬프트가 에이전트에 도달하지 않는다.

`bench` 를 처음 돌리다 발견했다. bench 프로토콜이 표적을 리모트 없이 복사하므로
**on 팔이 구조적으로 실행되지 않는다** — 3회 중 2회가 이렇게 죽었다.

## 재현

```bash
D=$(mktemp -d); git -C "$D" init -q
S=$(mktemp -d); mkdir -p "$S/projects"
cd "$D"     # 훅은 셸의 cwd 에서 git 을 부른다

echo '{"hook_event_name":"UserPromptSubmit","prompt":"/testrun:testrun","cwd":"'"$D"'"}' \
  | CLAUDE_PLUGIN_ROOT=<…>/signoff QA_WORKSPACE="$S" \
    bash <…>/signoff/hooks/capture-verdict.sh
echo $?      # → 2
```

실제 세션에서의 모습:

```
UserPromptSubmit operation blocked by hook:
[${CLAUDE_PLUGIN_ROOT}/hooks/capture-verdict.sh]: No stderr output

Original prompt: /testrun:testrun
```

`intake/hooks/session-start.sh` 는 같은 슬러그 계산을 하지만 `set -e` 가 없어
영향받지 않는다(실측 종료 0). 문제는 `capture-verdict.sh` 하나다.

## 원인 — 저자가 쓴 폴백이 도달 불가능하다

```bash
17: set -euo pipefail
…
42: slug=$(git remote get-url origin 2>/dev/null | sed -e … )
43: [ -n "$slug" ] || slug=$(basename "$PWD")
```

43행이 정확히 이 경우를 위한 폴백이다. 그런데 42행에서 스크립트가 이미 죽는다:

- 리모트가 없으면 `git remote get-url origin` 이 128로 종료한다.
  `2>/dev/null` 은 **stderr 만** 막고 종료 코드는 그대로다.
- `pipefail` 때문에 파이프라인 전체가 실패로 판정된다.
- `set -e` 가 그 대입문에서 스크립트를 끝낸다. 43행은 실행되지 않는다.

즉 **"리모트가 없으면 디렉터리 이름을 쓴다"는 의도가 코드에 적혀 있는데 한 번도
실행되지 않는다.** 스크립트의 다른 모든 이탈 경로는 `|| exit 0` 으로 정확히
가드돼 있어서, 이 한 줄만 예외다.

## 제안 수정

파이프라인을 `set -e` 에서 떼어낸다:

```bash
slug=$(git remote get-url origin 2>/dev/null | sed -e … || true)
```

이러면 43행의 폴백이 살아나고, 훅의 "never blocks" 계약이 지켜진다.

## 왜 이게 중요한가

1. **차단이 조용하다.** stderr 가 없어 사용자는 "왜 아무 일도 안 일어났는지"
   알 수 없다. 세션은 종료 코드 0으로 끝나므로 자동화에서는 성공으로 보인다.
2. **`bench` 의 on 팔이 성립하지 않는다.** bench README 는 표적 사본에 트래커가
   없는 것을 전제하고(`/bug` 가 `UNFILED(no tracker)` 로 떨어지도록), 그래서
   리모트도 없다. 그 전제가 이 훅과 충돌한다 — 룰북을 켠 팔만 죽으므로
   **ablation 이 룰북에 불리한 쪽으로 편향된다.**
3. **리모트 없는 레포는 정상 사례다.** 로컬 실험, 새 프로젝트, 사본. QA 룰북이
   그런 레포에서 쓸 수 없게 된다.

## 실측 기록

reps=3 배치에서 on 팔 3회 중 2회가 이 차단으로 산출물 0건이었다(`on-2`, `on-3`).
`on-1` 은 통과했는데, 같은 조건에서 훅을 직접 돌리면 3개 디렉터리 모두 종료 2가
나온다 — 세션 시작 시점의 플러그인 로드 타이밍 차이로 보이며, **비결정적이라는
점이 더 나쁘다.**

*러너와 로그: `tokenmaxxxer/muster` 의 `bench/run.py`.*
