# WelcomeToJPG

macOS에서 여러 이미지 파일을 한 번에 JPG로 변환해 지정한 폴더에 저장하는 SwiftUI 데스크탑 앱입니다.

## Features

- `HEIC`, `PNG`, `JPEG` 등 디코딩 가능한 이미지 파일 다중 선택
- 드래그앤드롭 또는 파일 선택으로 입력 추가
- 선택한 이미지 썸네일 미리보기
- 출력 폴더 선택 후 일괄 JPG 변환
- JPG 품질 슬라이더 (`30%` ~ `100%`, 기본 `75%`)
- 동일 파일명 충돌 시 `-1`, `-2` suffix 자동 부여
- 투명 배경 이미지는 흰 배경으로 평탄화 후 JPG 저장
- 파일별 성공/실패 상태와 원본/결과 용량 표시

## Open In Xcode

1. 전체 Xcode가 설치된 Mac에서 이 폴더를 엽니다.
2. `Package.swift`를 Xcode에서 열면 앱 타깃이 로드됩니다.
3. `WelcomeToJPGApp` 스킴을 선택해서 실행합니다.

## Command Line Build

```bash
swift build --product WelcomeToJPGApp
```

샌드박스 환경에서는 SwiftPM manifest 실행이 막힐 수 있으므로, 일반 터미널이나 Xcode에서 여는 편이 더 안정적입니다.
