#!/usr/bin/env python3
"""Pasang signingConfig rilis (keystore LAMA ~/.wakuplay) ke android/app/build.gradle(.kts). Idempoten."""
import os, re, sys
home = os.path.expanduser('~')
base = os.environ.get('WORK', '/work') + '/android/app/'
kts = os.path.exists(base + 'build.gradle.kts')
p = base + ('build.gradle.kts' if kts else 'build.gradle')
s = open(p).read()
if 'wp-sign' in s:
    print('signing sudah terpasang'); sys.exit(0)
props = home + '/.wakuplay/sign.properties'
if kts:
    head = ('// wp-sign\nimport java.util.Properties\nimport java.io.FileInputStream\n'
            f'val wp = Properties().apply {{ load(FileInputStream("{props}")) }}\n')
    cfg = ('\n    signingConfigs {\n        create("wakuplay") {\n'
           '            storeFile = file(wp.getProperty("storeFile"))\n'
           '            storePassword = wp.getProperty("storePassword")\n'
           '            keyAlias = wp.getProperty("keyAlias")\n'
           '            keyPassword = wp.getProperty("keyPassword")\n        }\n    }\n')
    s = head + s
    s = re.sub(r'android\s*\{', lambda m: m.group(0) + cfg, s, 1)
    s = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("wakuplay")', s)
else:
    head = ('// wp-sign\ndef wp = new Properties()\n'
            f'wp.load(new FileInputStream(new File("{props}")))\n')
    cfg = ('\n    signingConfigs {\n        wakuplay {\n'
           "            storeFile file(wp['storeFile'])\n            storePassword wp['storePassword']\n"
           "            keyAlias wp['keyAlias']\n            keyPassword wp['keyPassword']\n        }\n    }\n")
    s = head + s
    s = re.sub(r'android\s*\{', lambda m: m.group(0) + cfg, s, 1)
    s = s.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.wakuplay')
    s = s.replace('signingConfig = signingConfigs.debug', 'signingConfig = signingConfigs.wakuplay')
if 'wakuplay")' not in s and 'signingConfigs.wakuplay' not in s:
    print('PERINGATAN: baris signingConfig release tidak ditemukan; periksa build.gradle manual'); sys.exit(1)
open(p, 'w').write(s)
print('signing rilis terpasang di', p)
