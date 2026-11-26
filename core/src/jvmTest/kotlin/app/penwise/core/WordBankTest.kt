package app.penwise.core

import app.penwise.core.plan.WordBank
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class WordBankTest {
    private val bank = WordBank.fromJson(File("../content/words/en.json").readText())

    @Test
    fun wordListIsCleanLowercaseLetters() {
        assertTrue(bank.words.size >= 250)
        assertTrue(bank.words.all { w -> w.isNotEmpty() && w.all { it in 'a'..'z' } })
        assertEquals(bank.words.size, bank.words.toSet().size, "no duplicates")
    }

    @Test
    fun picksWordsWithTheFocusLettersUsingOnlyKnownLetters() {
        val known = "coadlti".map { it.toString() }
        val words = bank.pick(listOf("a"), known, 5, seed = 0, minLength = 3, maxLength = 5)
        assertTrue(words.isNotEmpty(), "words: $words")
        assertTrue(words.all { w -> 'a' in w && w.all { it.toString() in known } }, "$words")
    }

    @Test
    fun seedVariesTheChoice() {
        val a = bank.pick(listOf("g"), null, 4, seed = 0, minLength = 3, maxLength = 6)
        val b = bank.pick(listOf("g"), null, 4, seed = 2, minLength = 3, maxLength = 6)
        assertEquals(4, a.size)
        assertTrue(a != b)
        assertTrue((a + b).all { 'g' in it })
    }
}
