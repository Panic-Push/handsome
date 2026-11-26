package app.penwise.core.plan

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
private data class WordFile(val language: String, val words: List<String>)

/**
 * Picks practice words from the word list (content/words/en.json).
 * Words are chosen to contain the focus letters and, when [allowed] is
 * given, to use only letters the learner has already met.
 */
class WordBank private constructor(val words: List<String>) {

    /**
     * Up to [count] words, best matches first: words containing more of the
     * [focus] letters come first, then shorter words. [seed] varies the
     * choice from day to day while staying repeatable.
     */
    fun pick(
        focus: List<String>,
        allowed: List<String>?,
        count: Int,
        seed: Int,
        minLength: Int,
        maxLength: Int,
    ): List<String> {
        val allowedSet = allowed?.flatMap { it.lowercase().toList() }?.toSet()
        val focusSet = focus.flatMap { it.lowercase().toList() }.toSet()
        val candidates = words.filter { w ->
            w.length in minLength..maxLength &&
                (allowedSet == null || w.all { it in allowedSet })
        }
        fun hits(w: String) = w.toSet().count { it in focusSet }
        val ranked = candidates
            .filter { focusSet.isEmpty() || hits(it) > 0 }
            .sortedWith(compareByDescending<String> { hits(it) }.thenBy { it.length }.thenBy { it })
        if (ranked.isEmpty()) return candidates.take(count)
        // Keep the best matches but rotate within the top group for variety.
        val top = ranked.take(maxOf(count * 3, count))
        val start = if (top.isEmpty()) 0 else (seed.mod(top.size))
        return (top.drop(start) + top.take(start)).take(count)
    }

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        @Throws(Exception::class)
        fun fromJson(text: String): WordBank =
            WordBank(json.decodeFromString(WordFile.serializer(), text).words.map { it.lowercase() })
    }
}
