# Family Phone Cleanup

A small, review-first ADB workflow for cleaning up family Android phones. Built from maintenance work on older Redmi/POCO devices, including a POCO M2 and POCO C31. There is no universal uninstall list and no claim that unfamiliar apps are malware.

Read the story: [Cleaning Up Four Family Phones with Codex.](ARTICLE.md)

## Requirements

- macOS with its bundled Bash 3.2 or newer, or Linux with Bash and standard Unix tools. Windows users need an equivalent environment; Windows was not tested.
- Current [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools), with `adb` on `PATH`.
- An owned/authorized Android phone. The original sessions used Android 11/MIUI 12.5; other firmware has not been device-tested with these scripts.
- Python 3 only for running the simulated-device tests.

Back up important data and review feature loss before removing an app. The scripts protect several essential packages plus the active keyboard and launcher, but cannot model every firmware dependency. Do not use this to remove management controls from a managed device. Runtime inventories stay in ignored `runs/` folders; review any files before sharing them publicly.

## 1. Connect

Enable Developer options and Wireless debugging on the phone. Keep it on the same trusted Wi-Fi as the computer. In the terminal, run:

```sh
adb version
adb devices -l
```

For Android 11+ wireless pairing, open **Pair device with pairing code** on the phone. Replace the placeholders with the phone's current values:

```sh
adb pair PHONE_IP:PAIRING_PORT
# Type the pairing code locally at adb's prompt.
adb connect PHONE_IP:CONNECTION_PORT
adb devices -l
```

Pairing and connection ports can differ. After reboot, check the current connection address or run `adb mdns services`. Use the exact serial/IP:port shown by `adb devices -l`; proceed only if its state is `device`. A paired computer can still have no live connection. See [Android's ADB documentation](https://developer.android.com/tools/adb).

## 2. Inspect and review

```sh
./inspect.sh 'PHONE_IP:CONNECTION_PORT'
```

This reads the model, software versions, security patch date, current user, and package inventory. It saves a unique local folder under `runs/`; it does not change device packages. An explicit profile can be inspected with `./inspect.sh SERIAL USER_ID`.

Use the [UAD Next Generation package database](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/blob/main/resources/assets/uad_lists.json) as a reference, then review each candidate's actual function, firmware dependencies, and usefulness to the phone owner. The database is not downloaded or executed by these scripts. [PROMPT.md](PROMPT.md) contains a coding-agent handoff prompt.

## 3. Remove one reviewed package

**This step changes the phone.** Replace both placeholders with reviewed values:

```sh
./remove-reviewed.sh 'PHONE_IP:CONNECTION_PORT' 'com.example.reviewedapp'
```

The script displays the device model, ADB target, current user, and package, then requires you to type `REMOVE`. It runs `pm uninstall -k --user USER_ID PACKAGE`: a user-level removal that requests retained app data. For preinstalled apps, the protected factory APK can remain on the device. This is different from disabling an app or physically deleting a system APK.

Before/after inventories and command output are saved locally. The script verifies an exact package match and checks whether other packages appeared or disappeared. It never roots, reboots, replaces a launcher, restores apps, or changes wallpaper.

Exit states:

- **0:** inspection completed, removal was cancelled, package was already absent, or one removal was verified. Read the printed outcome to distinguish them.
- **1:** device/check/removal/verification failed, or command output disagreed with observed state. Stop and inspect the run records; some changes may already have happened.
- **2:** invalid usage, package/user format, or missing `adb`.

Data retention is not a full backup. If you later choose to restore a preinstalled package whose factory copy remains, Android offers `adb -s SERIAL shell cmd package install-existing --user USER_ID PACKAGE`. Check the exact device/user first; this is not automatic and does not restore an arbitrary deleted downloaded APK.

## 4. Check the screen and finish

Package removal alone cannot prove the visible problem is solved. A saved promotional wallpaper can remain; a shopping-app notification has a separate source; MIUI lock-screen shortcuts may be built into System UI. Read the [combined session lessons](examples/cleanup-lessons.md).

Check calls, Wi-Fi, keyboard, notifications, and the owner's apps on the phone. Run a fresh Play Protect scan and check official system updates separately. Debloating does not repair an outdated security patch. Turn Wireless debugging off and remove the computer's pairing when maintenance is finished.

## Validation

```sh
bash -n inspect.sh remove-reviewed.sh
python3 -m unittest discover -s tests -v
```

The tests use a fake `adb`, not a connected phone. They exercise refusal, cancellation, command failures, and before/after verification. The reusable scripts have not yet been run against physical devices; the original sessions used individual ADB commands. For tool selection/testing, `ADB_BIN` can point to an alternative executable; otherwise it defaults to `adb`.

## Sources and attribution

- [Android ADB documentation](https://developer.android.com/tools/adb) and [Platform-Tools](https://developer.android.com/tools/releases/platform-tools): device connection and package-management tooling.
- [Universal Android Debloater Next Generation](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation): package descriptions/classifications consulted in the original cleanups. No upstream code or package database is bundled here; upstream licensing remains separate.
- [Free My TV](https://github.com/simbasjungles/free-my-tv) and [Clean Your TV](https://github.com/Gathin23/cleanyourtv): parallel TV projects referenced in the article, not phone cleanup dependencies. Their reported results are not measurements of these phones.
- [Xiaomi wallpaper instructions](https://www.mi.com/global/support/article/KA-33155/): applying to the lock screen versus home screen.

Original project files are covered by the [MIT license](LICENSE). No phone credentials, pairing codes, screenshots, raw histories, or private inventories are included.
