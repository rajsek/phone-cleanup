# Cleaning Up Four Family Phones with Codex

Helping family with their phones is a familiar job. Someone hands you a phone and says, “Can you check this? Something keeps appearing.”

An unfamiliar app. Shopping notifications. Ads on the lock screen.

My parents and my sister’s family use their phones for everyday things: calls, WhatsApp, payments, and a few apps. They don’t need much. But one accidental tap can sometimes lead to more unwanted apps, and I kept finding myself cleaning up the same phones again.

I wanted to make that maintenance easier, so I used **Codex on my Mac, connected to four Redmi and POCO phones over Wi-Fi debugging**.

The idea was simple: let the coding agent help inspect installed packages, explain what could be removed, and run the commands I approved. I would still make the decisions.

## Connecting Codex to the phone

I didn't need to install an AI assistant on each phone or ask anyone in my family to learn terminal commands.

My Mac handled the work through Android Debug Bridge (ADB). Wireless debugging provided the connection, and Codex helped with package inventories, command execution, and verification.

The workflow was straightforward:

1. Connect to the intended phone.
2. List its installed packages.
3. Review what each removal candidate does.
4. Remove only the packages I approve.
5. Check the package list again and test the phone.

Across the devices, I reviewed Xiaomi advertising components, GetApps, Wallpaper Carousel, analytics, and optional applications.

Not every unfamiliar package was a problem. A feature one person never uses might be essential to someone else. I wanted to keep the phones useful for their owners, not strip them down just to produce a shorter app list.

## Finding what could be removed

One useful reference was the community-maintained [Universal Android Debloater Next Generation repository](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation).

Its [package database](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation/blob/main/resources/assets/uad_lists.json) helped identify packages and understand their likely roles.

Instead of guessing what a package such as `com.miui.msa.global` did, I could compare the phone's actual inventory with the database, review the description, and consider the consequences.

Some examples from the cleanup included:

| Package | Purpose considered during review |
|---|---|
| `com.miui.msa.global` | Xiaomi system advertising |
| `com.xiaomi.mipicks` | GetApps store and promotional content |
| `com.miui.android.fashiongallery` | Wallpaper Carousel / Glance |
| `com.miui.analytics` | Usage analytics |
| `com.miui.hybrid` | Quick Apps components |

These aren't universal removal recommendations. Package availability and dependencies vary by model and firmware, so each phone needs its own inspection.

I used the database as a reference, not as a list to execute blindly. Codex helped with the repetitive work, but I reviewed the candidates and approved the changes.

## The practical workflow

The setup was macOS with zsh, Android SDK Platform-Tools, and Android 11 phones. The same general approach applies to compatible Android devices, though manufacturer menus and package behaviour can differ.

First, install the current [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools). Enable Developer options and Wireless debugging on the phone, then pair it with the Mac. Keep the phone and computer on a trusted network.

Pairing and connecting use different addresses and ports. Use the pairing address shown in the pairing dialog, then the connection address shown on the main Wireless debugging screen.

```sh
adb pair PAIRING_IP:PAIRING_PORT
adb connect PHONE_IP:CONNECTION_PORT
adb devices -l
```

Proceed only when the intended phone appears with the status `device`. Stop if it is `offline`, `unauthorized`, or missing.

Next, inspect the device and save its package inventory:

```sh
adb -s "$PHONE" shell getprop ro.product.model
adb -s "$PHONE" shell getprop ro.build.version.release

adb -s "$PHONE" shell pm list packages --user 0 \
  > packages-before.txt
```

Review the inventory before making changes. Keep separate records for each phone so that the results don't get mixed up.

For the agent, I used instructions along these lines:

> Inspect the connected phone and review its installed packages against the Universal Android Debloater Next Generation database. Separate advertising components, analytics, optional apps, and essential services. Explain the likely impact and any uncertainty. Wait for my approval before removing anything. Save before-and-after inventories and verify the results. Do not root, reboot, or modify essential system components without approval.

Once I had reviewed a specific package, the removal command was simple:

```sh
adb -s "$PHONE" shell pm uninstall -k --user 0 PACKAGE_NAME
```

Here, `--user 0` targets the main owner account, while `-k` requests that app data be retained. For preinstalled apps, this is a user-level uninstall; it does not permanently erase the factory APK from the system partition.

Afterward, I checked the package state again:

```sh
adb -s "$PHONE" shell pm list packages --user 0 PACKAGE_NAME
```

The expected result is that the selected package no longer appears for that user. A successful command alone isn't enough; the resulting state matters more.

## What I could verify

Across the cleanup sessions, I verified selected packages absent from the intended user account. One session on a POCO C31 confirmed 16 selected packages absent; a later session confirmed 19.

I won't turn those figures into a claim that every unwanted app was removed from all four phones. We hadn't traced every unexpected installation, so we hadn't proved that the original installation route was permanently blocked either.

I also investigated sluggishness, but didn't establish a performance improvement. Removing optional packages and making a phone measurably faster are two different claims.

Before handing a phone back, I'd check calls, Wi-Fi, the keyboard, notifications, and the apps its owner relies on. I'd also check for current security updates and run a fresh Play Protect scan. Finally, turn off Wireless debugging and remove the computer's pairing when the maintenance session is over.

The useful part wasn't the uninstall command. It was having a repeatable way to inspect, review, make changes, and verify what actually happened.

## The same idea beyond phones

Around the same time, I came across two projects exploring a similar idea for Android TV:

- [Free My TV](https://github.com/simbasjungles/free-my-tv) provides an alternative TV home screen.
- [Clean Your TV](https://github.com/Gathin23/cleanyourtv) documents disabling unwanted Android TV packages and installing a launcher.

I didn't use either project for the phone cleanup; my work was separate. But they explore the same broader theme: taking more control over devices we already own instead of simply accepting every preinstalled app, interface, or promotion.

For me, that started with four family phones and a recurring request to check what had appeared again. Codex made the maintenance easier to repeat, while the decisions about "what to remove and what to leave alone—remained mine".
