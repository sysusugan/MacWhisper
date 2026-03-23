# Psst Free — Commercial Distribution Checklist

Everything code-side is set up. Below are the manual steps you need to complete.

---

## 1. Apple Developer Program

- [ ] Enroll at https://developer.apple.com/programs/ ($99/year)
- [ ] Use your business identity: Douglas Anthony Silkstone / Finmag.cz
- [ ] Once approved, note your **Team ID** (visible in Membership section)

## 2. Certificates & Signing

- [ ] In Xcode → Settings → Accounts, sign in with your Apple ID
- [ ] Or via https://developer.apple.com/account/resources/certificates
- [ ] Create a **Developer ID Application** certificate
- [ ] Download and install it into your Keychain
- [ ] Verify it exists: `security find-identity -v -p codesigning | grep "Developer ID"`
- [ ] Copy the full identity string for `DEVELOPER_ID` env var

## 3. Notarization Credentials

- [ ] Generate an app-specific password at https://appleid.apple.com/account/manage (Security → App-Specific Passwords)
- [ ] Store credentials for the build script:
  ```bash
  export DEVELOPER_ID="Developer ID Application: Douglas Anthony Silkstone (YOUR_TEAM_ID)"
  export APPLE_ID="your@email.com"
  export TEAM_ID="YOUR_TEAM_ID"
  export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
  ```
- [ ] Test a signed build: `./build-app.sh`

## 4. Sparkle Auto-Updates

- [ ] Install Sparkle tools: `brew install sparkle`
- [ ] Generate an EdDSA key pair: `generate_keys` (save the private key securely!)
- [ ] Replace `SPARKLE_ED25519_PUBLIC_KEY_PLACEHOLDER` in `PsstFree/Info.plist` with your public key
- [ ] After each release, run `./scripts/generate-appcast.sh`
- [ ] Upload the DMG + `appcast.xml` to your hosting

## 5. Payment Provider

Pick one (recommended: **LemonSqueezy** for simplicity or **Paddle** for full-service):

### Option A: LemonSqueezy
- [ ] Create account at https://lemonsqueezy.com
- [ ] Create a product for Psst Free (one-time payment, suggested $29)
- [ ] Get your API key and license validation endpoint
- [ ] Update `LicenseManager.swift` → `validationURL` with your endpoint
- [ ] Adapt the validation payload format (see comments in code)

### Option B: Paddle
- [ ] Create account at https://paddle.com
- [ ] Create a product, set pricing
- [ ] Get your API credentials
- [ ] Update `LicenseManager.swift` accordingly

## 6. Domain & Hosting

- [ ] Register a domain (e.g., psstfree.com)
- [ ] Host the landing page (`website/index.html`) — options:
  - Vercel (free, easy): `cd website && vercel`
  - Netlify (free)
  - GitHub Pages (free, but repo must be public)
  - Cloudflare Pages (free)
- [ ] Update `SUFeedURL` in Info.plist to match your actual domain
- [ ] Update the "Buy License" URL in `LicenseView.swift`
- [ ] Upload DMG files to your domain for downloads

## 7. Legal

- [ ] Review the generated privacy policy (`website/privacy.html`)
- [ ] Review the generated terms of service (`website/terms.html`)
- [ ] Update contact email and any placeholder details
- [ ] Consider having a lawyer review before launch

## 8. First Release Build

```bash
# Full release flow:
DEVELOPER_ID="Developer ID Application: ..." \
APPLE_ID="..." TEAM_ID="..." APP_PASSWORD="..." \
./build-app.sh

# Generate appcast for auto-updates:
./scripts/generate-appcast.sh

# Upload dist/PsstFree-1.0.0.dmg + website/appcast.xml to your hosting
```

## 9. Version Bumps

For new releases, update the version in `PsstFree/Info.plist`:
- `CFBundleShortVersionString` — user-facing version (e.g., "1.1.0")
- `CFBundleVersion` — build number (increment each build, e.g., "2")

Then rebuild, notarize, regenerate appcast, and upload.
