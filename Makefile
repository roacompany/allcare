# BabyCare — 개발/퍼블리싱/배포 파이프라인
# Usage: make [target]

SCHEME = BabyCare
DEST = 'platform=iOS Simulator,name=iPhone 17 Pro'
PROJECT = BabyCare.xcodeproj
ARCHIVE_PATH = build/BabyCare.xcarchive
EXPORT_PATH = build/export
API_KEY = 2LSXRAHPW7
API_ISSUER = b70eb6de-e25a-47a1-8021-28872df65d61
KEYCHAIN = ~/Library/Keychains/ci_new.keychain-db

# ═══════════════════════════════════════
# 3단계: 개발 (Development)
# ═══════════════════════════════════════

.PHONY: generate build test lint arch-test verify screenshots

## 프로젝트 재생성
generate:
	xcodegen generate

## 빌드
build: generate
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination $(DEST) -quiet

## 단위 테스트
test: generate
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination $(DEST) -only-testing:BabyCareTests -quiet

## 스크린샷 캡처
screenshots: generate
	mkdir -p /tmp/babycare_screenshots
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination $(DEST) -only-testing:BabyCareUITests/ScreenshotTests 2>&1 || true
	@echo "📸 스크린샷: /tmp/babycare_screenshots/"

## 디자인 토큰 검증
design-verify:
	cd /Users/roque/roa-design-system && npx tsx cli/index.ts verify babycare

## 디자인 토큰 동기화
design-sync:
	cd /Users/roque/roa-design-system && npx tsx cli/index.ts sync babycare

## SwiftLint (파일:라인:규칙 형식 출력)
lint:
	@bash scripts/harness_lint.sh

## 아키텍처 경계 검사 (Views→Services 직접 참조 탐지)
arch-test:
	@bash scripts/arch_test.sh

## 전체 검증 (빌드 + 린트 + 아키텍처 + 테스트 + 디자인)
verify: build lint arch-test test design-verify
	@echo ""
	@echo "━━━ ALL CHECKS PASSED ━━━━━━━━━━━━━━━━━━━━━━━━"

# ═══════════════════════════════════════
# 4단계: 퍼블리싱 (Publishing)
# ═══════════════════════════════════════

.PHONY: bump archive export upload

## 빌드 번호 자동 증가
bump:
	@CURRENT=$$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*: *"*\([0-9]*\)"*/\1/'); \
	NEXT=$$((CURRENT + 1)); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"$$CURRENT\"/CURRENT_PROJECT_VERSION: \"$$NEXT\"/g" project.yml; \
	echo "📦 빌드 번호: $$CURRENT → $$NEXT"

## Archive (Automatic signing — SPM 패키지와 호환)
archive: generate
	@security unlock-keychain -p "ci_password" $(KEYCHAIN)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-archivePath $(ARCHIVE_PATH) \
		-destination "generic/platform=iOS" \
		-allowProvisioningUpdates \
		-quiet
	@echo "📦 Archive 완료: $(ARCHIVE_PATH)"

## IPA Export
export: archive
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist ExportOptions_local.plist \
		-exportPath $(EXPORT_PATH) \
		-allowProvisioningUpdates \
		-quiet
	@echo "📦 Export 완료: $(EXPORT_PATH)"

## TestFlight Upload
upload: export
	xcrun altool --upload-app \
		-f $$(find $(EXPORT_PATH) -name '*.ipa' | head -1) \
		--apiKey $(API_KEY) \
		--apiIssuer $(API_ISSUER)
	@echo "✈️  TestFlight 업로드 완료"

# ═══════════════════════════════════════
# 5단계: 배포 (Deployment)
# ═══════════════════════════════════════

.PHONY: deploy

## 원커맨드 배포: 검증 → 버전범프 → Archive → Export → TestFlight 업로드
## sub-make로 호출하여 bump 후 generate가 다시 실행되도록 한다
## (단일 make 호출에서는 PHONY target도 한 번만 실행됨 → bump한 빌드 번호가 archive에 반영 안 됨)
deploy:
	$(MAKE) verify
	$(MAKE) bump
	$(MAKE) upload
	@echo "🚀 배포 완료!"

# ═══════════════════════════════════════
# 유틸리티
# ═══════════════════════════════════════

.PHONY: dead-code clean status help

## 미사용 코드 탐지
dead-code:
	@bash scripts/dead_code.sh

## 빌드 산출물 정리
clean:
	rm -rf build/ *.xcarchive
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) -quiet
	@echo "🧹 정리 완료"

## 현재 상태 표시
status:
	@echo "═══════════════════════════════"
	@echo "  BabyCare 프로젝트 상태"
	@echo "═══════════════════════════════"
	@VERSION=$$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*: *"*\([^"]*\)"*/\1/'); \
	BUILD=$$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*: *"*\([0-9]*\)"*/\1/'); \
	echo "  버전: v$$VERSION (빌드 $$BUILD)"
	@COMMITS=$$(git log --oneline $$(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD 2>/dev/null | wc -l | tr -d ' '); \
	echo "  미배포 커밋: $$COMMITS"
	@echo "  테스트: $$(xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination $(DEST) -only-testing:BabyCareTests -quiet 2>&1 | grep 'Executed' | tail -1 | sed 's/.*Executed //' | sed 's/ seconds.*/s/')"
	@echo "═══════════════════════════════"

## 도움말
help:
	@echo ""
	@echo "🍼 BabyCare Makefile"
	@echo ""
	@echo "개발:"
	@echo "  make build         빌드"
	@echo "  make lint          SwiftLint 검사"
	@echo "  make arch-test     아키텍처 경계 검사"
	@echo "  make test          단위 테스트"
	@echo "  make verify        전체 검증 (빌드+린트+아키텍처+테스트+디자인)"
	@echo "  make screenshots   스크린샷 캡처"
	@echo ""
	@echo "배포:"
	@echo "  make deploy        원커맨드 배포 (bump→archive→upload)"
	@echo "  make bump          빌드 번호 +1"
	@echo "  make status        현재 상태"
	@echo ""
	@echo "유틸:"
	@echo "  make dead-code     미사용 코드 탐지"
	@echo "  make clean         빌드 산출물 정리"
	@echo "  make design-verify 디자인 토큰 검증"
	@echo "  make design-sync   디자인 토큰 동기화"
	@echo ""
