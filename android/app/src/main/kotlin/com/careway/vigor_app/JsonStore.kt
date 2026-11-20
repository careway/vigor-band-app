package com.careway.vigor_app

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.Calendar

/**
 * Almacén local simple: un fichero JSON por "tipo" (clave -> objeto). Se sobrescribe por clave, así que re-sincronizar no duplica.
 * - Un fichero corrupto NO se sobrescribe: se renombra a `<kind>.corrupt-<timestamp>` y se empieza vacío.
 * - Escritura atómica (tmp + fsync + rename) comprobando el resultado.
 * - Retención: series densas (origin5/hrv/spo2/half/live) 60 días; sports/sportItems/sleep, tope de entradas.
 */
class JsonStore(private val dir: File, private val now: () -> Long = { System.currentTimeMillis() }) {
    private val cache = HashMap<String, JSONObject>()
    private val writeLock = Any()
    /** H1: generacion (se incrementa en cada wipe) y estado 'wiping'. Un flush serializado antes de un wipe no escribe tras el (gen distinta). */
    @Volatile private var gen = 0L
    @Volatile var wiping = false; private set
    /** Solo pruebas: se invoca entre la serializacion y la escritura de flush. */
    @Volatile internal var beforeWrite: (() -> Unit)? = null
    init { dir.mkdirs(); purgeCorrupt() }

    /** N8: los `<kind>.corrupt-<ms>` de mas de 30 dias se eliminan (nunca los de fecha futura/ilegible). */
    private fun purgeCorrupt() {
        val limit = now() - CORRUPT_KEEP_DAYS * 86_400_000L
        dir.listFiles()?.forEach { f ->
            val i = f.name.indexOf(".corrupt-"); if (i < 0) return@forEach
            val ts = f.name.substring(i + 9).toLongOrNull() ?: return@forEach
            if (ts < limit) f.delete()
        }
    }

    companion object {
        val RETENTION_DAYS = mapOf("origin5" to 60, "hrv" to 60, "spo2" to 60, "half" to 60, "live" to 60)
        const val CORRUPT_KEEP_DAYS = 30
        val MAX_ENTRIES = mapOf("sports" to 500, "sportItems" to 500, "sleep" to 400)
        /** H7: lista blanca de tipos conocidos (el `kind` forma el nombre de fichero: nunca rutas). */
        val KINDS = setOf("origin5", "hrv", "spo2", "half", "live", "sleep", "sports", "sportItems", "health")
    }

    /** Un error de E/S (no de formato) NO renombra ni cachea: el fichero bueno se conserva y flush() se niega a sobrescribirlo. */
    @Synchronized private fun load(kind: String): JSONObject {
        require(kind in KINDS) { "tipo desconocido" }
        cache[kind]?.let { return it }
        val f = File(dir, "$kind.json")
        val o = if (!f.exists()) JSONObject() else {
            val text = try { f.readText() } catch (e: IOException) { return JSONObject() }
            try { JSONObject(text) } catch (e: org.json.JSONException) {
                val bad = File(dir, "$kind.corrupt-${now()}")
                if (!f.renameTo(bad)) try { f.copyTo(bad, overwrite = true) } catch (_: Exception) {}
                JSONObject()
            }
        }
        cache[kind] = o
        return o
    }

    @Synchronized fun put(kind: String, key: String, v: JSONObject) { v.put("_key", key); load(kind).put(key, v) }

    @Synchronized fun putItems(kind: String, key: String, items: JSONArray, reset: Boolean) {
        val o = load(kind)
        val cur = if (reset) null else o.optJSONObject(key)
        val arr = cur?.optJSONArray("items") ?: JSONArray()
        for (i in 0 until items.length()) arr.put(items.get(i))
        o.put(key, JSONObject().put("_key", key).put("items", arr))
    }

    /** Fecha (yyyy-MM-dd) al comienzo de la clave, como milisegundos; null si no tiene. */
    private fun keyDay(k: String): Long? {
        if (k.length < 10 || k[4] != '-' || k[7] != '-') return null
        val y = k.substring(0, 4).toIntOrNull() ?: return null
        val m = k.substring(5, 7).toIntOrNull() ?: return null
        val d = k.substring(8, 10).toIntOrNull() ?: return null
        return Calendar.getInstance().apply { clear(); set(y, m - 1, d) }.timeInMillis
    }

    /** Aplica retención. Devuelve cuántas entradas se eliminaron. */
    @Synchronized fun prune(kind: String): Int {
        val o = load(kind); var removed = 0
        RETENTION_DAYS[kind]?.let { days ->
            // Referencia = min(reloj, dato mas reciente): un reloj adelantado no borra datos validos.
            var newest = 0L; val ik = o.keys(); while (ik.hasNext()) { val t = keyDay(ik.next()); if (t != null && t > newest) newest = t }
            val ref = if (newest > 0) minOf(now(), newest) else now()
            val cutoff = ref - days * 86_400_000L
            val del = ArrayList<String>()
            val it = o.keys(); while (it.hasNext()) { val k = it.next(); val t = keyDay(k); if (t != null && t < cutoff) del.add(k) }
            del.forEach { o.remove(it); removed++ }
        }
        MAX_ENTRIES[kind]?.let { max ->
            if (o.length() > max) {
                val ks = ArrayList<String>(); val it = o.keys(); while (it.hasNext()) ks.add(it.next())
                ks.sort(); ks.take(ks.size - max).forEach { o.remove(it); removed++ }
            }
        }
        return removed
    }

    /** Serializa bajo el cerrojo del almacen; la escritura con fsync ocurre fuera de el (no bloquea a los callbacks del SDK). */
    fun flush(kind: String): Boolean {
        if (kind !in KINDS) return false
        var g = 0L
        val data = synchronized(this) {
            if (wiping) return false
            g = gen
            val o = load(kind)
            if (!cache.containsKey(kind)) return false // lectura fallida: no se sobrescribe el fichero existente
            prune(kind); o.toString()
        }
        beforeWrite?.invoke()
        synchronized(writeLock) {
            if (gen != g) return false // H1: hubo un wipe despues de serializar: se descarta
            val target = File(dir, "$kind.json"); val tmp = File(dir, "$kind.tmp")
            return try {
                FileOutputStream(tmp).use { it.write(data.toByteArray(Charsets.UTF_8)); it.fd.sync() }
                if (!tmp.renameTo(target)) { tmp.delete(); false } else true
            } catch (e: Exception) { tmp.delete(); false }
        }
    }

    /** Libro de lo enviado a Health Connect/Salud (documento unico, clave "state"). null si aun no existe. Con control de version dentro del JSON (lo valida Dart). */
    @Synchronized fun healthState(): String? = load("health").optJSONObject("state")?.toString()

    /** Guarda el libro (JSON objeto) y lo vuelca a disco. false si el texto no es un objeto JSON o falla la escritura. */
    fun saveHealthState(text: String): Boolean {
        val o = try { JSONObject(text) } catch (e: org.json.JSONException) { return false }
        if (text.length > 2_000_000) return false
        synchronized(this) { put("health", "state", o) }
        return flush("health")
    }

    @Synchronized fun all(kind: String): String {
        val o = load(kind); val a = JSONArray()
        val ks = o.keys(); while (ks.hasNext()) a.put(o.get(ks.next()))
        return a.toString()
    }

    /**
     * Privacidad: copia los `<kind>.json` (no .tmp ni .corrupt-*) a [target] (se crea). Antes vuelca a disco lo que haya en memoria.
     * Devuelve los nombres copiados, ordenados. Solo local: no envia nada a ningun sitio.
     */
    fun exportTo(target: File): List<String> {
        val cached = synchronized(this) { cache.keys.toList() }
        cached.forEach { flush(it) }
        // H4: se regenera la carpeta (no quedan copias de tipos que ya no existan).
        if (target.exists() && !target.deleteRecursively()) throw IOException("no se pudo limpiar ${target.name}")
        if (!target.mkdirs()) throw IOException("no se pudo crear ${target.name}")
        val out = ArrayList<String>()
        synchronized(writeLock) {
            dir.listFiles { f -> f.isFile && f.name.endsWith(".json") }?.sortedBy { it.name }?.forEach { f -> f.copyTo(File(target, f.name), overwrite = true); out.add(f.name) }
        }
        return out
    }

    /** Privacidad: borra TODO el contenido del almacen (json, tmp, corrupt) y la cache. Devuelve cuantos ficheros se borraron. */
    fun wipe(): Int = tryWipe { true }!!

    /**
     * H1: como [wipe], pero [canStart] se evalua DENTRO del cerrojo del almacen (sin TOCTOU con quien lo consulta bajo el mismo cerrojo);
     * devuelve null si se niega. Durante el borrado `wiping` es true y los flush se descartan.
     */
    fun tryWipe(canStart: () -> Boolean): Int? {
        synchronized(this) {
            if (!canStart()) return null
            wiping = true; gen++; cache.clear()
        }
        var n = 0
        try { synchronized(writeLock) { dir.listFiles()?.forEach { if (it.isFile && it.delete()) n++ } } }
        finally { synchronized(this) { wiping = false } }
        return n
    }
}
