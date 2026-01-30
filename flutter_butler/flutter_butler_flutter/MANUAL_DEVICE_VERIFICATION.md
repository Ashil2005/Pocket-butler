# MANUAL DEVICE VERIFICATION PROTOCOL
## OPPO CPH2219 - Flutter Butler Release Testing

### ✅ COMPLETED: APK Installation & Launch
- **Status**: SUCCESS
- **Device**: OPPO CPH2219 (Android 13 API 33)
- **Installation Time**: 5.6 seconds
- **Launch Status**: App running, no crashes detected
- **Services**: Geolocator initialized, Flutter engine connected

---

## 🔍 PHASE 4 VERIFICATION MATRIX

### STEP 1: PERMISSION VERIFICATION (MANUAL)
**On the OPPO device, verify these permissions are granted:**

1. **Open Flutter Butler app**
2. **Check permission dialogs appear for:**
   - ✅ Location (Fine Location)
   - ✅ Location (Background Location) 
   - ✅ Bluetooth Connect
   - ✅ Bluetooth Scan
   - ✅ Notifications (Android 13+)
   - ✅ Phone/SMS (for emergency contacts)

3. **Grant ALL permissions with "Allow all the time" for location**

**Expected Result**: App should reach HomeScreen without crashes

---

### STEP 2: COLOROS SURVIVAL CONFIGURATION (CRITICAL)
**Navigate to OPPO Settings and configure:**

#### Battery Optimization
1. Settings → Battery → App Battery Usage
2. Find "Flutter Butler" 
3. Tap → "Allow background activity"
4. Set to "Don't optimize"

#### Auto Launch  
1. Settings → Apps → Flutter Butler
2. Enable "Auto-launch"
3. Enable "Background execution"
4. Enable "Run in background"

#### Location Services
1. Settings → Location → GPS ON
2. Settings → Apps → Flutter Butler → Permissions
3. Location → "Allow all the time"

---

### STEP 3: BLUETOOTH & THEFT DETECTION TEST

#### 3A: Trusted Device Pairing
1. **Ensure Bluetooth is ON**
2. **Pair a trusted Bluetooth device** (phone, earbuds, etc.)
3. **Open Flutter Butler**
4. **Navigate to Device Selection**
5. **Select the trusted device**
6. **Verify RSSI readings appear**

#### 3B: ARM System Test
1. **Tap ARM button**
2. **Enter security PIN** (if configured)
3. **Verify system shows "ARMED" status**
4. **Check notification appears** (foreground service)

#### 3C: Grace Period Test
1. **With system ARMED**
2. **Walk slowly away from trusted device**
3. **Observe grace period countdown** (should be visible)
4. **Return within grace period**
5. **Verify countdown cancels**

#### 3D: Snatch Detection Test
1. **ARM system**
2. **Rapidly move away from trusted device** (simulate theft)
3. **Expected**: Instant alarm (no grace period)
4. **Verify alarm sound plays**
5. **Test DISARM functionality**

#### 3E: Signal Blip Test
1. **ARM system**
2. **Turn Bluetooth OFF for <2 seconds**
3. **Turn Bluetooth back ON**
4. **Expected**: NO alarm (debounce logic)

---

### STEP 4: PERSISTENCE & ABUSE RESISTANCE

#### 4A: App Kill Survival
1. **ARM the system**
2. **Swipe-kill the app** (recent apps → swipe up)
3. **Wait 2 minutes**
4. **Check notification still present**
5. **Verify monitoring continues**

#### 4B: Reboot Persistence  
1. **ARM the system**
2. **Reboot the OPPO device**
3. **After reboot, check:**
   - Service auto-resumes
   - Monitoring continues
   - No re-ARM required

#### 4C: Force Stop Test
1. **ARM system**
2. **Settings → Apps → Flutter Butler → Force Stop**
3. **Document behavior** (expected: service stops)

---

### STEP 5: UX & FEEDBACK VERIFICATION

#### 5A: Visual Feedback
- [ ] Grace period countdown visible
- [ ] ARM/DISARM status clear
- [ ] RSSI readings update
- [ ] Alert notifications appear

#### 5B: Haptic Feedback
- [ ] ARM button vibrates
- [ ] DISARM button vibrates  
- [ ] Alert triggers vibration

#### 5C: Audio Feedback
- [ ] Alarm sound plays during alert
- [ ] Volume respects device settings
- [ ] Audio stops on DISARM

---

### STEP 6: AUDIT & LOGGING

#### 6A: Event Logging Verification
1. **Perform various actions** (ARM, DISARM, alerts)
2. **Check if logs are created** for:
   - REBOOT_RESUME
   - SIGNAL_LOST_CONFIRMED  
   - SNATCH_DETECTED
   - ALARM_TRIGGERED
   - RECOVERY

---

## 📊 VERIFICATION RESULTS TEMPLATE

### ✅ SUCCESSFUL TESTS
- [ ] APK Installation
- [ ] App Launch
- [ ] Permission Grants
- [ ] HomeScreen Reach
- [ ] Bluetooth Pairing
- [ ] ARM/DISARM
- [ ] Grace Period Logic
- [ ] Snatch Detection
- [ ] App Kill Survival
- [ ] Reboot Persistence
- [ ] Audio/Haptic Feedback
- [ ] Event Logging

### ⚠️ ISSUES FOUND
- [ ] Permission denied: ___________
- [ ] ColorOS restriction: ___________
- [ ] Service killed by: ___________
- [ ] Bluetooth issue: ___________
- [ ] Other: ___________

### 🎯 FINAL CLASSIFICATION
- [ ] ✅ Phase 4 VERIFIED — RELEASE READY
- [ ] ⚠️ Phase 4 VERIFIED WITH OEM NOTES  
- [ ] ❌ Blocking runtime defect found

---

## 📝 TESTING NOTES
*Record any observations, issues, or ColorOS-specific behaviors here*
