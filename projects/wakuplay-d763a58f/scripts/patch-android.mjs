import fs from 'node:fs'
import path from 'node:path'

const res = path.join('android', 'app', 'src', 'main', 'res', 'values')
if (!fs.existsSync(res)) { console.log('patch-android: folder android belum ada, dilewati'); process.exit(0) }

fs.writeFileSync(path.join(res, 'wp_colors.xml'), '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="wp_bg">#111214</color>\n</resources>\n')

const f = path.join(res, 'styles.xml')
if (!fs.existsSync(f)) { console.log('patch-android: styles.xml tidak ada, dilewati'); process.exit(0) }
let x = fs.readFileSync(f, 'utf8')
const addItems = (name, items) => {
  const re = new RegExp(`(<style name="${name.replace('.', '\\.')}"[^>]*>)([\\s\\S]*?)(</style>)`)
  x = x.replace(re, (m, open, body, close) => {
    let b = body
    for (const [attr, val] of items) {
      const itemRe = new RegExp(`\\s*<item name="${attr}">[^<]*</item>`)
      b = b.replace(itemRe, '')
      b += `\n        <item name="${attr}">${val}</item>`
    }
    return open + b + '\n    ' + close
  })
}
const common = [['android:windowBackground', '@color/wp_bg'], ['android:colorBackground', '@color/wp_bg']]
addItems('AppTheme.NoActionBar', common)
const launch = [['android:background', '@color/wp_bg'], ['android:windowBackground', '@color/wp_bg']]
if (/<style name="AppTheme\.NoActionBarLaunch"[^>]*parent="Theme\.SplashScreen/.test(x)) launch.push(['windowSplashScreenBackground', '@color/wp_bg'])
addItems('AppTheme.NoActionBarLaunch', launch)
fs.writeFileSync(f, x)
console.log('patch-android: tema layar awal disesuaikan (#111214)')

const mf = path.join('android', 'app', 'src', 'main', 'AndroidManifest.xml')
if (fs.existsSync(mf)) {
  let m = fs.readFileSync(mf, 'utf8')
  if (!m.includes('android.permission.POST_NOTIFICATIONS')) {
    m = m.replace('</manifest>', '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n</manifest>')
    fs.writeFileSync(mf, m)
    console.log('patch-android: izin notifikasi ditambahkan')
  }
}
