import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class PremiumService {
  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://balance-apps-991c6-default-rtdb.asia-southeast1.firebasedatabase.app",
  );

  static final DatabaseReference _db = _database.ref();

  static bool _cachePremium = false;

  static bool get cachedPremium => _cachePremium;

  static Future<bool> isPremium() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _cachePremium = false;
      return false;
    }

    final snapshot = await _db.child("users/${user.uid}/premium/remove_ads").get();

    _cachePremium = snapshot.value == true;

    return _cachePremium;
  }

  static Future<void> setPremium({required String purchaseToken}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await _db.child("users/${user.uid}/premium").update({
      "remove_ads": true,
      "product_id": "remove_ads",
      "purchase_token": purchaseToken,
      "purchase_time": ServerValue.timestamp,
    });

    _cachePremium = true;
  }

  static void reset() {
    _cachePremium = false;
  }
}
