package com.example.piliplus

import org.json.JSONArray
import org.json.JSONObject

/** Pure update rules shared by foreground and system-scheduled checks. */
internal object UpdatePolicy {
    private val videoID = Regex("BV[0-9A-Za-z]{10}")
    val levels = setOf("off", "specialOnly", "allFollowing")

    fun validBvid(value: String) = videoID.matches(value)

    fun pages(data: JSONObject): List<JSONObject> =
        data.optJSONArray("pages").objects().filter { it.optLong("cid") > 0 }
            .distinctBy { it.getLong("cid") }.sortedBy { it.optInt("page") }
            .map { page ->
                JSONObject().put("cid", page.getLong("cid"))
                    .put("page", page.optInt("page"))
                    .put("title", page.optString("part", page.optString("title")))
            }

    fun addedPages(known: Set<Long>, current: List<JSONObject>): List<JSONObject> =
        if (known.isEmpty()) emptyList()
        else current.filter { it.getLong("cid") !in known }.distinctBy { it.getLong("cid") }

    fun records(data: JSONObject): List<JSONObject> =
        data.optJSONArray("items").objects().mapNotNull { item ->
            val modules = item.optJSONObject("modules") ?: return@mapNotNull null
            val author = modules.optJSONObject("module_author") ?: return@mapNotNull null
            val archive = modules.optJSONObject("module_dynamic")?.optJSONObject("major")
                ?.optJSONObject("archive") ?: return@mapNotNull null
            val bvid = archive.optString("bvid")
            val id = item.optString("id_str")
            if (!validBvid(bvid) || id.isEmpty() || author.optLong("mid") <= 0) null
            else JSONObject().put("id", id).put("bvid", bvid)
                .put("mid", author.getLong("mid")).put("owner", author.optString("name"))
                .put("title", archive.optString("title", "新投稿"))
        }.distinctBy { it.getString("id") }

    fun newRecords(
        current: List<JSONObject>, seen: Set<String>, hasBaseline: Boolean,
        allowed: Set<Long>? = null,
    ): List<JSONObject> = if (!hasBaseline) emptyList() else current.filter {
        it.getString("id") !in seen && (allowed == null || it.getLong("mid") in allowed)
    }.distinctBy { it.getString("id") }

    fun snapshot(data: JSONObject, markedAt: Long, checkedAt: Long = 0): JSONObject {
        val bvid = data.getString("bvid")
        require(validBvid(bvid)) { "Invalid video ID" }
        return JSONObject().put("bvid", bvid).put("title", data.optString("title", bvid))
            .put("cover", data.optString("pic", data.optString("cover")))
            .put("owner", data.optJSONObject("owner")?.optString("name") ?: data.optString("owner"))
            .put("pages", JSONArray(pages(data))).put("markedAt", markedAt)
            .put("checkedAt", checkedAt)
    }
}

internal fun JSONArray?.objects(): List<JSONObject> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }

internal fun JSONArray?.strings(): Set<String> =
    if (this == null) emptySet() else (0 until length()).map { getString(it) }.toSet()

internal fun JSONArray?.longs(): Set<Long> =
    if (this == null) emptySet() else (0 until length()).map { getLong(it) }.toSet()
