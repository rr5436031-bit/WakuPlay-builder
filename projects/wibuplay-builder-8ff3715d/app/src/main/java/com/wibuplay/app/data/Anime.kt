package com.wibuplay.app.data

import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener

// ───────────────────────── Model ─────────────────────────

data class AnimeItem(
    val source: String,
    val slug: String,
    val title: String,
    val cover: String? = null,
    val badge: String? = null,
    val episodeLabel: String? = null,
    val score: String? = null,
    val views: String? = null,
    val extra: String? = null,
) {
    val key: String get() = "$source:$slug"
}

data class StreamLink(
    val label: String,
    val url: String,
    val direct: Boolean,
    val lazy: Map<String, String>? = null,
)

data class EpisodeItem(
    val id: String,
    val title: String,
    val number: String?,
    val inline: List<StreamLink>,
)

data class AnimeDetail(
    val key: String,
    val source: String,
    val slug: String,
    val title: String,
    val cover: String?,
    val synopsis: String?,
    val genres: List<String>,
    val status: String?,
    val meta: List<Pair<String, String>>,
    val episodes: List<EpisodeItem>,
)

data class GenreItem(val name: String, val slug: String)
data class Section(val title: String, val items: List<AnimeItem>)
data class ScheduleEntry(val item: AnimeItem, val time: String?)
data class ScheduleDay(val day: String, val entries: List<ScheduleEntry>)

// ───────────────────────── Sumber & endpoint ─────────────────────────
// Semua path di bawah diambil dari sanka-endpoints.js (tidak ada endpoint karangan).

enum class Feature {
    HOME, LATEST, POPULAR, ONGOING, COMPLETED, MOVIE, DONGHUA, LIVE,
    SEARCH, GENRES, GENRE, SCHEDULE, SEASONS, SEASON, AZ, DETAIL, EPISODE, SERVER,
}

class Source(
    val id: String,
    val label: String,
    val paths: Map<Feature, String>,
    val detailAlternates: List<String> = emptyList(),
    val fallbackGenres: List<GenreItem> = emptyList(),
)

object Sources {
    private const val W = "/anime/winbu"
    private const val K = "/anime/animekompi"
    private const val D = "/anime/donghub"
    private const val A = "/anime/alqanime"
    private const val N = "/anime/nimegami"

    private fun g(vararg names: String) = names.map { GenreItem(it, it.lowercase().replace(' ', '-')) }

    val winbu = Source(
        "winbu", "Winbu",
        mapOf(
            Feature.HOME to "$W/home", Feature.LATEST to "$W/latest", Feature.POPULAR to "$W/populer",
            Feature.ONGOING to "$W/ongoing", Feature.COMPLETED to "$W/completed", Feature.MOVIE to "$W/film",
            Feature.DONGHUA to "$W/animedonghua", Feature.LIVE to "$W/series",
            Feature.SEARCH to "$W/search?q={q}", Feature.GENRES to "$W/genres", Feature.GENRE to "$W/genre/{slug}",
            Feature.SCHEDULE to "$W/schedule?day=all", Feature.AZ to "$W/all-anime",
            Feature.DETAIL to "$W/anime/{slug}", Feature.EPISODE to "$W/episode/{slug}",
            Feature.SERVER to "$W/server?post={post}&nume={nume}&type={type}",
        ),
        detailAlternates = listOf("$W/film/{slug}", "$W/series/{slug}"),
    )

    val animekompi = Source(
        "animekompi", "Animekompi",
        mapOf(
            Feature.HOME to "$K/home", Feature.LATEST to "$K/terbaru", Feature.POPULAR to "$K/order/popular",
            Feature.ONGOING to "$K/status/ongoing", Feature.COMPLETED to "$K/status/completed",
            Feature.MOVIE to "$K/movie", Feature.DONGHUA to "$K/donghua", Feature.LIVE to "$K/live-action",
            Feature.SEARCH to "$K/search?q={q}", Feature.GENRES to "$K/genres", Feature.GENRE to "$K/genre/{slug}",
            Feature.SCHEDULE to "$K/schedule", Feature.SEASONS to "$K/seasons", Feature.SEASON to "$K/season/{slug}",
            Feature.AZ to "$K/az?letter=A", Feature.DETAIL to "$K/detail/{slug}", Feature.EPISODE to "$K/episode/{slug}",
        ),
    )

    val donghub = Source(
        "donghub", "Donghub",
        mapOf(
            Feature.HOME to "$D/home", Feature.LATEST to "$D/latest", Feature.POPULAR to "$D/popular",
            Feature.MOVIE to "$D/movie", Feature.DONGHUA to "$D/latest",
            Feature.SEARCH to "$D/search/{q}", Feature.GENRE to "$D/genre/{slug}",
            Feature.SCHEDULE to "$D/schedule", Feature.DETAIL to "$D/detail/{slug}", Feature.EPISODE to "$D/episode/{slug}",
        ),
        // donghub tidak punya endpoint daftar genre; slug berikut hanya dipakai ke endpoint genre/:slug
        fallbackGenres = g("Action", "Adventure", "Comedy", "Fantasy", "Martial Arts", "Romance", "Supernatural"),
    )

    val alqanime = Source(
        "alqanime", "Alqanime",
        mapOf(
            Feature.HOME to "$A/home", Feature.LATEST to "$A/home", Feature.POPULAR to "$A/popular",
            Feature.ONGOING to "$A/ongoing", Feature.COMPLETED to "$A/completed", Feature.MOVIE to "$A/movie",
            Feature.SEARCH to "$A/search/{q}", Feature.GENRES to "$A/genres", Feature.GENRE to "$A/genre/{slug}",
            Feature.SCHEDULE to "$A/schedule", Feature.SEASON to "$A/season/{slug}", Feature.AZ to "$A/list?show=A",
            Feature.DETAIL to "$A/detail/{slug}",
        ),
    )

    val nimegami = Source(
        "nimegami", "Nimegami",
        mapOf(
            Feature.HOME to "$N/home", Feature.LATEST to "$N/home", Feature.LIVE to "$N/live-action",
            Feature.SEARCH to "$N/search/{q}", Feature.GENRES to "$N/genre/list", Feature.GENRE to "$N/genre/{slug}",
            Feature.SEASONS to "$N/seasons/list", Feature.SEASON to "$N/seasons/{slug}", Feature.AZ to "$N/anime-list",
            Feature.DETAIL to "$N/detail/{slug}",
        ),
        detailAlternates = listOf("$N/live-action/{slug}", "$N/drama/{slug}"),
    )

    val all = listOf(winbu, animekompi, donghub, alqanime, nimegami)
    fun byId(id: String): Source = all.firstOrNull { it.id == id } ?: winbu
}

// ───────────────────────── Normalisasi respons ─────────────────────────
// Format respons tiap sumber berbeda dan belum terverifikasi dari sandbox ini.
// Adapter membaca JSON secara toleran (nama kunci umum), tidak mengasumsikan satu format.

object Norm {
    private val TITLE = listOf("title", "name", "judul", "anime_title", "animeTitle")
    private val SLUG = listOf("slug", "id", "endpoint", "anime_id", "animeId", "url", "link", "href")
    private val COVER = listOf("poster", "image", "img", "cover", "thumbnail", "thumb", "image_url", "poster_url", "imageUrl", "cover_url")
    private val EPS = listOf("episode", "eps", "episodes", "latest_episode", "episode_text", "current_episode", "last_episode", "total_episode")
    private val SCORE = listOf("score", "rating", "rate")
    private val VIEWS = listOf("views", "view", "viewers")
    private val TYPE = listOf("type", "kind", "status")
    private val TIME = listOf("time", "jam", "release_time", "airing_time", "date")
    private val SYNOPSIS = listOf("synopsis", "sinopsis", "description", "desc", "deskripsi", "overview")

    fun parse(text: String): Any? = JSONTokener(text.trim()).nextValue()

    fun prim(o: JSONObject, keys: List<String>): String? {
        val map = HashMap<String, String>()
        val it = o.keys()
        while (it.hasNext()) {
            val k = it.next()
            map[k.lowercase()] = k
        }
        for (k in keys) {
            val real = map[k.lowercase()] ?: continue
            val v = o.opt(real)
            if (v is String && v.isNotBlank()) return v.trim()
            if (v is Number) return v.toString()
        }
        return null
    }

    private fun slugFrom(raw: String): String? {
        val s = raw.substringBefore('#').substringBefore('?').trimEnd('/')
        val last = s.substringAfterLast('/')
        return last.ifBlank { null }
    }

    fun toAnime(source: String, o: JSONObject): AnimeItem? {
        val title = prim(o, TITLE) ?: return null
        val slug = slugFrom(prim(o, SLUG) ?: return null) ?: return null
        var cover = prim(o, COVER)
        if (cover == null) {
            for (k in COVER) {
                val nested = o.optJSONObject(k) ?: continue
                cover = prim(nested, listOf("url", "src"))
                if (cover != null) break
            }
        }
        if (cover != null && cover.startsWith("//")) cover = "https:$cover"
        return AnimeItem(
            source = source, slug = slug, title = title, cover = cover,
            episodeLabel = prim(o, EPS)?.let { if (it.all { c -> c.isDigit() }) "Eps $it" else it },
            score = prim(o, SCORE), views = prim(o, VIEWS), extra = prim(o, TYPE),
        )
    }

    /** Semua array berisi objek, dengan nama kunci induknya. */
    fun arrays(root: Any?, maxDepth: Int = 4): List<Pair<String, JSONArray>> {
        val out = ArrayList<Pair<String, JSONArray>>()
        fun walk(n: Any?, key: String, depth: Int) {
            if (depth > maxDepth) return
            if (n is JSONObject) {
                val it = n.keys()
                while (it.hasNext()) {
                    val k = it.next()
                    walk(n.opt(k), k, depth + 1)
                }
            } else if (n is JSONArray) {
                if (n.length() > 0 && n.optJSONObject(0) != null) out.add(key to n)
            }
        }
        walk(root, "root", 0)
        return out
    }

    fun pretty(key: String): String =
        key.replace('_', ' ').replace('-', ' ').trim().replaceFirstChar { it.uppercase() }

    fun sections(source: String, root: Any?): List<Section> {
        val out = ArrayList<Section>()
        for ((k, arr) in arrays(root)) {
            val items = ArrayList<AnimeItem>()
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                toAnime(source, o)?.let { items.add(it) }
            }
            if (items.isNotEmpty()) out.add(Section(pretty(k), items))
        }
        return out
    }

    /** Daftar utama: array dengan item terbanyak. */
    fun mainList(source: String, root: Any?): List<AnimeItem> =
        sections(source, root).maxByOrNull { it.items.size }?.items ?: emptyList()

    fun genres(root: Any?): List<GenreItem> {
        val out = ArrayList<GenreItem>()
        fun add(name: String?, slugRaw: String?) {
            if (name.isNullOrBlank()) return
            val slug = slugFrom(slugRaw ?: name.lowercase().replace(' ', '-')) ?: return
            if (out.none { it.slug == slug }) out.add(GenreItem(name, slug))
        }
        fun scan(arr: JSONArray) {
            for (i in 0 until arr.length()) {
                val v = arr.opt(i)
                if (v is String) add(v, null)
                else if (v is JSONObject) add(prim(v, listOf("name", "title", "genre", "label")), prim(v, listOf("slug", "id", "endpoint", "url", "link", "href")))
            }
        }
        fun walk(n: Any?, depth: Int) {
            if (depth > 4 || out.isNotEmpty()) return
            if (n is JSONArray) {
                if (n.length() > 0 && (n.opt(0) is String || n.optJSONObject(0) != null)) scan(n)
            } else if (n is JSONObject) {
                val it = n.keys()
                while (it.hasNext()) walk(n.opt(it.next()), depth + 1)
            }
        }
        walk(root, 0)
        return out
    }

    fun detail(source: String, slug: String, root: Any?): AnimeDetail {
        var obj: JSONObject = (root as? JSONObject) ?: JSONObject()
        obj.optJSONObject("data")?.let { obj = it }
        val title = prim(obj, TITLE) ?: slug
        val cover = prim(obj, COVER)?.let { if (it.startsWith("//")) "https:$it" else it }
        val synopsis = prim(obj, SYNOPSIS)
        val status = prim(obj, listOf("status"))

        val genres = ArrayList<String>()
        for (k in listOf("genre", "genres")) {
            val a = obj.optJSONArray(k) ?: continue
            for (i in 0 until a.length()) {
                val v = a.opt(i)
                if (v is String) genres.add(v)
                else if (v is JSONObject) prim(v, listOf("name", "title", "genre"))?.let { genres.add(it) }
            }
        }

        val meta = ArrayList<Pair<String, String>>()
        for (k in listOf("type", "studio", "season", "duration", "released", "score", "rating", "producer", "total_episode")) {
            prim(obj, listOf(k))?.let { meta.add(pretty(k) to it) }
        }

        // Cari daftar episode: utamakan kunci bernama episode/eps, lainnya array terbesar
        val skip = Regex("genre|related|recommend|batch|download|similar|popular|latest_anime", RegexOption.IGNORE_CASE)
        val candidates = arrays(obj).filter { !skip.containsMatchIn(it.first) }
        val epArr = candidates.firstOrNull { Regex("episode|eps|chapter", RegexOption.IGNORE_CASE).containsMatchIn(it.first) }?.second
            ?: candidates.maxByOrNull { it.second.length() }?.second
        val episodes = ArrayList<EpisodeItem>()
        if (epArr != null) {
            for (i in 0 until epArr.length()) {
                val e = epArr.optJSONObject(i) ?: continue
                val rawId = prim(e, listOf("slug", "id", "endpoint", "episode_id", "url", "link", "href")) ?: continue
                val id = slugFrom(rawId) ?: continue
                val num = prim(e, listOf("number", "episode", "eps", "ep", "no"))
                val title2 = prim(e, listOf("title", "name", "episode", "eps")) ?: "Episode ${num ?: (i + 1)}"
                episodes.add(EpisodeItem(id, title2, num, collectLinks(e, relaxed = false)))
            }
        }
        return AnimeDetail("$source:$slug", source, slug, title, cover, synopsis, genres, status, meta, episodes)
    }

    // ── stream ──
    private val STREAM_KEY = Regex("stream|embed|iframe|player|mirror|source|server|video|watch|play", RegexOption.IGNORE_CASE)
    private val BAD_KEY = Regex("download|thumb|image|img|poster|cover|banner|avatar|next|prev|slug|endpoint|anime|batch|comment|danmaku|reaction", RegexOption.IGNORE_CASE)
    private val IMG_EXT = Regex("\\.(jpe?g|png|gif|webp|svg|ico)(\\?.*)?$", RegexOption.IGNORE_CASE)
    private val DIRECT_EXT = Regex("\\.(mp4|m3u8|webm|mpd)(\\?.*)?$", RegexOption.IGNORE_CASE)
    private val IFRAME_SRC = Regex("src=[\"']([^\"']+)[\"']", RegexOption.IGNORE_CASE)

    fun isDirect(url: String) = DIRECT_EXT.containsMatchIn(url)

    /** Kumpulkan tautan streaming dari objek JSON apa pun. relaxed=true menerima semua URL non-gambar. */
    fun collectLinks(root: Any?, relaxed: Boolean): List<StreamLink> {
        val out = ArrayList<StreamLink>()
        val seen = HashSet<String>()
        fun addUrl(raw: String, label: String) {
            var u = raw.trim()
            if (u.startsWith("//")) u = "https:$u"
            if (!u.startsWith("http") || IMG_EXT.containsMatchIn(u) || !seen.add(u)) return
            out.add(StreamLink(label, u, isDirect(u)))
        }
        fun walk(n: Any?, key: String, parent: String, label: String, depth: Int) {
            if (depth > 6) return
            when (n) {
                is JSONObject -> {
                    // Objek pemilih server (post/nume/type) -> diselesaikan lazy lewat endpoint server
                    val post = prim(n, listOf("post"))
                    val nume = prim(n, listOf("nume"))
                    if (post != null && nume != null) {
                        val type = prim(n, listOf("type")) ?: "schtml"
                        val lb = prim(n, listOf("name", "server", "title", "label")) ?: "Server $nume"
                        out.add(StreamLink(lb, "", false, mapOf("post" to post, "nume" to nume, "type" to type)))
                    }
                    val lb2 = prim(n, listOf("name", "server", "label", "title", "quality", "provider")) ?: label
                    val it = n.keys()
                    while (it.hasNext()) {
                        val k = it.next()
                        walk(n.opt(k), k, key, lb2, depth + 1)
                    }
                }
                is JSONArray -> for (i in 0 until n.length()) walk(n.opt(i), key, parent, label, depth + 1)
                is String -> {
                    val ctxOk = relaxed || (STREAM_KEY.containsMatchIn("$parent.$key") &&
                        !BAD_KEY.containsMatchIn(key) && !BAD_KEY.containsMatchIn(parent))
                    if (!ctxOk) return
                    if (n.contains("<iframe", ignoreCase = true)) {
                        IFRAME_SRC.findAll(n).forEach { m -> addUrl(m.groupValues[1], label.ifBlank { key }) }
                    } else addUrl(n, label.ifBlank { key })
                }
                else -> {}
            }
        }
        walk(root, "root", "root", "", 0)
        // Beri nomor pada label kembar
        val counts = HashMap<String, Int>()
        return out.map {
            val c = (counts[it.label] ?: 0) + 1
            counts[it.label] = c
            if (c > 1) it.copy(label = "${it.label} $c") else it
        }
    }

    // ── jadwal ──
    fun schedule(source: String, root: Any?): List<ScheduleDay> {
        val base: Any? = (root as? JSONObject)?.opt("data") ?: root
        fun entries(arr: JSONArray?): List<ScheduleEntry> {
            val out = ArrayList<ScheduleEntry>()
            if (arr == null) return out
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val item = toAnime(source, o) ?: continue
                out.add(ScheduleEntry(item, prim(o, TIME)))
            }
            return out
        }
        val days = ArrayList<ScheduleDay>()
        val dayWords = Regex("senin|selasa|rabu|kamis|jumat|jum'at|sabtu|minggu|ahad|monday|tuesday|wednesday|thursday|friday|saturday|sunday", RegexOption.IGNORE_CASE)
        if (base is JSONObject) {
            val it = base.keys()
            while (it.hasNext()) {
                val k = it.next()
                val v = base.opt(k)
                if (v is JSONArray && dayWords.containsMatchIn(k)) {
                    days.add(ScheduleDay(pretty(k), entries(v)))
                } else if (v is JSONObject) {
                    // bentuk { jadwal: { senin: [...] } }
                    val it2 = v.keys()
                    while (it2.hasNext()) {
                        val k2 = it2.next()
                        val v2 = v.opt(k2)
                        if (v2 is JSONArray && dayWords.containsMatchIn(k2)) days.add(ScheduleDay(pretty(k2), entries(v2)))
                    }
                }
            }
        }
        if (days.isEmpty()) {
            // bentuk [ {day:"Senin", anime:[...]} ]
            for ((_, arr) in arrays(base)) {
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    val day = prim(o, listOf("day", "hari", "name", "title")) ?: continue
                    if (!dayWords.containsMatchIn(day)) continue
                    val inner = arrays(o).maxByOrNull { it.second.length() }?.second
                    days.add(ScheduleDay(pretty(day), entries(inner)))
                }
                if (days.isNotEmpty()) break
            }
        }
        if (days.isEmpty()) {
            val flat = mainList(source, base)
            if (flat.isNotEmpty()) days.add(ScheduleDay("Semua", flat.map { ScheduleEntry(it, null) }))
        }
        return days.filter { it.entries.isNotEmpty() }
    }

    /** Ringkasan struktur untuk layar diagnostik. */
    fun describe(root: Any?): String {
        val sb = StringBuilder()
        if (root is JSONObject) {
            val keys = ArrayList<String>()
            val it = root.keys()
            while (it.hasNext()) keys.add(it.next())
            sb.append("kunci: ").append(keys.take(8).joinToString(","))
        } else if (root is JSONArray) sb.append("array[${root.length()}]")
        return sb.toString()
    }
}

// ───────────────────────── Repository ─────────────────────────

class UnsupportedFeature(label: String) : Exception("Fitur ini tidak tersedia di sumber $label")

class AnimeRepository {
    private val cache = object : LinkedHashMap<String, Pair<Long, String>>(64, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Pair<Long, String>>?): Boolean = size > 60
    }

    private suspend fun fetch(path: String, ttlMs: Long = 5 * 60_000L): Any? {
        val now = System.currentTimeMillis()
        synchronized(cache) {
            val hit = cache[path]
            if (hit != null && now - hit.first < ttlMs) return Norm.parse(hit.second)
        }
        val token = Graph.auth.validToken() ?: throw ApiException(401, "Sesi berakhir, silakan login lagi")
        val text = httpGetText(
            AppConfig.FUNCTIONS_URL + "/anime?path=" + Uri.encode(path),
            mapOf("apikey" to AppConfig.SUPABASE_KEY, "Authorization" to "Bearer $token"),
        )
        synchronized(cache) { cache[path] = now to text }
        return Norm.parse(text)
    }

    private fun build(src: Source, f: Feature, slug: String? = null, q: String? = null, page: Int = 1): String {
        var p = src.paths[f] ?: throw UnsupportedFeature(src.label)
        if (slug != null) p = p.replace("{slug}", Uri.encode(slug))
        if (q != null) p = p.replace("{q}", Uri.encode(q))
        if (page > 1) p += (if ('?' in p) "&" else "?") + "page=$page"
        return p
    }

    suspend fun list(src: Source, f: Feature, page: Int = 1, slug: String? = null, q: String? = null): List<AnimeItem> =
        Norm.mainList(src.id, fetch(build(src, f, slug, q, page)))

    suspend fun home(src: Source): List<Section> = Norm.sections(src.id, fetch(build(src, Feature.HOME)))

    suspend fun genres(src: Source): List<GenreItem> {
        if (src.paths[Feature.GENRES] == null) return src.fallbackGenres
        val g = Norm.genres(fetch(build(src, Feature.GENRES), 30 * 60_000L))
        return g.ifEmpty { src.fallbackGenres }
    }

    suspend fun schedule(src: Source): List<ScheduleDay> =
        Norm.schedule(src.id, fetch(build(src, Feature.SCHEDULE), 15 * 60_000L))

    suspend fun detail(key: String): AnimeDetail {
        val src = Sources.byId(key.substringBefore(':'))
        val slug = key.substringAfter(':')
        val main = src.paths[Feature.DETAIL] ?: throw UnsupportedFeature(src.label)
        val templates = listOf(main) + src.detailAlternates
        var last: Exception? = null
        for (t in templates) {
            try {
                val d = Norm.detail(src.id, slug, fetch(t.replace("{slug}", Uri.encode(slug))))
                if (d.episodes.isNotEmpty() || t == templates.last() || d.synopsis != null) return d
            } catch (e: Exception) {
                last = e
            }
        }
        throw last ?: ApiException(0, "Detail tidak ditemukan")
    }

    suspend fun streams(src: Source, ep: EpisodeItem): List<StreamLink> {
        val fromEndpoint = if (src.paths[Feature.EPISODE] != null) {
            Norm.collectLinks(fetch(build(src, Feature.EPISODE, ep.id), 2 * 60_000L), relaxed = false)
        } else emptyList()
        val all = (fromEndpoint + ep.inline).distinctBy { it.url.ifEmpty { it.lazy.toString() } }
        return all.sortedByDescending { it.direct }
    }

    suspend fun resolve(src: Source, link: StreamLink): List<StreamLink> {
        val lz = link.lazy ?: return listOf(link)
        val tpl = src.paths[Feature.SERVER] ?: throw UnsupportedFeature(src.label)
        val path = tpl.replace("{post}", Uri.encode(lz["post"] ?: ""))
            .replace("{nume}", Uri.encode(lz["nume"] ?: ""))
            .replace("{type}", Uri.encode(lz["type"] ?: ""))
        return Norm.collectLinks(fetch(path, 60_000L), relaxed = true).map { it.copy(label = link.label) }
    }

    /** Untuk layar diagnostik: uji endpoint HOME & LATEST tiap sumber. */
    suspend fun probe(src: Source): String {
        val sb = StringBuilder()
        for (f in listOf(Feature.HOME, Feature.LATEST, Feature.DETAIL)) {
            val path = src.paths[f] ?: continue
            if (f == Feature.DETAIL) continue
            try {
                val root = fetch(path, 0L)
                val secs = Norm.sections(src.id, root)
                sb.append("✔ ${f.name}: ${Norm.describe(root)} | ${secs.size} daftar, ")
                    .append(secs.joinToString { "${it.title}(${it.items.size})" }.take(120)).append('\n')
            } catch (e: Exception) {
                sb.append("✘ ${f.name}: ${e.userMessage()}\n")
            }
        }
        return sb.toString().trim()
    }
}
