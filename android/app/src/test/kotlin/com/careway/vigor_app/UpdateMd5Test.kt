package com.careway.vigor_app

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class UpdateMd5Test {
    @Test fun knownVectors() {
        assertEquals("d41d8cd98f00b204e9800998ecf8427e", UpdateRules.md5Hex(ByteArray(0)))
        assertEquals("900150983cd24fb0d6963f7d28e17f72", UpdateRules.md5Hex("abc".toByteArray()))
    }
    @Test fun fileMatchesBytesEvenAcrossBlocks() {
        val data = ByteArray(200_000) { (it * 31 % 251).toByte() } // mas de un bloque de 64 KiB
        val f = File.createTempFile("vigor-md5", ".apk"); f.writeBytes(data)
        try { assertEquals(UpdateRules.md5Hex(data), UpdateRules.md5Hex(f)) } finally { f.delete() }
    }
}
