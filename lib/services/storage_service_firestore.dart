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
      for (var i = 0; i < symbols.length; i++) {
        final docRef = _watchlistCollection.doc(symbols[i]);
        batch.set(docRef, {
          'symbol': symbols[i],
          'addedAt': FieldValue.serverTimestamp(),
          'sortOrder': i,
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
      // Fetch all and sort client-side rather than using orderBy('sortOrder'):
      // Firestore's orderBy excludes documents missing that field, which
      // would silently drop pre-existing watchlist entries created before
      // sortOrder was introduced. Docs without sortOrder fall back to
      // addedAt and sort after all explicitly-ordered docs.
      final snapshot = await _watchlistCollection.get();
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final orderA = dataA['sortOrder'] as int?;
          final orderB = dataB['sortOrder'] as int?;
          if (orderA != null && orderB != null) return orderA.compareTo(orderB);
          if (orderA != null) return -1;
          if (orderB != null) return 1;
          final addedAtA = dataA['addedAt'] as Timestamp?;
          final addedAtB = dataB['addedAt'] as Timestamp?;
          return (addedAtB ?? Timestamp(0, 0))
              .compareTo(addedAtA ?? Timestamp(0, 0));
        });

      return docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['symbol'] as String)
          .toList();
    } catch (e) {
      throw Exception('Failed to load watchlist: $e');
    }
  }

  @override
  Future<void> saveOrder(List<String> orderedSymbols) async {
    try {
      final batch = _firestore.batch();
      for (var i = 0; i < orderedSymbols.length; i++) {
        batch.update(_watchlistCollection.doc(orderedSymbols[i]), {
          'sortOrder': i,
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save order: $e');
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

      final existing = await _watchlistCollection.get();
      final maxOrder = existing.docs.fold<int>(-1, (max, d) {
        final data = d.data() as Map<String, dynamic>;
        final order = data['sortOrder'] as int? ?? -1;
        return order > max ? order : max;
      });

      await _watchlistCollection.doc(symbol).set({
        'symbol': symbol,
        'addedAt': FieldValue.serverTimestamp(),
        'sortOrder': maxOrder + 1,
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
