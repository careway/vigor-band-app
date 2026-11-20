package com.careway.vigor_app

import java.io.File

/** Logica pura (sin Android) extraida de BandClient/Agps/MainActivity para poder probarla con JUnit en la JVM. */
object Mac {
    /** Muestra solo los 2 ultimos bytes de una MAC (privacidad). */
    fun mask(m: String?): String = if (m == null || m.length < 5) "" else "••:••:••:••:" + m.takeLast(5)
}

object AgpsRules {
    const val MIN_BYTES = 1000L
    const val UNSUPPORTED_BACKOFF_MS = 24 * 3600_000L
    const val FRESH_MS = 20 * 3600_000L
    const val MAX_ATTEMPTS = 3

    /** El fichero descargado debe tener un tamano minimo y no ser una pagina de error (HTML/XML/JSON de texto). */
    fun looksValid(f: File): Boolean {
        if (!f.exists() || f.length() < MIN_BYTES) return false
        val head = ByteArray(64); val n = try { f.inputStream().use { it.read(head) } } catch (e: Exception) { return false }
        if (n <= 0) return false
        val t = String(head, 0, n, Charsets.ISO_8859_1).trimStart().lowercase()
        return !(t.startsWith("<") || t.startsWith("{") || t.startsWith("[") || t.startsWith("error") || t.contains("not found"))
    }

    /** Espera tras un fallo permanente (la pulsera no admite efemerides). */
    fun inBackoff(now: Long, nextTryAt: Long) = now < nextTryAt
    fun nextTryAfterUnsupported(now: Long) = now + UNSUPPORTED_BACKOFF_MS
    /** true = se reintenta (Result.retry); false = se da por hecho (success). attempt = runAttemptCount (0, 1, 2...). */
    fun shouldRetry(attempt: Int) = attempt < MAX_ATTEMPTS
    /** Hay un fichero valido y descargado hace menos de 20 h: no se vuelve a descargar. */
    fun isFresh(valid: Boolean, now: Long, downloadedAt: Long) = valid && now - downloadedAt < FRESH_MS
}

/**
 * M7/K3: peticiones de permisos simultaneas. Se lanzan de una en una; cada peticion se resuelve cuando se ha PREGUNTADO por todo lo que le falta
 * (true si lo tiene todo, false si se pregunto y no se concedio). Lo que una peticion pide y la anterior no preguntaba se solicita en la ronda siguiente.
 */
class PermissionQueue<R>(private val isGranted: (String) -> Boolean) {
    companion object { const val TIMEOUT_MS = 60_000L }
    /** H3: numero de ronda en curso; `expire(g)` solo actua si sigue siendo la misma ronda (un temporizador viejo no toca la nueva). */
    @get:Synchronized var generation = 0L; private set
    private class Entry<R>(val token: R, val perms: List<String>, val seen: MutableSet<String> = HashSet())
    private val waiting = ArrayList<Entry<R>>()
    /** H3: peticiones que al llegar ya no faltaban permisos (carrera): se entregan en la siguiente llamada a [drainLate]. */
    private val lateResolved = ArrayList<Pair<R, Boolean>>()
    @Synchronized fun drainLate(): List<Pair<R, Boolean>> { val r = ArrayList(lateResolved); lateResolved.clear(); return r }
    private var inFlight: Set<String>? = null
    class Round<R>(val resolved: List<Pair<R, Boolean>>, val next: List<String>?)

    private fun missing(e: Entry<R>) = e.perms.filter { !isGranted(it) }

    /** Devuelve los permisos a solicitar YA al sistema, o null si hay que esperar (ya hay una peticion en curso) o no falta nada. */
    @Synchronized fun add(token: R, perms: List<String>): List<String>? {
        val e = Entry(token, perms); waiting.add(e)
        val fl = inFlight
        if (fl != null) { e.seen.addAll(fl); return null }
        val m = missing(e).distinct()
        if (m.isEmpty()) { waiting.remove(e); lateResolved.add(e.token to true); return null }
        inFlight = m.toSet(); generation++; return m
    }

    /** Llamar desde onRequestPermissionsResult. Devuelve las peticiones resueltas y, si procede, la siguiente ronda de permisos. */
    @Synchronized fun onResult(): Round<R> {
        val asked = inFlight ?: emptySet(); inFlight = null
        val done = ArrayList<Pair<R, Boolean>>(); val keep = ArrayList<Entry<R>>()
        for (e in waiting) {
            e.seen.addAll(asked)
            val m = missing(e)
            if (m.isEmpty()) done.add(e.token to true)
            else if (e.seen.containsAll(m)) done.add(e.token to false)
            else keep.add(e)
        }
        waiting.clear(); waiting.addAll(keep)
        if (keep.isEmpty()) return Round(done, null)
        val next = keep.flatMap { e -> missing(e).filter { it !in e.seen } }.distinct()
        inFlight = next.toSet(); generation++
        return Round(done, next)
    }

    /** H3: el sistema no respondio a tiempo. Resuelve TODO lo pendiente (true si ya tiene todo, false si no) y libera la cola. */
    @Synchronized fun expire(gen: Long): Round<R> {
        if (inFlight == null || gen != generation) return Round(emptyList(), null)
        inFlight = null
        val done = ArrayList<Pair<R, Boolean>>(); for (e in waiting) done.add(e.token to missing(e).isEmpty())
        waiting.clear(); return Round(done, null)
    }
}

object AutoMeasureRules {
    const val MAX_INTERVAL_MIN = 240
    /** Intervalo (min) múltiplo del paso mínimo de la pulsera, entre ese paso y 240 min; si no es válido -> null. */
    fun safeInterval(req: Int, stepUnit: Int): Int? {
        if (stepUnit <= 0 || req < stepUnit || req > MAX_INTERVAL_MIN) return null
        return if (req % stepUnit == 0) req else null
    }
}

object HeartRules {
    const val MAX_MS = 70_000L
    /** La SDK documenta 20-300; 0 y valores fuera de un rango fisiologico razonable no se reenvian a la interfaz. */
    fun valid(v: Int) = v in 30..220
}

object UpdateRules {
    private val NAME = Regex("^[A-Za-z0-9._-]{1,64}\\.apk$")
    /** Solo se instala un APK que la propia app descargo en su carpeta de actualizaciones: nombre simple, sin rutas. */
    fun safeName(n: String?) = n != null && NAME.matches(n) && !n.contains("..")
    /** El APK debe ser de este paquete y de una version mayor que la instalada. */
    fun acceptable(ownPkg: String, pkg: String?, installed: Long, candidate: Long) = pkg == ownPkg && candidate > installed
}
