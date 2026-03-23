#!/bin/zsh
set -euo pipefail

PROJECT="whisper.swiftui.xcodeproj"
SCHEME="WhisperCppDemo"
CONFIGURATION="Release"
ARCHIVE_PATH="build/LocalTranslator.xcarchive"
EXPORT_PATH="build/ipa"
EXPORT_OPTIONS="exportOptions.free.plist"

if [[ ! -f "$PROJECT/project.pbxproj" ]]; then
  echo "❌ Cannot find $PROJECT in current directory: $PWD"
  exit 1
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "❌ Cannot find $EXPORT_OPTIONS."
  exit 1
fi

echo "🧹 Cleaning previous artifacts..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "📦 Archiving app..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "📤 Exporting IPA..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

IPA_FILE=$(find "$EXPORT_PATH" -maxdepth 1 -name "*.ipa" -print -quit || true)
if [[ -n "${IPA_FILE:-}" ]]; then
  echo "✅ IPA generated: $IPA_FILE"
else
  echo "⚠️ Export finished but no IPA found. Check Xcode signing logs."
fi

echo "ℹ️ Free Apple ID may still limit export/install to personal testing only."
