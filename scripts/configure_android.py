from pathlib import Path
import re

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')

permissions = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.WAKE_LOCK"/>',
    '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
    '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
]
for permission in permissions:
    if permission not in text:
        text = text.replace('<application', permission + '\n    <application', 1)

activity_match = re.search(r'<activity\b[^>]*android:name="([^"]+)"[^>]*>', text, re.S)
if activity_match:
    activity = activity_match.group(0)
    if 'android:exported=' not in activity:
        activity = activity[:-1] + '\n            android:exported="true">'
        text = text[:activity_match.start()] + activity + text[activity_match.end():]

service = """    <service
        android:name="com.ryanheise.audioservice.AudioService"
        android:foregroundServiceType="mediaPlayback"
        android:exported="true">
        <intent-filter>
            <action android:name="android.media.browse.MediaBrowserService"/>
        </intent-filter>
    </service>
    <receiver
        android:name="com.ryanheise.audioservice.MediaButtonReceiver"
        android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.MEDIA_BUTTON"/>
        </intent-filter>
    </receiver>\n"""
if 'com.ryanheise.audioservice.AudioService' not in text:
    text = text.replace('</application>', service + '  </application>', 1)
manifest.write_text(text, encoding='utf-8')

gradle = Path('android/app/build.gradle.kts')
if gradle.exists():
    value = gradle.read_text(encoding='utf-8')
    value = value.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 37')
    value = value.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
    gradle.write_text(value, encoding='utf-8')

res = Path('android/app/src/main/res/drawable')
res.mkdir(parents=True, exist_ok=True)
(res / 'ic_repeat.xml').write_text("""<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M7,7h9.2l-1.6,-1.6L16,4l4,4 -4,4 -1.4,-1.4L16.2,9H7c-1.1,0 -2,0.9 -2,2v1H3v-1c0,-2.2 1.8,-4 4,-4zM17,17H7.8l1.6,1.6L8,20l-4,-4 4,-4 1.4,1.4L7.8,15H17c1.1,0 2,-0.9 2,-2v-1h2v1c0,2.2 -1.8,4 -4,4z"/></vector>""", encoding='utf-8')
(res / 'ic_shuffle.xml').write_text("""<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M16,3h5v5h-2V6.4l-4.2,4.2 -1.4,-1.4L17.6,5H16V3zM3,5h3.2c1.1,0 2.2,0.5 2.9,1.4l8,10.2c0.3,0.4 0.8,0.6 1.3,0.6H21v2h-2.6c-1.1,0 -2.2,-0.5 -2.9,-1.4L7.5,7.6C7.2,7.2 6.7,7 6.2,7H3V5zM3,17h3.2c0.5,0 1,-0.2 1.3,-0.6l2.1,-2.7 1.4,1.4 -1.9,2.5c-0.7,0.9 -1.8,1.4 -2.9,1.4H3v-2zM16,13.3l1.4,-1.4 2.2,2.7V13h2v6h-6v-2h2.6L16,13.3z"/></vector>""", encoding='utf-8')
