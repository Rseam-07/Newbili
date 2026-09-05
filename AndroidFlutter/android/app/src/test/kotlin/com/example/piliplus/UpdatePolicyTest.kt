package com.example.piliplus

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class UpdatePolicyTest {
    private fun pages(vararg ids: Long) = ids.mapIndexed { index, id ->
        JSONObject().put("cid", id).put("page", index + 1).put("title", "P${index + 1}")
    }
    private fun record(id: String, mid: Long = 1) = JSONObject()
        .put("id", id).put("mid", mid).put("bvid", "BV1td8R6EE2L")

    @Test fun firstSyncDoesNotNotifyHistoricalPages() {
        assertTrue(UpdatePolicy.addedPages(emptySet(), pages(1, 2)).isEmpty())
    }
    @Test fun onlyNewCidsCountNotRenamesReorderingOrRemovals() {
        val current = pages(2, 1, 3, 3)
        assertEquals(listOf(3L), UpdatePolicy.addedPages(setOf(1, 2), current).map { it.getLong("cid") })
        assertTrue(UpdatePolicy.addedPages(setOf(1, 2), pages(2)).isEmpty())
    }
    @Test fun previouslyRemovedPagesDoNotNotifyWhenRestored() {
        assertTrue(UpdatePolicy.addedPages(setOf(1, 2, 3), pages(1, 3)).isEmpty())
    }
    @Test fun switchingAccountOrTierEstablishesBaselineWithoutHistory() {
        assertTrue(UpdatePolicy.newRecords(listOf(record("new")), emptySet(), false).isEmpty())
    }
    @Test fun specialOnlyNeverFallsBackToAllFollowing() {
        val current = listOf(record("a", 1), record("b", 2), record("b", 2))
        assertTrue(UpdatePolicy.newRecords(current, emptySet(), true, emptySet()).isEmpty())
        assertEquals(listOf("b"), UpdatePolicy.newRecords(current, emptySet(), true, setOf(2)).map { it.getString("id") })
    }
    @Test fun seenAndDuplicateDynamicsAreNotEmittedTwice() {
        val current = listOf(record("old"), record("new"), record("new"))
        assertEquals(1, UpdatePolicy.newRecords(current, setOf("old"), true).size)
    }
    @Test fun snapshotKeepsCaseAndNormalizesPages() {
        val data = JSONObject().put("bvid", "BV1td8R6EE2L").put("title", "标题")
            .put("owner", JSONObject().put("name", "UP"))
            .put("pages", JSONArray(pages(9, 2, 2, 0).reversed()))
        val snapshot = UpdatePolicy.snapshot(data, 10, 20)
        assertEquals("BV1td8R6EE2L", snapshot.getString("bvid"))
        assertEquals("UP", snapshot.getString("owner"))
        assertEquals(2, snapshot.getJSONArray("pages").length())
        assertEquals(10L, snapshot.getLong("markedAt"))
        assertEquals(20L, snapshot.getLong("checkedAt"))
    }
    @Test fun invalidVideoIDsCannotBecomeNetworkPaths() {
        assertFalse(UpdatePolicy.validBvid("BV1td8R6EE2L?cookie=x"))
        assertFalse(UpdatePolicy.validBvid("https://example.com"))
        assertTrue(UpdatePolicy.validBvid("BV1td8R6EE2L"))
    }
    @Test fun malformedAndNonVideoDynamicsAreIgnored() {
        val archive = JSONObject().put("bvid", "BV1td8R6EE2L").put("title", "视频")
        val modules = JSONObject().put("module_author", JSONObject().put("mid", 1).put("name", "UP"))
            .put("module_dynamic", JSONObject().put("major", JSONObject().put("archive", archive)))
        val item = JSONObject().put("id_str", "one").put("modules", modules)
        val result = UpdatePolicy.records(JSONObject().put("items", JSONArray(listOf(item, item, JSONObject()))))
        assertEquals(1, result.size)
        assertEquals("视频", result.first().getString("title"))
    }
}
