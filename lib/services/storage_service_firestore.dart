import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

/// Firestore implementation of StorageService
/// Stores watchlist data in Firebase Firestore for cross-device sync
class StorageServiceFirestore implements StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  StorageServiceFirestore(this.userId);

  /// Collection reference for user's watchlist
  CollectionReference get _watchlistCollection =>
      _firestore.collection('users').doc(userId).collection('watchlist');

  @override
  Future<void> init() async {
    // Firestore doesn't require initialization
  }

  @override
  Future<void> saveWatchlist(List<String> symbols) async {
    try {
      final batch = _firestore.batch();

      // Delete all existing watchlist items
      final existing = await _watchlistCollection.get();
      for (var doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // Add new watchlist items
      for (var symbol in symbols) {
        final docRef = _watchlistCollection.doc(symbol);
        batch.set(docRef, {
          'symbol': symbol,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save watchlist: $e');
    }
  }

  @override
  Future<List<String>> loadWatchlist() async {
    try {
      final snapshot = await _watchlistCollection
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['symbol'] as String)
          .toList();
    } catch (e) {
      throw Exception('Failed to load watchlist: $e');
    }
  }

  @override
  Future<bool> addToWatchlist(String symbol) async {
    try {
      // Check if already exists
      final doc = await _watchlistCollection.doc(symbol).get();
      if (doc.exists) {
        return false;
      }

      await _watchlistCollection.doc(symbol).set({
        'symbol': symbol,
        'addedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      throw Exception('Failed to add to watchlist: $e');
    }
  }

  @override
  Future<bool> removeFromWatchlist(String symbol) async {
    try {
      final doc = await _watchlistCollection.doc(symbol).get();
      if (!doc.exists) {
        return false;
      }

      await _watchlistCollection.doc(symbol).delete();
      return true;
    } catch (e) {
      throw Exception('Failed to remove from watchlist: $e');
    }
  }

  @override
  Future<bool> isInWatchlist(String symbol) async {
    try {
      final doc = await _watchlistCollection.doc(symbol).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> clearWatchlist() async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _watchlistCollection.get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear watchlist: $e');
    }
  }

  @override
  Future<int> getWatchlistCount() async {
    try {
      final snapshot = await _watchlistCollection.get();
      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }
}
