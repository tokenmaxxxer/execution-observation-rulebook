---
date: 2026-07-25
status: fixed
files:
  - signoff/hooks/capture-verdict.sh
  - signoff/hooks/tests/run-verdict-tests.sh
---

# `capture-verdict.sh` 가 조용히 죽는 다섯 지점

## 요약

`signoff/hooks/capture-verdict.sh` 는 스스로 "This hook never blocks" (7행) 라고
선언하지만, **다섯 가지 경로에서 그 계약을 어긴다.** 첫 판(2026-07-25)은 그중
하나만 지목했다. 나머지 넷은 회귀 테스트를 짜면서 드러났고, **그중 하나가 훅의
본업을 통째로 막고 있었다.**

병은 하나다. 스크립트가 `set -euo pipefail` (17행) 아래 도는데, 값을 뽑아내는
파이프라인 셋이 **"못 찾음"을 종료 1 로 알리는 `grep`/`git` 으로 시작한다.**
못 찾은 것은 실패가 아니라 부재인데, `pipefail` 이 그것을 파이프라인 실패로
승격시키고 `set -e` 가 스크립트를 끝낸다.

| # | 조건 | 증상 | 위치 |
|---|---|---|---|
| ① | `QA_WORKSPACE` 경로에 심볼릭 링크 | 아무것도 안 함 (토큰 0) | 29행 |
| ② | `origin` 리모트 없음 | **종료 2 — 프롬프트 차단** | 42행 |
| ③ | 프롬프트에 `item <id>` 없음 | 종료 1 | 74행 |
| ④ | 판정에 `priority` 단어가 없음 | **종료 1 + 토큰 미발행** | 153행 |
| ⑤ | (항상) | 매 발행마다 stderr 에 grep 에러 | 185행 |

**④ 가 가장 크다.** `item F-1 confirmed defect` 라는 정상 판정이 토큰을 만들지
못한다 — 153행에서 죽어 214행의 발행부에 도달하지 않는다. `priority` 를 같은
턴에 같이 써야만 살아남는다. 훅의 존재 이유가 안 돌고 있었다.

## 실측

수정 전후로 `signoff/hooks/tests/run-verdict-tests.sh` 를 돌린 결과다.

| 케이스 | 전 | 후 |
|---|---|---|
| `origin` 없음 | **종료 2** | 종료 0 |
| `item` 없는 프롬프트 | 종료 1 | 종료 0 |
| `item F-1 confirmed defect` | 종료 1, **토큰 0** | 종료 0, `F-1.token` |
| `item F-1 priority now` | 종료 0, `F-1.priority.token` | 동일 |
| 둘 다 한 턴에 | 종료 0, 토큰 2 | 동일 |
| `item F-9` (state.md 에 없음) | 종료 0, 토큰 0 | 동일 |
| 맨 동의 (`ok`) | 종료 1 | 종료 0, 토큰 0 |
| 심볼릭 링크 워크스페이스 | 종료 0, **토큰 0** | 종료 0, `F-1.token` |
| `QA_SIGNOFF_DISABLE=1` | 종료 0, 토큰 0 | 동일 |

**발행되면 안 되는 경우가 새로 발행되지는 않았다.** 게이트가 느슨해지지 않았다는
쪽이 이 표에서 더 중요하다.

## 원인

### ②③④ — 저자가 쓴 폴백이 도달 불가능하다

```bash
17: set -euo pipefail
…
42: slug=$(git remote get-url origin 2>/dev/null | sed -e … )
43: [ -n "$slug" ] || slug=$(basename "$PWD")
```

43행이 정확히 "리모트가 없을 때"를 위한 폴백이다. 그런데 42행에서 스크립트가 이미
죽는다. `2>/dev/null` 은 **stderr 만** 막고 종료 코드는 그대로다 — 리모트가 없으면
`git remote get-url origin` 은 128 로 끝난다.

74행(`item <id>` 추출)과 153행(`priority` 값 추출)도 같은 모양이다. 셋 다 값이
없으면 빈 문자열이 되는 것이 **정상 동작**이고, 실제로 바로 다음 줄들이 빈 값을
받아 처리하도록 쓰여 있다. 그 줄들에 도달하지 못할 뿐이다.

### ① — 논리 경로와 실경로를 서로 비교한다

```bash
29: ws="$(cd "$ws" 2>/dev/null && pwd)"           || exit 0   # 논리 경로
60: proj_dir_real="$(cd "$proj_dir" … && pwd -P)" || exit 0   # 실경로
61: case "$proj_dir_real" in "$ws"|"$ws"/*) ;; *) exit 0 ;; esac
```

봉쇄 검사 자체는 옳다 — 해석한 뒤에 검사한다. 그런데 한쪽만 해석했다.
`QA_WORKSPACE` 가 심볼릭 링크를 지나면 두 값은 영원히 안 맞고, 훅은 조용히
종료 0 한다. macOS 의 `/tmp`·`/var`, 그리고 `mktemp -d` 가 전부 여기 걸린다.

### ⑤ — `-m` 의 인자로 `iE` 가 들어간다

```bash
185: grep -miE 1 -E '(…)'      # → invalid argument, 매번 실패
```

`|| true` 로 감싸여 있어 조용히 폴백한다. 결과로 토큰의 `phrase:` 에 판정 문장
한 줄이 아니라 **프롬프트 전체**가 담기고, 190행의 자격증명 스캔도 프롬프트
전체를 훑는다. 스캔이 넓어지는 것은 안전한 방향이지만, 판정과 무관한 곳의 내부
URL 하나로 정상 판정의 발행이 거부될 수 있다.

## 수정

```diff
-29: ws="$(cd "$ws" 2>/dev/null && pwd)" || exit 0
+29: ws="$(cd "$ws" 2>/dev/null && pwd -P)" || exit 0

-42:  slug=$(git remote get-url origin 2>/dev/null | sed …)
+42:  slug=$(git remote get-url origin 2>/dev/null | sed … || true)

-74:  raw_item="$(echo "$prompt" | grep -ioE … | head -1 | sed -E …)"
+74:  raw_item="$(echo "$prompt" | grep -ioE … | head -1 | sed -E … || true)"

-153:   priority_value="$(echo "$prompt" | grep -ioE … | tail -1 | … | tr …)"
+153:   priority_value="$(echo "$prompt" | grep -ioE … | tail -1 | … | tr … || true)"

-185:   grep -miE 1 -E \
+185:   grep -m1 -iE \
```

`set -e` 를 걷어내는 쪽은 택하지 않았다. 그러면 셋이 한 번에 풀리지만 *진짜*
예상 못 한 실패까지 같이 침묵한다. `|| true` 는 **"여기서 못 찾는 것은 정상이다"**
를 각 지점에서 명시하는 것이라 더 정확하고, 34행이 이미 쓰고 있는 관용구다.

## 회귀 테스트

`signoff/hooks/tests/run-verdict-tests.sh` — 훅을 실제 서브프로세스로 띄우고,
관측한 종료 코드와 **남은 토큰 파일**로 단언한다. 소스 텍스트는 보지 않는다.
`qa-cycle/hooks/tests/run-gate-tests.sh` 와 같은 방식이다.

수정을 되돌리고 돌려서 **9건 중 5건이 실패하는 것을 확인했다.** ⑤ 는 다른 결함에
가려 안 보였으므로, ⑤ 만 따로 되돌려 stderr 단언이 잡는 것도 확인했다.

`jq`·`python3`·`git` 이 없으면 훅은 자기 의존성 검사에서 종료 0 한다. 그 상태로
돌리면 전 케이스가 **틀린 이유로 통과**하므로, 러너는 그때 검사를 하지 않고
종료 2 로 거부한다.

## 왜 이제껏 안 보였나

②③④ 는 전부 **부재 조건에서만** 터진다. 리모트가 있고, 프롬프트에 `item` 이
있고, `priority` 를 같이 쓰는 흐름 — 즉 손으로 시험하는 행복 경로 — 에서는
다섯 개 중 어느 것도 나타나지 않는다.

그리고 실패가 실패처럼 보이지 않는다. ① 과 ④ 는 종료 0 이거나 토큰이 없을 뿐이고,
② 는 stderr 가 비어 있어 세션 로그에 이유가 남지 않는다. `bench` 가 이것을
드러낸 것은 표적 사본에 리모트를 두지 않기 때문이고(`/bug` 가
`UNFILED(no tracker)` 로 떨어지도록), **룰북을 켠 팔만 죽으므로 ablation 이
룰북에 불리한 쪽으로 편향된다.** reps=3 배치에서 on 팔 3회 중 2회가 산출물
0건이었다.

*러너와 로그: `tokenmaxxxer/muster` 의 `bench/run.py`.*
