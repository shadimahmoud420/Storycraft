"""Applies StoryCraft's native settings after `flutter create`.
Safe to run multiple times. Usage: python3 tool/configure_platforms.py"""
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ok = lambda msg: print(f"  [ok] {msg}")
warn = lambda msg: print(f"  [!!] {msg}")


def configure_ios():
    plist_path = ROOT / "ios/Runner/Info.plist"
    if not plist_path.exists():
        warn("ios/Runner/Info.plist not found – run flutter create first")
        return
    with plist_path.open("rb") as f:
        plist = plistlib.load(f)
    plist.update({
        "CFBundleDisplayName": "StoryCraft",
        "CFBundleLocalizations": ["ar", "en"],
        "NSPhotoLibraryUsageDescription":
            "StoryCraft needs access to your photos so you can pick a picture "
            "for your story background.",
        "NSPhotoLibraryAddUsageDescription":
            "StoryCraft saves your finished story designs to your photo library.",
        "NSCameraUsageDescription":
            "StoryCraft can use the camera to take a photo for your story.",
        # The app uses no custom encryption: skips the export-compliance
        # question on every TestFlight / App Store upload.
        "ITSAppUsesNonExemptEncryption": False,
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
    })
    plist.pop("UISupportedInterfaceOrientations~ipad", None)
    with plist_path.open("wb") as f:
        plistlib.dump(plist, f)
    ok("Info.plist: name, permissions, portrait, encryption flag")

    pbx = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    text = pbx.read_text()
    # iPhone only: avoids mandatory iPad screenshots & iPad review.
    new = re.sub(r'TARGETED_DEVICE_FAMILY = "1,2";', "TARGETED_DEVICE_FAMILY = 1;", text)
    pbx.write_text(new)
    ok("Xcode project: iPhone only")


SIGNING_HEADER = '''import java.io.FileInputStream
import java.util.Properties

'''

SIGNING_PROPS = '''
// Release signing: values come from android/key.properties (never commit it).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
'''

SIGNING_CONFIGS = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {'''

RELEASE_SIGNING = '''signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }'''


def configure_android():
    gradle = ROOT / "android/app/build.gradle.kts"
    if not gradle.exists():
        warn("android/app/build.gradle.kts not found – add release signing "
             "manually (see docs/RELEASE_GUIDE.md)")
        return
    text = gradle.read_text()
    if "keystoreProperties" in text:
        ok("build.gradle.kts: release signing already configured")
        return
    debug_line = 'signingConfig = signingConfigs.getByName("debug")'
    if "buildTypes {" not in text or debug_line not in text:
        warn("build.gradle.kts has an unexpected layout – add release signing "
             "manually (see docs/RELEASE_GUIDE.md)")
        return
    text = SIGNING_HEADER + text
    end_of_plugins = text.index("}", text.index("plugins {")) + 1
    text = text[:end_of_plugins] + "\n" + SIGNING_PROPS + text[end_of_plugins:]
    text = text.replace("    buildTypes {", SIGNING_CONFIGS, 1)
    text = text.replace(debug_line, RELEASE_SIGNING, 1)
    gradle.write_text(text)
    ok("build.gradle.kts: release signing via key.properties")


if __name__ == "__main__":
    configure_ios()
    configure_android()
