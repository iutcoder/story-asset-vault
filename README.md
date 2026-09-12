# 스토리 에셋 볼트

스토리 제작에 사용하는 이미지 원본을 작품·캐릭터·번호 순서로 정리하고,
검수하기 쉬운 인덱스 ZIP으로 내보내는 로컬 Flutter 데스크톱 앱입니다.

현재 데이터는 프로토타입과 호환하지 않습니다. 정식판 전용 저장소에서 처음부터
새로 쌓는 것을 전제로 합니다.

## 주요 기능

- 여러 작품을 하나의 앱에서 독립적으로 관리
- 캐릭터와 NPC마다 `A`, `B`, `C` 형태의 추출 코드 부여
- 이미지 여러 장을 가져오고 `01`, `02`, `03` 순서 자동 부여
- 이미지 이름 수정과 드래그 순서 변경
- 배경·이벤트·연출 등 공용 에셋 관리
- 원본을 앱 보관소에 복사하여 백업 대상을 단일화
- 삭제한 원본 복사본을 앱 휴지통에 보존
- 프로젝트 전체를 `A/01.png` 형태의 ZIP으로 추출
- 등록 화면과 분리된 읽기 전용 갤러리
- PNG에 포함된 NovelAI 생성 정보 열람 및 프롬프트 복사
- NovelAI 4/4.5 계열 캐릭터 프롬프트를 최대 6개까지 분리 표시

이미지 편집, 프롬프트 버전 관리, Git/R2 연동과 플랫폼 URL 생성은 앱 범위에
포함하지 않습니다.

## 소스 구조

```text
lib/
├─ app/                         앱 구성과 테마
├─ core/
│  ├─ bootstrap/               의존성 생성
│  ├─ database/                SQLite 연결과 스키마
│  └─ storage/                 원본·휴지통 파일 처리
└─ features/
   ├─ projects/domain/         프로젝트 모델
   ├─ entities/domain/         캐릭터·NPC 모델
   ├─ assets/domain/           이미지 에셋 모델
   ├─ metadata/
   │  ├─ data/                PNG 청크 판독과 NovelAI 메타데이터 해석
   │  ├─ domain/              생성 정보 표시 모델
   │  └─ presentation/        원본·EXIF 상세 열람 창
   └─ vault/
      ├─ application/          UI 상태와 명령
      ├─ data/                 DB·파일 저장소 조합
      └─ presentation/         화면과 대화상자
```

화면은 `VaultController`에만 명령을 전달하며 SQL과 파일 시스템을 직접 사용하지
않습니다. DB 구조는 `VaultDatabase`, 실제 파일 배치는 `VaultFileStore`, 업무
규칙은 `VaultRepository`를 먼저 확인하면 됩니다.

## 실행

저장소에 플랫폼 폴더가 없다면 최초 한 번 생성합니다.

```shell
flutter create --platforms=macos,windows .
flutter pub get
flutter run -d macos
```

## DartDoc 문서 생성

공개 클래스와 유지보수 경계에는 한국어 DartDoc 주석을 사용합니다.

```shell
dart doc
open doc/api/index.html
```

## 데이터 위치

운영체제의 Application Support 경로 아래 `story_asset_vault`에 저장됩니다.

```text
story_asset_vault/
├─ vault.sqlite3
├─ originals/{project-uuid}/
└─ trash/
```

SQLite는 작품·캐릭터·에셋 관계를 색인하고, 이미지 자체는 파일로 보관합니다.
프로젝트나 에셋을 삭제하면 앱이 보관한 원본 복사본은 `trash`로 이동합니다.

## 추출 형식

```text
project-name.zip
├─ A/
│  ├─ 01.png
│  └─ 02.webp
├─ B/
│  └─ 01.jpg
├─ _공용/
│  └─ 배경/
└─ index.csv
```

현재는 원본 확장자를 유지합니다. WebP 재인코딩과 메타데이터 제거는 별도 변환
서비스로 추가할 예정이며, 원본 파일은 변환하지 않습니다.

## 열람 모드와 메타데이터

상단의 `에셋 열람` 탭은 등록·삭제·순서 변경 도구를 표시하지 않는 갤러리입니다.
이미지를 누르면 확대 가능한 원본과 Base Prompt, Character Prompt 1~6,
Negative Prompt, 주요 생성 설정을 확인할 수 있습니다. Peropix 전용 Slot Prompt는
표시하지 않습니다. 생성 정보는 데이터베이스에 복제하지 않고 원본 PNG를 열 때
읽으므로 원본이 보존되는 한 새 메타데이터 형식에도 파서를 확장할 수 있습니다.
상세창의 좌우 버튼 또는 키보드 `←`·`→`로 현재 캐릭터 안의 이전·다음 이미지를
이동할 수 있으며, 이 조작으로 다른 캐릭터로 넘어가지는 않습니다.

추출 버튼을 누르면 별도 폴더 선택창 없이 운영체제의 다운로드 폴더 아래
`StoryAssetVaultExports`에 ZIP을 생성합니다. macOS에서는 완료 후 Finder가 해당
파일을 표시합니다.
