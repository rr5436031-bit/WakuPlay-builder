import fs from 'node:fs'
import path from 'node:path'

const app = path.join('android', 'app')
if (!fs.existsSync(app)) { console.log('push-android: folder android/app belum ada, dilewati'); process.exit(0) }

const gs = path.join(app, 'google-services.json')
if (fs.existsSync(gs)) { fs.rmSync(gs); console.log('push-android: google-services.json lama dihapus (Firebase tidak dipakai)') }

const res = path.join(app, 'src', 'main', 'res')
fs.mkdirSync(path.join(res, 'drawable'), { recursive: true })
fs.mkdirSync(path.join(res, 'values'), { recursive: true })
fs.writeFileSync(path.join(res, 'drawable', 'ic_stat_wakuplay.xml'), `<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF" android:fillType="evenOdd" android:pathData="M5,4h14a3,3 0 0 1 3,3v10a3,3 0 0 1 -3,3H5a3,3 0 0 1 -3,-3V7a3,3 0 0 1 3,-3z M10,8.5v7l6,-3.5z"/>
</vector>
`)
fs.writeFileSync(path.join(res, 'values', 'wakuplay_notif.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="wakuplay_notif">#2F86FF</color>
</resources>
`)

const mf = path.join(app, 'src', 'main', 'AndroidManifest.xml')
if (fs.existsSync(mf)) {
  let m = fs.readFileSync(mf, 'utf8'); const before = m
  if (!m.includes('android.permission.POST_NOTIFICATIONS')) m = m.replace(/<application/, '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n\n    <application')
  m = m.replace(/[ \t]*<meta-data android:name="com\.google\.firebase\.messaging\.[^>]*\/>\r?\n/g, '')
  if (m !== before) { fs.writeFileSync(mf, m); console.log('push-android: AndroidManifest diperbarui') }
}
console.log('push-android: selesai (notifikasi lewat Supabase, tanpa Firebase)')
