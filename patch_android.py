import re, pathlib
m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = m.read_text(encoding='utf-8')
perms = ('<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
         '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n')
recv = '''
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
  </intent-filter>
</receiver>
'''
s = s.replace('<application', perms + '<application', 1)
s = s.replace('</application>', recv + '</application>', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="السيستم"', s, count=1)
m.write_text(s, encoding='utf-8')

for name in ('build.gradle.kts', 'build.gradle'):
    p = pathlib.Path('android/app') / name
    if p.exists():
        break
g = p.read_text(encoding='utf-8')
if name.endswith('.kts'):
    g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
else:
    g = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', g, count=1)
    g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
p.write_text(g, encoding='utf-8')
