import '../services/supabase/supabase_service.dart' show rpc;
import '../repositories/library_repository.dart';
import '../services/anime/legacy_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/profile_repository.dart';
import '../services/anime/engine.dart';
import '../services/anime/legacy_adapter.dart';
import '../services/anime/sanka_adapter.dart';
import '../services/auth/auth_service.dart';
import '../services/supabase/supabase_service.dart';
import '../models/anime.dart';

final authProvider = Provider((_) => AuthService());
final profileRepoProvider = Provider((_) => ProfileRepository());

final animeEngineProvider = Provider((_) => AnimeEngine([
      LegacyAdapter(db),
      for (final s in ['animekompi', 'winbu', 'alqanime', 'donghub', 'nimegami']) SankaAdapter(s, db),
    ]));

final homeCatalogProvider = FutureProvider.autoDispose<CatalogResult>(
    (ref) => ref.read(animeEngineProvider).home());

final goldProvider = FutureProvider.autoDispose<num?>((ref) => ref.read(profileRepoProvider).myGold());

final libraryRepoProvider = Provider((_) => LibraryRepository());
final legacyApiProvider = Provider((_) => LegacyApi());
final favoritesProvider = FutureProvider.autoDispose((ref) => ref.read(libraryRepoProvider).favorites());
final historyProvider = FutureProvider.autoDispose((ref) => ref.read(libraryRepoProvider).history());

final legacyHomeProvider = FutureProvider.autoDispose((ref) => ref.read(legacyApiProvider).homeSections());
final scheduleProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
    (ref, day) => ref.read(legacyApiProvider).schedule(day));
final myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final u = ref.read(authProvider).user;
  return u == null ? Future.value(null) : ref.read(profileRepoProvider).myPublicProfile(u.id);
});

final genresProvider = FutureProvider.autoDispose((ref) => ref.read(legacyApiProvider).genres());
final rankingProvider = FutureProvider.autoDispose<List<(Anime, int)>>((ref) async {
  final rows = await rpc('top_anime_by_views', {'p_limit': 10});
  final api = ref.read(legacyApiProvider);
  final out = <(Anime, int)>[];
  final briefs = await Future.wait([for (final r in (rows as List)) api.brief('${r['id']}')]);
  for (var i = 0; i < briefs.length; i++) {
    final a = briefs[i];
    if (a != null) out.add((a, ((rows)[i]['views'] as num?)?.toInt() ?? 0));
  }
  return out;
});
