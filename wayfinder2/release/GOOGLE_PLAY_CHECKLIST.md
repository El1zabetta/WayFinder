# Google Play Store Release Checklist

## 1. App Details
- [ ] **App Name:** WayFinder
- [ ] **Short Description:** AI-powered egocentric navigation assistant for the visually impaired.
- [ ] **Full Description:** (See STORE_LISTING_DRAFT.md)

## 2. Graphic Assets
- [ ] **App Icon:** 512x512 PNG, 32-bit (Add via `flutter_launcher_icons`)
- [ ] **Feature Graphic:** 1024x500 PNG
- [ ] **Screenshots:** Minimum 2 to 8 screenshots (Android Phone size). Ensure they show the Home Camera, Question History, and Settings.

## 3. Privacy & Policy
- [ ] **Privacy Policy URL:** Host `PRIVACY_POLICY_DRAFT.md` on a website (e.g., GitHub Pages or your domain) and paste the link in the Play Console.
- [ ] **Data Safety Form:** 
  - Declare that the app collects Audio (Microphone) and Images (Camera) temporarily for processing.
  - Declare that user data (like History) is tied to the Firebase Auth ID.
  - Check "App does not share data with third parties" (unless you count Firebase).
  - Indicate that data is encrypted in transit (HTTPS/WSS).

## 4. App Content
- [ ] **Target Audience:** 13 and older.
- [ ] **Content Rating:** Fill out the IARC questionnaire (Likely "Everyone" or equivalent).
- [ ] **Accessibility:** Check the box stating this app provides accessibility features or is targeted at accessibility use cases.

## 5. Release Tracks
- [ ] **Internal Testing:** Upload the first `.aab` (Android App Bundle) here. Add testers by email.
- [ ] **Closed Testing:** Move from Internal to Closed. Wait for Google Review (can take up to 7 days for new apps).
- [ ] **Production:** Roll out to production once closed testing is approved and stable.
