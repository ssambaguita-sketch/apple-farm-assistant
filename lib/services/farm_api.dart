import 'dart:convert';
import 'package:http/http.dart' as http;
class FarmApi{
  final String baseUrl;
  FarmApi({this.baseUrl='http://10.0.2.2:8000'});
  Future<Map<String,dynamic>> dashboard(String orchard) async{
    final u=Uri.parse('$baseUrl/api/dashboard').replace(queryParameters:{'orchard':orchard});
    final r=await http.get(u); if(r.statusCode!=200) throw Exception('대시보드 조회 실패');
    return Map<String,dynamic>.from(jsonDecode(r.body));
  }
  Future<List<dynamic>> orchards() async{
    final r=await http.get(Uri.parse('$baseUrl/api/orchards'));
    if(r.statusCode!=200) throw Exception('과수원 조회 실패'); return jsonDecode(r.body);
  }
  Future<Map<String,dynamic>> coach() async{
    final r=await http.get(Uri.parse('$baseUrl/api/coach'));
    if(r.statusCode!=200) throw Exception('코치 조회 실패'); return Map<String,dynamic>.from(jsonDecode(r.body));
  }
  Future<Map<String,dynamic>> survivorAdvice(Map<String,dynamic> data) async{
    final r=await http.post(Uri.parse('$baseUrl/api/weeds/survivor-advice'),
      headers:{'Content-Type':'application/json'},body:jsonEncode(data));
    if(r.statusCode!=200) throw Exception('잡초 조언 실패'); return Map<String,dynamic>.from(jsonDecode(r.body));
  }
}
