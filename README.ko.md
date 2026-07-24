# tokenmaxxxer / qa-agent-rulebook

*[English](README.md)*

Claude Code 플러그인 마켓플레이스: 에이전트가
**QA 엔지니어처럼 동작하게** 만드는 스택입니다 — 실제 제품을 띄우고, 직접
돌려보고, 증거가 붙은 기록을 프로젝트가 이미 기록을 쌓는 곳(그 프로젝트의
이슈 트래커, 그 프로젝트의 템플릿과 라벨)에 남깁니다.

철학이 아니라 기능에서 출발했습니다: 각 플러그인은 실제 QA 사이클의 한
조각에 대응합니다 — v0.1은 **프로파일 → 실행 → 리포트**, 로드맵에 설계·회귀·
사인오프. 자매 레포
[coding-agent-rulebook](https://github.com/tokenmaxxxer/coding-agent-rulebook)
과 공유하는 것은 패키징(마켓플레이스 구조, 얇은 훅, kill switch, 정직한
벤치마크 표기)이지 테제가 아닙니다.

모든 것을 관통하는 두 규칙:

- **Verdict에는 실행이 필요하다.** pass/fail은 실제로 돌려본 동작에 대해서만
  주장하고, 모든 verdict는 증거를 인용한다 — 커맨드와 그 출력, 스크린샷,
  로그 발췌. 코드를 읽어서 나오는 것은 노트이지 verdict가 아니다.
- **고치지 말고 리포트한다.** QA 세션은 제품 코드를 절대 수정하지 않는다.
  발견은 이슈나 run record가 되고, 수정은 개발 세션의 몫이다.

## 플러그인

| 플러그인 | QA 기능 | 방식 |
|---|---|---|
| [intake](intake/) | 프로젝트별 프로파일: 이슈 repo, 이슈 템플릿, 라벨, 앱 기동법, 테스트 컨벤션, 리포트 언어 — `/qa-init`이 한 번 발견해서 커밋되는 `qa/intake.md`로 동결하고, 다른 모든 플러그인이 이 파일을 읽는다. `--check`는 환경 점검(닥터). | command + `SessionStart` |
| [testrun](testrun/) | 실행: `/testrun`이 프로파일대로 앱을 띄우고, 플랜(`qa/plan.md`)이 있으면 플랜대로, 없으면 주요 플로우 애드혹 스모크를 돌린 뒤, 케이스마다 verdict가 증거를 가리키는 run record를 남긴다. | command + 얇은 directive |
| [bugreport](bugreport/) | 리포트: `/bug`가 재현된 결함을 중복 검색 후 프로젝트의 트래커에 — 그 프로젝트의 템플릿, 라벨, 언어로 — 발행한다. 표준 양식은 템플릿 없는 프로젝트의 폴백. | command + 얇은 directive |
| [stats](stats/) | 신뢰 회계: `/qa-stats`가 `qa/runs/`에서 발행된 모든 이슈를 트래커 결과까지 추적해 acceptance rate, noise rate, DUP 전환, UNFILED 사유를 보고한다. 읽기 전용. | command |
| [qa-agent-env](qa-agent-env/) | 스택 전체 원-인스톨 번들. | dependencies |

로드맵(순서대로): **regress**(확정된 버그 → 프로젝트 자체 프레임워크의
자동화 회귀 테스트 — 버그 커밋에서 fail하고 수정 커밋에서 안정적으로 pass할
때만 채택, 스펙:
[docs/proposals/2026-07-24-regress-adoption-gate.md](docs/proposals/2026-07-24-regress-adoption-gate.md);
flaky 탐지, 회귀 시 `git bisect`), **testplan**(스펙 → 경계값/네거티브/
상태전이 케이스 + 추적성), **signoff**(플랜 대비 실행 요약 — 판단 재료이지
verdict가 아님; 결과 추적 절반은 `/qa-stats`가 이미 담당).

## QA→개발 루프

"고치지 말고 리포트한다"에는 후반전이 있습니다: **트래커가 인수인계
창구입니다.** 이 스택은 이슈를 발행하고, 자매
[coding-agent-rulebook](https://github.com/tokenmaxxxer/coding-agent-rulebook)의
dispatch 플러그인은 이슈를 `Closes` PR로 만듭니다. QA 세션은 고치지 않고,
개발 세션은 발행하지 않습니다 — 두 스택 사이의 인터페이스는 프로젝트의 이슈
트래커이고, 주고받은 양쪽 모두 git에 기록됩니다.

## `qa/` 디렉토리 계약

스택이 만드는 모든 것은 대상 프로젝트 안에 커밋되어 남습니다 — 세션이 죽어도
디스크에서 재개되고, 모든 사용자가 하나의 상태를 공유합니다:

```
qa/
  intake.md        # 프로파일 (env var는 이름만 — 시크릿 절대 금지)
  plan.md          # 선택적 테스트 플랜 (로드맵: /testplan이 작성)
  runs/            # 실행당 기록 하나: 케이스 표, 실패, 이슈 URL
  evidence/        # run record가 인용하는 스크린샷·출력·로그
```

## 설치

**레포 스코프 (1차 경로)** — 대상 프로젝트의 `.claude/settings.json`에 아래를
커밋합니다. 그 레포를 여는 모든 사용자에게 스택이 자동으로 깔리고(경계는
레포 접근 권한 + 폴더 trust), 한 번 커밋된 `/qa-init`
프로파일이 모든 세션을 같은 트래커에 같은 방식으로 발행하게 만듭니다:

```json
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer-qa": {
      "source": { "source": "github", "repo": "tokenmaxxxer/qa-agent-rulebook" }
    }
  },
  "enabledPlugins": {
    "qa-agent-env@tokenmaxxxer-qa": true
  }
}
```

마켓플레이스 레포가 프라이빗이면 각자 `gh auth setup-git`을 한 번 실행해야
백그라운드 마켓플레이스 업데이트가 인증됩니다. 헤드리스/CI 세션(`claude -p`,
`--bare` 제외)도 같은 레포 스코프 플러그인을 로드합니다 — 예약된 스모크
실행이 같은 규율로 이슈를 발행합니다.

**개인 (유저 스코프)** — 아무 Claude Code 세션에서:

```
/plugin marketplace add tokenmaxxxer/qa-agent-rulebook
/plugin install qa-agent-env@tokenmaxxxer-qa
```

## Kill switch

`QA_INTAKE_OFF=1`, `QA_TESTRUN_OFF=1`, `QA_BUGREPORT_OFF=1` — 각각 해당
플러그인의 훅을 세션에서 끕니다. `0/false/no/off`가 아닌 비어있지 않은 값만
off로 칩니다. stats는 훅이 없어 스위치도 없습니다 — 호출하지 않는 커맨드는
그 자체로 꺼져 있습니다.

## 레포 구성

- `.claude-plugin/marketplace.json` — 마켓플레이스 매니페스트.
- `intake/`, `testrun/`, `bugreport/`, `stats/`, `qa-agent-env/` —
  플러그인당 디렉토리 하나, 각자 README 보유.
- `bench/` — 씨딩 버그 평가 하니스: 타겟 앱, 숨겨진 정답 키, 스택을 측정하는
  on/off 프로토콜.
- `docs/design.md` — 설계 기록: 기능 중심 라인업, 3층 배포 모델, 로드맵.
  `docs/proposals/` — 구현에 앞서 동결한 스펙.

v0.1.0 기준 모든 플러그인은 벤치마크 전입니다 — 하우스 룰에 따라 그렇게
표기합니다. 그 표기를 떼는 장치가 `bench/`입니다.
