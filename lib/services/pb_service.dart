import 'package:pocketbase/pocketbase.dart';

/// Service to handle PocketBase connections and operations
class PbService {
  PbService._();
  static final PbService _instance = PbService._();
  static PbService get instance => _instance;

  final PocketBase pb = PocketBase('http://145.223.21.62:8090');

  // You can add more methods here for common PocketBase operations
}
