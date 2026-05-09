import 'dart:convert';
import 'dart:io';

void main() {
  final jsonStr = File('assets/service_access.json').readAsStringSync();
  final compact = jsonEncode(jsonDecode(jsonStr)); // minify to single line
  File('.env.secret').writeAsStringSync('FCM_SERVICE_ACCOUNT=$compact');
  print('✅ .env.secret written. Now run:');
  print('   supabase secrets set --env-file .env.secret');
  print('   Remove-Item .env.secret');
}
