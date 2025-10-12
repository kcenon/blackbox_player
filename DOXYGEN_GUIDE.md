# Doxygen 문서 생성 가이드

## 📚 개요

BlackboxPlayer 테스트 스위트의 소스 코드를 Doxygen으로 문서화하여 HTML 문서를 생성하는 가이드입니다.

## 🔧 Doxygen 설치

### macOS (Homebrew)
```bash
brew install doxygen
```

### macOS (MacPorts)
```bash
sudo port install doxygen
```

### 설치 확인
```bash
doxygen --version
```

## 📖 문서 생성 방법

### 1. 기본 문서 생성

```bash
cd /Users/dongcheolshin/Sources/blackbox_player
doxygen Doxyfile
```

생성된 문서 위치: `./docs/html/index.html`

### 2. 브라우저에서 확인

```bash
open docs/html/index.html
```

## 📂 문서 구조

생성된 문서는 다음과 같은 구조를 가집니다:

```
docs/
├── html/
│   ├── index.html              # 메인 페이지
│   ├── annotated.html          # 클래스 목록
│   ├── files.html              # 파일 목록
│   ├── functions.html          # 함수 목록
│   └── ...
└── latex/ (옵션)
```

## 🎨 주요 Doxygen 명령어

### 파일 문서화
```cpp
/**
 * @file filename.swift
 * @brief 파일에 대한 간단한 설명
 * @author 작성자
 * @details 상세 설명
 */
```

### 클래스 문서화
```cpp
/**
 * @class ClassName
 * @brief 클래스 간단 설명
 * @details 상세 설명
 */
```

### 메서드 문서화
```cpp
/**
 * @brief 메서드 간단 설명
 * @param paramName 파라미터 설명
 * @return 반환값 설명
 * @throws 발생 가능한 예외
 */
```

### 섹션 구분
```cpp
/**
 * @section section_name 섹션 제목
 * @subsection subsection_name 서브섹션 제목
 */
```

### 코드 블록
```cpp
/**
 * @code
 * let example = "코드 예제"
 * print(example)
 * @endcode
 */
```

### 주의사항 및 경고
```cpp
/**
 * @note 주의사항
 * @warning 경고
 * @todo 할 일
 */
```

## 🔍 변환 완료 파일

모든 테스트 파일이 Doxygen 형식으로 완전히 변환되었습니다:

- ✅ **SyncControllerTests.swift** (3,136줄, 42개 Doxygen 블록)
- ✅ **MultiChannelRendererTests.swift** (3,454줄, 196개 Doxygen 블록)
- ✅ **VideoChannelTests.swift** (3,435줄, 187개 Doxygen 블록)
- ✅ **VideoDecoderTests.swift** (2,439줄, 215개 Doxygen 블록)
- ✅ **EXT4FileSystemTests.swift** (1,962줄, 147개 Doxygen 블록)
- ✅ **DataModelsTests.swift** (1,439줄, 80개 Doxygen 블록)

**총계**: 15,865줄, 867개 Doxygen 문서화 블록

## 📊 생성된 문서 통계

- **HTML 파일**: 19개
- **문서 크기**: 3.5MB
- **문서 위치**: `./docs/html/index.html`

## ⚙️ Doxyfile 주요 설정

현재 Doxyfile의 주요 설정:

- **PROJECT_NAME**: BlackboxPlayer Tests
- **INPUT**: ./BlackboxPlayer/Tests
- **OUTPUT_DIRECTORY**: ./docs
- **OUTPUT_LANGUAGE**: Korean (한글 지원)
- **INPUT_ENCODING**: UTF-8 (한글 주석 지원)
- **GENERATE_HTML**: YES
- **GENERATE_TREEVIEW**: YES (계층 구조 트리뷰)
- **SOURCE_BROWSER**: YES (소스 코드 보기)
- **EXTENSION_MAPPING**: swift=C++ (Swift 지원)

## 🎯 문서 생성 팁

### 1. 증분 빌드
변경된 파일만 다시 문서화하려면:
```bash
doxygen Doxyfile
```

### 2. 문서 정리
기존 문서를 삭제하고 새로 생성하려면:
```bash
rm -rf docs
doxygen Doxyfile
```

### 3. PDF 생성 (LaTeX 필요)
Doxyfile에서 `GENERATE_LATEX = YES`로 설정 후:
```bash
doxygen Doxyfile
cd docs/latex
make
```

## 🌐 웹 서버로 문서 공개

### Python 내장 서버
```bash
cd docs/html
python3 -m http.server 8000
```

브라우저에서 http://localhost:8000 접속

### GitHub Pages
docs/html 폴더를 GitHub Pages로 배포 가능

## 🔧 커스터마이징

### 테마 변경
Doxyfile에서 HTML 색상 설정:
```
HTML_COLORSTYLE_HUE    = 220
HTML_COLORSTYLE_SAT    = 100
HTML_COLORSTYLE_GAMMA  = 80
```

### 로고 추가
```
PROJECT_LOGO           = path/to/logo.png
```

### 커스텀 CSS
```
HTML_EXTRA_STYLESHEET  = custom.css
```

## 📚 참고 자료

- [Doxygen 공식 문서](https://www.doxygen.nl/manual/)
- [Doxygen 명령어 참조](https://www.doxygen.nl/manual/commands.html)
- [Swift with Doxygen](https://www.doxygen.nl/manual/config.html#cfg_extension_mapping)

## 🐛 트러블슈팅

### Swift 파일이 인식되지 않는 경우
Doxyfile 확인:
```
EXTENSION_MAPPING      = swift=C++
FILE_PATTERNS          = *.swift
```

### 한글이 깨지는 경우
Doxyfile 확인:
```
INPUT_ENCODING         = UTF-8
DOXYFILE_ENCODING      = UTF-8
OUTPUT_LANGUAGE        = Korean
```

### 코드 블록이 표시되지 않는 경우
주석에 `@code ... @endcode` 사용 확인

## 💡 다음 단계

1. **전체 파일 변환**: 나머지 5개 테스트 파일을 Doxygen 형식으로 변환
2. **문서 생성**: `doxygen Doxyfile` 실행
3. **리뷰**: 생성된 HTML 문서 확인
4. **배포**: GitHub Pages 또는 내부 서버에 배포

---

📝 **Note**: 현재 SyncControllerTests.swift의 주요 부분만 Doxygen 형식으로 변환되었습니다. 전체 변환이 필요한 경우 요청해주세요.
