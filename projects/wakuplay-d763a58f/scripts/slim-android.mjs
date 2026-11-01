import fs from 'node:fs'
import path from 'node:path'

const app = path.join('android', 'app')
const gradle = path.join(app, 'build.gradle')
if (!fs.existsSync(gradle)) { console.log('slim-android: android/app/build.gradle belum ada, dilewati'); process.exit(0) }
let g = fs.readFileSync(gradle, 'utf8')

if (!process.env.WP_SLIM) {
  const before = g
  g = g.replace(/\n[ \t]*debug \{\n[ \t]*\/\/ wakuplay-slim\n[ \t]*minifyEnabled true\n[ \t]*shrinkResources true\n[ \t]*proguardFiles [^\n]*\n[ \t]*\}/, '')
  g = g.replace(/\n[ \t]*\/\/ wakuplay-slim\n[ \t]*minifyEnabled true\n[ \t]*shrinkResources true\n[ \t]*proguardFiles [^\n]*/, '')
  if (g !== before) { fs.writeFileSync(gradle, g); console.log('slim-android: patch R8 lama dihapus (build jadi cepat lagi)') }
  else console.log('slim-android: R8 nonaktif (default)')
  process.exit(0)
}

const rules = path.join(app, 'proguard-rules.pro')
let r = fs.existsSync(rules) ? fs.readFileSync(rules, 'utf8') : ''
if (!r.includes('# WakuPlay slim')) {
  r += `
# WakuPlay slim
-keep class com.getcapacitor.** { *; }
-keep @com.getcapacitor.annotation.CapacitorPlugin public class * { @com.getcapacitor.annotation.PermissionCallback <methods>; @com.getcapacitor.PluginMethod <methods>; }
-keep class com.wakuplay.** { *; }
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn **
`
  fs.writeFileSync(rules, r)
}
if (!/wakuplay-slim/.test(g)) {
  const inject = `\n            // wakuplay-slim\n            minifyEnabled true\n            shrinkResources true\n            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'`
  if (/buildTypes\s*\{[\s\S]*?\bdebug\s*\{/.test(g)) g = g.replace(/(\bdebug\s*\{)/, `$1${inject}`)
  else if (/buildTypes\s*\{/.test(g)) g = g.replace(/(buildTypes\s*\{)/, `$1\n        debug {${inject}\n        }`)
  else { console.log('slim-android: blok buildTypes tidak ditemukan, dilewati'); process.exit(0) }
  fs.writeFileSync(gradle, g)
  console.log('slim-android: R8 + shrinkResources AKTIF (WP_SLIM=1)')
} else console.log('slim-android: sudah aktif')
