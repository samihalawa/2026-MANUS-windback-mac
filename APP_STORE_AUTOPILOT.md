# UNIVERSAL APP STORE AUTOPILOT v3.0

> **Autonomous deployment system for shipping apps to Apple App Store & Google Play**

---

## CREDENTIALS CONFIGURATION

```bash
# Load credentials from .env (NEVER hardcode secrets)
source .env

# Verify credentials exist before proceeding
[[ -z "$APPLE_TEAM_ID" ]] && echo "ERROR: APPLE_TEAM_ID not set" && exit 1
[[ -z "$GOOGLE_PLAY_SERVICE_ACCOUNT" ]] && echo "ERROR: GOOGLE_PLAY_SERVICE_ACCOUNT not set" && exit 1
```

**Required Environment Variables** (see `.env.example`):
| Variable | Description |
|----------|-------------|
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_KEY_ID` | App Store Connect API Key ID |
| `APPLE_ISSUER_ID` | App Store Connect Issuer UUID |
| `APPLE_KEY_PATH` | Path to AuthKey_*.p8 file |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Service account email |
| `GOOGLE_PLAY_KEY_PATH` | Path to service account JSON |

---

## CORE PRINCIPLES

| Principle | Rule |
|-----------|------|
| **Truth** | Verify every file/key exists before use |
| **Constraint** | User limits are law (no SaaS = local only) |
| **Resilience** | stderr → hypothesize → fix → retry (3x max) |
| **No Placeholders** | Real IDs, real URLs, real configs only |
| **Silent Execution** | No confirmations, just artifacts |
| **Docs First** | Check official docs before assuming API shapes |

---

## 140 PROJECT STATES (AUTO-DETECT & HANDLE)

### FRAMEWORK DETECTION (1-20)
| ID | Framework |
|----|-----------|
| 1 | react | 2 | react-native | 3 | expo | 4 | next.js | 5 | nuxt |
| 6 | vue | 7 | angular | 8 | svelte | 9 | sveltekit | 10 | flutter |
| 11 | ionic | 12 | capacitor | 13 | cordova | 14 | tauri | 15 | electron |
| 16 | astro | 17 | remix | 18 | gatsby | 19 | vite-vanilla | 20 | static-html |

### BUILD STATE (21-40)
| ID | State |
|----|-------|
| 21 | no-build-yet | 22 | dev-only | 23 | broken-build | 24 | dist-exists |
| 25 | out-exists | 26 | build-exists | 27 | .next-exists | 28 | .nuxt-exists |
| 29 | www-exists | 30 | public-exists | 31 | missing-deps | 32 | wrong-node |
| 33 | missing-env | 34 | typescript-errors | 35 | eslint-errors | 36 | test-failures |
| 37 | outdated-deps | 38 | lockfile-conflict | 39 | monorepo | 40 | workspace |

### PWA STATE (41-60)
| ID | State |
|----|-------|
| 41 | no-manifest | 42 | partial-manifest | 43 | valid-manifest | 44 | no-sw |
| 45 | workbox-sw | 46 | custom-sw | 47 | no-icons | 48 | partial-icons |
| 49 | full-icons | 50 | no-maskable | 51 | has-maskable | 52 | wrong-start-url |
| 53 | http-not-https | 54 | no-offline | 55 | partial-offline | 56 | full-offline |
| 57 | no-theme-color | 58 | no-splash | 59 | lighthouse-fail | 60 | lighthouse-pass |

### ANDROID STATE (61-80)
| ID | State |
|----|-------|
| 61 | no-android | 62 | capacitor-android | 63 | cordova-android | 64 | expo-android |
| 65 | rn-android | 66 | flutter-android | 67 | twa-ready | 68 | bubblewrap-init |
| 69 | gradle-broken | 70 | no-keystore | 71 | has-keystore | 72 | debug-keystore |
| 73 | release-keystore | 74 | no-bundle-id | 75 | wrong-bundle-id | 76 | no-version |
| 77 | aab-exists | 78 | apk-exists | 79 | no-assetlinks | 80 | assetlinks-deployed |

### iOS STATE (81-100)
| ID | State |
|----|-------|
| 81 | no-ios | 82 | capacitor-ios | 83 | cordova-ios | 84 | expo-ios |
| 85 | rn-ios | 86 | flutter-ios | 87 | xcode-project | 88 | no-pods |
| 89 | pods-installed | 90 | signing-broken | 91 | no-provisioning | 92 | dev-provisioning |
| 93 | dist-provisioning | 94 | no-team-id | 95 | wrong-team-id | 96 | no-bundle-id |
| 97 | ipa-exists | 98 | xcarchive-exists | 99 | testflight-uploaded | 100 | appstore-uploaded |

### STORE STATE (101-120)
| ID | State |
|----|-------|
| 101 | no-play-app | 102 | play-draft | 103 | play-internal | 104 | play-alpha |
| 105 | play-beta | 106 | play-production | 107 | play-rejected | 108 | no-appstore-app |
| 109 | appstore-draft | 110 | appstore-testflight | 111 | appstore-review | 112 | appstore-rejected |
| 113 | appstore-live | 114 | no-metadata | 115 | partial-metadata | 116 | full-metadata |
| 117 | no-screenshots | 118 | partial-screenshots | 119 | full-screenshots | 120 | no-privacy-policy |

### ENV STATE (121-140)
| ID | State |
|----|-------|
| 121 | no-env | 122 | env-local | 123 | env-dev | 124 | env-prod |
| 125 | missing-api-keys | 126 | localhost-urls | 127 | debug-flags | 128 | console-logs |
| 129 | source-maps-exposed | 130 | secrets-in-repo | 131 | no-gitignore | 132 | ci-cd-exists |
| 133 | github-actions | 134 | vercel-config | 135 | netlify-config | 136 | docker-exists |
| 137 | no-readme | 138 | no-license | 139 | git-dirty | 140 | git-clean |

---

## EXECUTION FLOW

```
┌─────────────────────────────────────────────────────────────┐
│                     1. SCAN & DETECT                        │
├─────────────────────────────────────────────────────────────┤
│  • ls -la, cat package.json, find configs                   │
│  • Detect framework from deps/files                         │
│  • Map to state matrix (140 states)                         │
│  • Output: DETECTED: {framework} | STATES: [x,y,z]          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   2. FIX BLOCKERS                           │
├─────────────────────────────────────────────────────────────┤
│  • No manifest → generate manifest.json                     │
│  • No icons → generate from name/colors                     │
│  • No SW → add workbox service worker                       │
│  • localhost → replace with prod URLs                       │
│  • No bundle ID → generate com.{domain}.{app}               │
│  • No keystore → keytool generate                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      3. BUILD                               │
├─────────────────────────────────────────────────────────────┤
│  • npm run build (or detected command)                      │
│  • Verify dist/build/out exists                             │
│  • If fail: read error → fix → retry (3x)                   │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│      4. ANDROID         │   │        5. iOS           │
├─────────────────────────┤   ├─────────────────────────┤
│ • TWA (bubblewrap) for  │   │ • Capacitor add ios     │
│   PWA preferred         │   │ • pod install           │
│ • Capacitor if native   │   │ • fastlane match        │
│ • Generate keystore     │   │ • fastlane gym → .ipa   │
│ • bubblewrap build      │   │ • fastlane deliver      │
│ • Extract SHA256        │   │ • → App Store Connect   │
│ • fastlane supply       │   └─────────────────────────┘
│ • → Play Console        │
└─────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   6. VERIFY & OUTPUT                        │
├─────────────────────────────────────────────────────────────┤
│  • SHA256 checksums                                         │
│  • TestFlight URL (if iOS)                                  │
│  • Play Console URL (if Android)                            │
│  • All artifacts listed                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## STANDARD OUTPUT FORMAT

```
══════════════════════════════════════════════════════════════
DETECTED: {framework} v{version}
STATES: [{comma-separated state numbers}]
══════════════════════════════════════════════════════════════

BLOCKERS FIXED: {count}
├─ {blocker} → {fix applied}
└─ ...

BUILD: ✓ {dist_path} ({size})

ANDROID:
├─ AAB: ./release/app.aab (sha256:{hash})
├─ Keystore: ./release.keystore
├─ AssetLinks: deployed to /.well-known/
├─ Play Console: https://play.google.com/console/...
└─ Track: internal | Status: uploaded

iOS:
├─ IPA: ./App.ipa (sha256:{hash})
├─ Provisioning: Distribution
├─ App Store Connect: uploaded
├─ TestFlight: https://testflight.apple.com/join/{code}
└─ Status: processing | ready_for_review

METADATA:
├─ Title: {app_name}
├─ Bundle: {bundle_id}
├─ Version: {version}
└─ Privacy: {policy_url}
══════════════════════════════════════════════════════════════
```

---

## API AUTHENTICATION COMMANDS

### Google Play JWT Generation
```bash
#!/bin/bash
# Generate JWT for Google Play Developer API

NOW=$(date +%s)
EXP=$((NOW + 3600))

# Read private key from file
GOOGLE_KEY=$(cat "$GOOGLE_PLAY_KEY_PATH")

JWT=$(node -e "
const jwt = require('jsonwebtoken');
const key = process.env.GOOGLE_KEY;
console.log(jwt.sign({
  iss: process.env.GOOGLE_PLAY_SERVICE_ACCOUNT,
  scope: 'https://www.googleapis.com/auth/androidpublisher',
  aud: 'https://oauth2.googleapis.com/token',
  exp: $EXP,
  iat: $NOW
}, key, { algorithm: 'RS256' }));
")

# Exchange JWT for access token
TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$JWT" \
  | jq -r .access_token)

echo "Access Token: $TOKEN"
```

### Apple App Store Connect JWT Generation
```bash
#!/bin/bash
# Generate JWT for App Store Connect API

# Read private key from file
APPLE_KEY=$(cat "$APPLE_KEY_PATH")

APPLE_JWT=$(node -e "
const jwt = require('jsonwebtoken');
const key = process.env.APPLE_KEY;
console.log(jwt.sign({
  iss: process.env.APPLE_ISSUER_ID,
  iat: Math.floor(Date.now() / 1000),
  exp: Math.floor(Date.now() / 1000) + 1200,
  aud: 'appstoreconnect-v1'
}, key, {
  algorithm: 'ES256',
  header: { kid: process.env.APPLE_KEY_ID }
}));
")

echo "Apple JWT: $APPLE_JWT"

# Example API call
curl -H "Authorization: Bearer $APPLE_JWT" \
  https://api.appstoreconnect.apple.com/v1/apps
```

---

## COMMON BLOCKERS & SOLUTIONS

| Blocker | Solution |
|---------|----------|
| No Mac available | GitHub Actions `macos-latest` or EAS Build |
| No Play credentials | Upload to internal track manually via console |
| No Apple credentials | Use PWABuilder.com export as fallback |
| Build failure | `npm ci && npm run build` (clean install) |
| Gradle failure | `./gradlew clean && ./gradlew bundleRelease` |
| Pod failure | `pod deintegrate && pod install` |
| Signing failure | `fastlane match nuke distribution && fastlane match` |
| Missing icons | Generate with `pwa-asset-generator` |
| No service worker | Add `workbox-webpack-plugin` or `vite-plugin-pwa` |

---

## FRAMEWORK-SPECIFIC COMMANDS

### React / Vite / Next.js (Web → PWA → Mobile)
```bash
# Install dependencies
npm ci

# Build for production
npm run build

# Add PWA support (if missing)
npm install vite-plugin-pwa workbox-precaching

# Generate icons
npx pwa-asset-generator ./logo.png ./public/icons --index ./index.html --manifest ./public/manifest.json

# Wrap as TWA for Android
npx @anthropic/bubblewrap init --manifest https://your-domain.com/manifest.json
npx @anthropic/bubblewrap build
```

### React Native / Expo
```bash
# Install dependencies
npm ci

# Build Android AAB
eas build --platform android --profile production

# Build iOS IPA
eas build --platform ios --profile production

# Submit to stores
eas submit --platform android
eas submit --platform ios
```

### Capacitor (Any Web → Native)
```bash
# Add platforms
npx cap add android
npx cap add ios

# Sync web build
npx cap sync

# Open in native IDEs
npx cap open android
npx cap open ios
```

### Flutter
```bash
# Get dependencies
flutter pub get

# Build Android AAB
flutter build appbundle --release

# Build iOS
flutter build ios --release

# Archive and export
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -archivePath build/Runner.xcarchive archive
xcodebuild -exportArchive -archivePath build/Runner.xcarchive -exportPath build/ipa -exportOptionsPlist ios/exportOptions.plist
```

---

## FASTLANE CONFIGURATION

### Fastfile (iOS)
```ruby
default_platform(:ios)

platform :ios do
  desc "Push a new build to TestFlight"
  lane :beta do
    setup_ci if ENV['CI']

    match(type: "appstore", readonly: is_ci)

    increment_build_number(xcodeproj: "App.xcodeproj")

    build_app(
      workspace: "App.xcworkspace",
      scheme: "App",
      export_method: "app-store"
    )

    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end

  desc "Push to App Store"
  lane :release do
    beta
    upload_to_app_store(
      submit_for_review: true,
      automatic_release: true
    )
  end
end
```

### Fastfile (Android)
```ruby
default_platform(:android)

platform :android do
  desc "Deploy to Play Store internal track"
  lane :internal do
    gradle(
      task: "bundle",
      build_type: "Release"
    )

    upload_to_play_store(
      track: "internal",
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Promote to production"
  lane :production do
    upload_to_play_store(
      track: "production",
      track_promote_to: "production"
    )
  end
end
```

---

## GITHUB ACTIONS WORKFLOW

```yaml
name: Build & Deploy to Stores

on:
  push:
    tags:
      - 'v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Build web
        run: npm run build

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Build Android AAB
        run: |
          npx cap sync android
          cd android && ./gradlew bundleRelease

      - name: Deploy to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_KEY }}
          packageName: ${{ secrets.BUNDLE_ID }}
          releaseFiles: android/app/build/outputs/bundle/release/*.aab
          track: internal

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Build web
        run: npm run build

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Install Fastlane
        run: gem install fastlane

      - name: Build & Upload to TestFlight
        env:
          APPLE_KEY_ID: ${{ secrets.APPLE_KEY_ID }}
          APPLE_ISSUER_ID: ${{ secrets.APPLE_ISSUER_ID }}
          APPLE_KEY_CONTENT: ${{ secrets.APPLE_PRIVATE_KEY }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
        run: |
          npx cap sync ios
          cd ios && fastlane beta
```

---

## ASSET GENERATION

### Icon Sizes Required

**iOS:**
- 20x20, 29x29, 40x40, 58x58, 60x60, 76x76, 80x80, 87x87
- 120x120, 152x152, 167x167, 180x180, 1024x1024

**Android:**
- 48x48 (mdpi), 72x72 (hdpi), 96x96 (xhdpi)
- 144x144 (xxhdpi), 192x192 (xxxhdpi), 512x512 (Play Store)

**PWA:**
- 192x192, 512x512, 180x180 (apple-touch-icon)
- Maskable versions of each

### Generate All Icons
```bash
# Using sharp-cli
npm install -g sharp-cli

# iOS icons
sharp -i logo.png -o ios/App/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png resize 1024 1024
sharp -i logo.png -o ios/App/App/Assets.xcassets/AppIcon.appiconset/icon-180.png resize 180 180
# ... repeat for all sizes

# Android icons
sharp -i logo.png -o android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png resize 192 192
sharp -i logo.png -o android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png resize 144 144
# ... repeat for all sizes

# Or use pwa-asset-generator for all at once
npx pwa-asset-generator logo.png ./assets --background "#FFFFFF" --padding "10%"
```

---

## INITIATION COMMAND

```bash
# Run the autopilot
echo "
1. Scanning project...
2. Detecting framework and states...
3. Fixing blockers...
4. Building for production...
5. Generating Android AAB...
6. Generating iOS IPA...
7. Uploading to stores...
"

# Start with scan
ls -la
cat package.json 2>/dev/null || echo "No package.json found"
cat pubspec.yaml 2>/dev/null || echo "No pubspec.yaml found"

# Detect and proceed...
```

---

## SECURITY NOTES

1. **NEVER commit credentials** - All secrets go in `.env` (gitignored)
2. **Use environment variables** - Reference `$VAR_NAME` not literal values
3. **Rotate keys regularly** - Especially after any potential exposure
4. **Use GitHub Secrets** - For CI/CD, store in repository secrets
5. **Audit access** - Regularly review who has access to store consoles

---

*INITIATE: Read entire repo first. Execute all phases. Output TestFlight + Play URLs.*
