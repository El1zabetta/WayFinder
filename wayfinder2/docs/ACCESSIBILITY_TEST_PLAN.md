# WayFinder Accessibility Test Plan

> **Objective:** Ensure that WayFinder is 100% usable by blind and visually impaired users navigating exclusively via screen readers (TalkBack on Android, VoiceOver on iOS). No critical flow should require visual verification.

## 1. Prerequisites
- **Android Device:** Enable TalkBack (Settings > Accessibility > TalkBack).
- **iOS Device:** Enable VoiceOver (Settings > Accessibility > VoiceOver).
- **Network:** Ability to toggle Airplane mode for offline testing.

---

## 2. Android TalkBack Test Flow
1. **Launch App:** Open WayFinder with TalkBack enabled.
2. **Onboarding:** Swipe right to navigate through the 4 onboarding screens. Verify that the title and body of each page are announced clearly. Double tap the "Next" button to proceed.
3. **Permissions:** Grant permissions using TalkBack. Ensure the rationale is read aloud.
4. **Home Screen:** 
   - Swipe to explore the layout. 
   - Verify that the App Status and Wake Word status are announced.
   - Verify that the **Massive "Ask WayFinder" Button** is announced as a button with a clear hint.
   - Verify that the **Massive "Analyze Surroundings" Button** is announced.
5. **Action:** Double-tap the "Analyze Surroundings" button. Ensure the "Analyzing..." state is announced and haptic feedback is triggered.
6. **Ask Assistant:** Double-tap the "Ask WayFinder" button. Verify the live region announces "Listening". Dictate a question and double-tap "Send Question".
7. **Cancel:** Open Ask Assistant, then double-tap the "Close" button. Verify the sheet closes.

## 3. iOS VoiceOver Test Flow
1. **Launch App:** Open WayFinder with VoiceOver enabled.
2. **General Navigation:** Use swipe left/right gestures to move focus. Verify the focus rectangle encompasses the massive buttons correctly without overlapping.
3. **Home Screen Layout:** Ensure the order of elements read by VoiceOver is logical (Top Bar -> Audio Compass -> Guidance Card -> Ask Button -> Analyze Button -> Safety Area).
4. **Action:** Double-tap "Analyze Surroundings" and verify the screen reader pauses or announces processing correctly.
5. **Ask Assistant:** Double-tap "Ask WayFinder". Test the "Stop" and "Close" buttons.

## 4. Low-Vision Large Text Test
1. Go to OS Settings (Android/iOS) and set **Display Size** and **Font Size** to maximum.
2. Open WayFinder.
3. **Verification:**
   - Text must not be truncated.
   - Buttons must remain fully visible and tap targets must not overlap.
   - The massive buttons on the Home screen must adapt or scroll if they exceed screen bounds.
   - The Ask Assistant sheet must remain usable and scrollable.

## 5. Permission Denied Test
1. Deny Camera and Microphone permissions in OS settings.
2. Open WayFinder.
3. **Verification:**
   - Screen reader must immediately announce that permissions are denied upon reaching the Home Screen.
   - A "Retry" button must be accessible and its function clear.

## 6. Offline Test
1. Turn on **Airplane Mode**.
2. Open WayFinder.
3. Double-tap "Analyze Surroundings".
4. **Verification:**
   - App must announce "Offline" via TTS.
   - A safety hint must be spoken.
5. Double-tap "Ask WayFinder", ask a question, and submit.
   - App must attempt to find a cached answer or announce that no cached answer is available for offline mode.

## 7. Wake Word Enabled/Disabled Test
1. Ensure Wake Word is enabled in settings.
2. Go to the Home Screen. Verify the top status bar announces "Wake word: Enabled".
3. Say "Way Finder".
   - The Ask Assistant sheet should open automatically.
   - "Listening" should be announced.
4. Disable Wake Word in Settings.
5. Return to Home Screen. Verify the status bar announces "Wake word: Disabled".
6. Say "Way Finder".
   - The app must **not** react.

## 8. Stop Speech Test
1. Trigger a long TTS response (e.g., a detailed scene analysis or a long answer to a question).
2. While TTS is speaking, locate and double-tap the **"Stop"** button in the Safety Area of the Home Screen (or Ask Assistant sheet).
3. **Verification:**
   - TTS must interrupt and stop speaking **immediately**.
   - Haptic feedback (tap) should confirm the action.

## 9. Repeat Response Test
1. After a response has finished playing, locate and double-tap the **"Repeat"** button.
2. **Verification:**
   - The exact last response must be spoken again in full.
   - If Ask Assistant was the last action, its answer should be repeated. If Scene Analysis was the last action, its analysis should be repeated.
