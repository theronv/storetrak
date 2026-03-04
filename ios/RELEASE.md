# Storetrak iOS Release Process

## 1. Update the Code

Make changes in Xcode or your editor of choice. Key files:
- `Storetrak/App/AppState.swift` — central state / data logic
- `Storetrak/Services/APIClient.swift` — API calls
- `Storetrak/Services/AuthManager.swift` — auth / Keychain
- `Storetrak/Views/` — SwiftUI views

## 2. Push to GitHub

```bash
cd /Users/theron/storetrak
git add .
git commit -m "your message here"
git push origin main
```

## 3. Bump the Build Number

Every TestFlight upload requires a unique build number.

- In Xcode: select the project → target → **General** tab → increment **Build** (e.g. 1 → 2)
- Version (e.g. `1.0.0`) only needs to change for meaningful releases

Or via terminal:
```bash
cd /Users/theron/storetrak/ios
agvtool next-version -all
```

## 4. Archive in Xcode

1. Set the run destination to **Any iOS Device (arm64)** (top toolbar)
2. **Product → Archive**
3. Wait — the **Organizer** window opens when done

## 5. Upload to TestFlight

1. In Organizer, select the new archive → **Distribute App**
2. Choose **TestFlight & App Store**
3. Follow the wizard (defaults are fine)
4. Sign in with Apple ID if prompted
5. Wait 5–15 min for Apple to process — you'll get an email

## 6. Add Testers (first time or new tester)

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Your app → **TestFlight** tab
3. Add internal or external testers

---

## Checklist Before Each Build

- [ ] Code changes committed and pushed
- [ ] Build number incremented
- [ ] Destination set to **Any iOS Device (arm64)**
- [ ] Signing certificates valid (Xcode → Settings → Accounts → Manage Certificates)

## Troubleshooting

- **"No accounts with App Store distribution"** — re-download your distribution certificate in Xcode settings
- **"Invalid build number"** — build number must be higher than any previously uploaded build
- **Build rejected** — check App Store Connect for specific rejection reason under the build's detail page
