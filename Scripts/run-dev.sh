#!/bin/zsh
# Builds Crest and runs it as an isolated development copy that never touches
# the installed Crest's session, credentials or website data.
#
#   Scripts/run-dev.sh             WebKit build, run with the persistent "dev" store
#   Scripts/run-dev.sh --chromium  Chromium build, from the published prebuilt engine
#   Scripts/run-dev.sh --fresh     run with a store that is forgotten on quit
#   Scripts/run-dev.sh --no-build  run the last build again
#   Scripts/run-dev.sh --reset     forget that copy's Spaces, tabs, imports and
#                                  sign-ins first (combine with --chromium)
#
# The WebKit copy is ad-hoc signed without entitlements, so iCloud sync, push
# and the shared keychain are unavailable; credentials stay in memory. Its
# import may still open another browser's Keychain item, after macOS asks.
# A new store starts as a first launch does, with one starter Space an import
# replaces, rather than the sample Work and Personal Spaces. The
# Chromium copy is Crest's isolated review host, signed with your own Apple
# Development or Developer ID identity (set CREST_DEV_SIGNING_IDENTITY to pick
# one). When the app quits, the copy is unregistered from Launch Services so
# macOS keeps handing links to the installed Crest.
set -euo pipefail

repository_root="${0:A:h:h}"
cd "$repository_root"

fresh=false
build=true
chromium=false
reset=false
for argument in "$@"; do
  case "$argument" in
    --fresh) fresh=true ;;
    --no-build) build=false ;;
    --chromium) chromium=true ;;
    --reset) reset=true ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) print -u2 "Unknown option: $argument"; exit 2 ;;
  esac
done

derived_data="$HOME/Library/Developer/Xcode/DerivedData/CrestDev"

# Forgets one development copy's store: its session under the installed
# app's Isolated folder, named by a hash of the store's name, and the
# preferences domain of that name. The installed Crest's own session and
# preferences are never touched. A WebKit Space's website data is keyed by
# the Space, so a fresh import's new Spaces start without it.
reset_store() {
  local name="$1"
  local hash="$(printf '%s' "$name" | shasum -a 256 | awk '{print $1}')"
  rm -rf "$HOME/Library/Application Support/Crest/ControlPlane/Isolated/$hash"
  defaults delete "com.ladvace.crestark.isolated.$name" >/dev/null 2>&1 || true
}

if $reset; then
  if pgrep -f "DerivedData/CrestDev/.*(Crest.app|Crest Chromium Dev.app)/Contents/MacOS/" >/dev/null; then
    print -u2 "Quit the running development copy of Crest first, then run with --reset again."
    exit 1
  fi
  if $chromium; then
    # The Chromium host keeps its named review store and its engine profiles,
    # with their cookies and extensions.
    reset_store chromium-native-ui-review
    rm -rf "$HOME/Library/Application Support/CrestDev/chromium"
  else
    reset_store dev
  fi
  print "Cleared the development copy's Spaces, tabs and imports."
fi
log="$derived_data/build.log"
export PATH="$HOME/.dotnet:$PATH" DOTNET_CLI_TELEMETRY_OPTOUT=1
mkdir -p "$derived_data"

# Runs xcodebuild for `scheme`, printing only the errors when it fails.
build_scheme() {
  local scheme="$1"; shift
  if ! xcodebuild build -project Crest.xcodeproj -scheme "$scheme" -configuration Debug \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data" "$@" >"$log" 2>&1; then
    grep -E "error:" "$log" | sort -u | head -40
    print -u2 "Build failed. Full log: $log"
    exit 1
  fi
}

if $build; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    print "Installing XcodeGen…"
    brew install xcodegen
  fi
  Scripts/control-plane/install-dotnet.sh
  if [[ ! -d Crest.xcodeproj || project.yml -nt Crest.xcodeproj/project.pbxproj ]]; then
    xcodegen generate --quiet
  fi
fi

if $chromium; then
  app="$derived_data/Chromium/Crest Chromium Dev.app"
  if $build; then
    # The engine is published once per engine revision; this branch's engine
    # sources name the one it needs.
    engine_tag="$(python3 Scripts/control-plane/chromium_engine.py tag)"
    engine_asset="$(python3 Scripts/control-plane/chromium_engine.py asset)"
    engine_root="$HOME/Library/Caches/CrestDev/$engine_tag"
    if [[ ! -d "$engine_root/Chromium.app" ]]; then
      print "Downloading the Chromium engine ($engine_tag)…"
      mkdir -p "$engine_root"
      release="https://github.com/pauljoda/Crest/releases/download/$engine_tag"
      if ! curl --fail --location --silent --show-error --output "$engine_root/$engine_asset" "$release/$engine_asset" \
        || ! curl --fail --location --silent --show-error --output "$engine_root/$engine_asset.sha256" "$release/$engine_asset.sha256"; then
        print -u2 "No Chromium engine is published for this branch's engine sources ($engine_tag)."
        exit 1
      fi
      (cd "$engine_root" && shasum -a 256 -c "$engine_asset.sha256")
      ditto -x -k "$engine_root/$engine_asset" "$engine_root"
      rm -f "$engine_root/$engine_asset"
    fi

    identity="${CREST_DEV_SIGNING_IDENTITY:-}"
    if [[ -z "$identity" ]]; then
      identity="$(security find-identity -v -p codesigning \
        | grep -E '"(Apple Development|Developer ID Application):' | head -1 | awk '{print $2}')"
    fi
    if [[ -z "$identity" ]]; then
      print -u2 "The Chromium host needs an Apple Development or Developer ID signing identity in your keychain."
      exit 1
    fi

    print "Building the core…"
    (cd CrestCore && dotnet publish src/CrestCore.Native -c Release -r osx-arm64 --nologo >"$log" 2>&1) \
      || { tail -20 "$log"; print -u2 "Core build failed. Full log: $log"; exit 1; }
    core="$repository_root/CrestCore/src/CrestCore.Native/bin/Release/net10.0/osx-arm64/publish/CrestCore.Native.dylib"

    print "Building Crest for Chromium…"
    build_scheme CrestChromiumUI CODE_SIGNING_ALLOWED=NO

    print "Packaging…"
    rm -rf "$app"
    mkdir -p "${app:h}"
    python3 Scripts/control-plane/package-chromium-host.py \
      --browser "$engine_root/Chromium.app" \
      --ui "$derived_data/Build/Products/Debug/CrestChromiumUI.framework" \
      --core "$core" \
      --signing-identity "$identity" \
      --output "$app" >"$log" 2>&1 \
      || { tail -20 "$log"; print -u2 "Packaging failed. Full log: $log"; exit 1; }
  fi
else
  app="$derived_data/Build/Products/Debug/Crest.app"
  if $build; then
    print "Building Crest…"
    build_scheme Crest CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=
  fi
fi

if [[ ! -d "$app" ]]; then
  print -u2 "No build at $app. Run without --no-build first."
  exit 1
fi

lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
trap '"$lsregister" -u "$app" >/dev/null 2>&1 || true' EXIT INT TERM HUP

executable="$app/Contents/MacOS/$(defaults read "$app/Contents/Info" CFBundleExecutable)"
if $chromium; then
  # The review host keeps its own isolated store; the profile directory is
  # the engine's, kept between runs unless --fresh.
  profile="$HOME/Library/Application Support/CrestDev/chromium"
  if $fresh; then
    profile="$(mktemp -d "${TMPDIR:-/tmp}/crest-chromium-dev.XXXXXX")"
  fi
  mkdir -p "$profile"
  # As in the WebKit copy, its import may open another browser's Keychain
  # item, after the macOS prompt, even when a setup flag isolates it.
  export CREST_ALLOW_IMPORT_KEYCHAIN=1 CREST_FIRST_LAUNCH_SESSION=1
  print "Running Crest with Chromium (isolated review host). Quit the app or press Control-C to stop."
  "$executable" --crest-control-plane --user-data-dir="$profile"
else
  # The copy may open another browser's Keychain item, after the macOS
  # prompt, so its import can bring passwords and sign-ins.
  export CREST_ISOLATED_SESSION=1 CREST_USE_IN_MEMORY_CREDENTIALS=1 CREST_ALLOW_IMPORT_KEYCHAIN=1 \
    CREST_FIRST_LAUNCH_SESSION=1
  if $fresh; then
    unset CREST_ISOLATED_PERSISTENCE_ID
  else
    export CREST_ISOLATED_PERSISTENCE_ID=dev
  fi
  print "Running Crest (isolated${CREST_ISOLATED_PERSISTENCE_ID:+, store \"dev\"}). Quit the app or press Control-C to stop."
  "$executable"
fi
