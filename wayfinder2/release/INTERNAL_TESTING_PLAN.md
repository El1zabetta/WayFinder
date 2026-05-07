# WayFinder Internal Testing Plan

## 1. Tester Profiles

| Role | Description | Minimum Testers |
|:---|:---|:---|
| Sighted Technical Tester | Developer or QA engineer testing functionality | 1-2 |
| Low-Vision Tester | User with partial vision testing usability | 1 (when available) |
| Blind / TalkBack Tester | Screen reader user testing full accessibility | 1 (when available) |
| Founder / Internal QA | Product owner validating overall experience | 1 |

## 2. Testing Groups

### Group A: Functional Testing (Android)
- Install debug APK or internal testing build
- Test all features end-to-end
- Report crashes, errors, unexpected behavior

### Group B: Backend / API Testing
- Verify backend health endpoint
- Test Ask and Analyze endpoints directly
- Monitor server logs for errors

### Group C: Accessibility Testing
- Test with TalkBack enabled
- Verify all buttons have semantic labels
- Test voice interaction flow
- Check haptic/audio feedback

### Group D: AI Safety Testing
- Verify obstacle detection responses
- Check that mock mode is clearly indicated
- Test edge cases (dark room, ceiling, floor)
- Verify no unsafe navigation commands

## 3. Test Scripts

### Test 1: First Launch
1. Install WayFinder on Android device
2. Open app
3. Verify onboarding screen appears
4. Sign in with Google
5. **Expected:** Successful login, home screen appears

### Test 2: Permission Grant
1. From home screen, tap Ask or Analyze
2. Permission dialog should appear for Camera and Microphone
3. Grant both permissions
4. **Expected:** App returns to main flow, camera preview may appear

### Test 3: Ask WayFinder
1. Tap microphone button or say "WayFinder"
2. Ask: "What is in front of me?"
3. **Expected:** App records speech, sends to backend, speaks response within 5-10 seconds
4. **Verify:** Response is short (1-2 sentences), relevant, does not make unsafe claims

### Test 4: Analyze Surroundings
1. Point camera at a scene with objects
2. Tap Analyze button
3. **Expected:** App captures frame(s), sends to backend, displays/speaks guidance
4. **Verify:** Response includes obstacle info if any, directional guidance, alert level

### Test 5: Stop Speaking
1. During spoken response, tap Stop button
2. **Expected:** Speech stops immediately
3. **Verify:** No crash, app remains usable

### Test 6: Repeat Last Response
1. After receiving a response, tap Repeat button
2. **Expected:** Last response is spoken again
3. **Verify:** Same content as original response

### Test 7: History
1. After at least one Ask or Analyze interaction
2. Navigate to History screen
3. **Expected:** List of past interactions with timestamps
4. **Verify:** Correct question/response pairs, ordered by time

### Test 8: Offline Mode
1. Disable WiFi and mobile data
2. Try Ask or Analyze
3. **Expected:** Graceful error message (not a crash)
4. **Verify:** App explains that internet is required

### Test 9: Denied Permissions
1. Deny camera or microphone permission
2. Try to use related feature
3. **Expected:** App explains why permission is needed, offers to open settings
4. **Verify:** No crash, no silent failure

### Test 10: TalkBack Navigation
1. Enable TalkBack on Android
2. Navigate through all screens using swipe gestures
3. **Expected:** All buttons, text, and interactive elements are announced
4. **Verify:** Navigation is logical, no unlabeled elements, no traps

## 4. Feedback Form Questions

After each testing session, testers should answer:

1. Did the app speak the response clearly and at a comfortable volume?
2. Was the main Ask/Analyze button easy to find and activate?
3. Did any AI response feel unsafe, misleading, or confusing?
4. Did the app freeze, crash, or get stuck at any point?
5. Did TalkBack labels make sense for all interactive elements? (TalkBack testers only)
6. Was anything about the app confusing or unclear?
7. How would you rate the overall experience? (1-5)
8. Any additional comments or suggestions?

## 5. Bug Report Template

```
## Bug Report

**Device:** [e.g., Samsung Galaxy S23]
**Android Version:** [e.g., Android 14]
**App Version:** [e.g., 2.0.0+1]
**Date:** [YYYY-MM-DD]

**Steps to Reproduce:**
1. ...
2. ...
3. ...

**Expected Behavior:**
...

**Actual Behavior:**
...

**Severity:** [Critical / High / Medium / Low]

**Screenshots / Logs:**
[Attach if available]
```

## 6. Testing Schedule

| Phase | When | Focus |
|:---|:---|:---|
| Pre-Internal | Before Google Play upload | Basic functionality on real device |
| Internal Alpha | After Play Console upload | Full feature testing, 1 week |
| Accessibility Round | After alpha fixes | TalkBack testing with real users |
| Closed Beta | After accessibility fixes | Broader testing group |
