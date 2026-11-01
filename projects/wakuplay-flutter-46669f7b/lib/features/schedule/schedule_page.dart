import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../models/anime.dart';
import '../detail/detail_page.dart';

const _days = [['MONDAY', 'Senin'], ['TUESDAY', 'Selasa'], ['WEDNESDAY', 'Rabu'], ['THURSDAY', 'Kamis'], ['FRIDAY', 'Jumat'], ['SATURDAY', 'Sabtu'], ['SUNDAY', 'Minggu']];

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});
  @override
  ConsumerState<SchedulePage> createState() => _S();
}

class _S extends ConsumerState<SchedulePage> {
  int day = (DateTime.now().weekday - 1) % 7;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(scheduleProvider(_days[day][0]));
    return SafeArea(
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(14), child: Text('Jadwal Tayang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        SizedBox(height: 40, child: ListView.separated(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => setState(() => day = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18), alignment: Alignment.center,
              decoration: BoxDecoration(color: i == day ? C.pillBlue : C.surface, borderRadius: BorderRadius.circular(20)),
              child: Text(_days[i][1], style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        )),
        Expanded(child: s.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) => rows.isEmpty
              ? const Center(child: Text('Belum ada jadwal', style: TextStyle(color: C.textDim)))
              : ListView.builder(
                  padding: const EdgeInsets.all(14), itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final a = rows[i]['anime'] as Anime;
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(anime: a))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: C.scheduleCard, borderRadius: BorderRadius.circular(16),
                            border: const Border(left: BorderSide(color: C.scheduleAccent, width: 3))),
                        child: Row(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 62, height: 88,
                              child: a.poster == null ? Container(color: C.surface) : CachedNetworkImage(imageUrl: a.poster!, fit: BoxFit.cover, memCacheWidth: 200))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${rows[i]['time']}', style: const TextStyle(color: C.scheduleAccent, fontWeight: FontWeight.w700, fontSize: 12)),
                            Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (rows[i]['episode'] != null) Text('Episode ${rows[i]['episode']}', style: const TextStyle(color: C.textDim, fontSize: 12)),
                          ])),
                        ]),
                      ),
                    );
                  }),
        )),
      ]),
    );
  }
}
