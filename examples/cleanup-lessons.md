# Combined lessons from the original sessions

These are anonymized historical notes, not fresh device checks or a batch removal list. Four cleanup threads were reviewed; sessions are not proof of four distinct hardware models. The author's four-phone account is preserved in the article; the records explicitly identify a POCO M2 and POCO C31, with additional Xiaomi sessions reporting the same numeric model identifier.

| Observation | Lesson |
|---|---|
| USB debugging was enabled but macOS did not detect the phone over USB | Check transport detection before retrying commands; Android 11 wireless debugging provided the working path |
| The phone showed the computer as paired, but ADB was offline | Pairing is separate from a live connection; a reboot can change the connection port |
| One C31 session verified 16 selected packages absent; a later session verified 19 | Keep counts attached to their session/user; do not sum them into a unique four-phone total |
| An extra-keyboard uninstall returned `Failure [-1000]`, but later package/path checks found it absent | Command output and resulting state can disagree; preserve evidence and stop to investigate |
| A lock-screen ₹49 offer remained after Carousel removal | A saved wallpaper outlives its provider; replace the wallpaper before removing its management app |
| Themes was temporarily restored to access wallpaper controls, then removed again | Restoration is a separate user-authorized action; the reusable scripts do not do it |
| Xiaomi blocked a remote wallpaper action | A person had to make the selection on the device; the final visual confirmation was not captured |
| A Flipkart notification appeared alongside the wallpaper | Identify the notification's app separately from the wallpaper source |
| Mi Home/remote shortcuts remained on a right swipe | The MIUI System UI panel can remain without the app; no supported root-free gesture switch was verified on that firmware |
| An old Play Protect result was visible | It was not a fresh scan result |
| Storage, memory, and temperature did not explain stuttering; a fresh measurement was interrupted | No confirmed performance cause, fix, or speedup was established |
| Android reported a July 2023 security patch | Package cleanup does not supply operating-system security updates |

The original work used individual ADB commands. The repository's reusable scripts are a later extraction and have simulated-device test coverage, not fresh physical-device validation. A package's absence does not certify that ads are gone, malware is absent, or future unwanted installations are prevented.
