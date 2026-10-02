from pathlib import Path
import plistlib
import re

info = Path('ios/Runner/Info.plist')
data = plistlib.loads(info.read_bytes())
data['UIBackgroundModes'] = ['audio']
data['NSPhotoLibraryUsageDescription'] = 'ZEIA memerlukan akses ke galeri untuk memilih cover playlist.'
info.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_XML, sort_keys=False))

podfile = Path('ios/Podfile')
if podfile.exists():
    text = podfile.read_text(encoding='utf-8')
    text = re.sub(r"platform :ios, ['\"][^'\"]+['\"]", "platform :ios, '13.0'", text, count=1)
    if 'platform :ios' not in text:
        text = "platform :ios, '13.0'\n" + text
    podfile.write_text(text, encoding='utf-8')
