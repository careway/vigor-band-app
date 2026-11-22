package com.careway.vigor_app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HeartRateWireTest {
    @Test fun encodesUint8WithFlagsZero() { assertArrayEquals(byteArrayOf(0x00, 72), HeartRateWire.encode(72)) }
    @Test fun encodesHighValueAsUnsignedByte() { assertArrayEquals(byteArrayOf(0x00, 200.toByte()), HeartRateWire.encode(200)) }
    @Test fun rejectsInvalid() { assertNull(HeartRateWire.encode(0)); assertNull(HeartRateWire.encode(29)); assertNull(HeartRateWire.encode(221)); assertNull(HeartRateWire.encode(-5)) }
    @Test fun validBounds() { assertTrue(HeartRateWire.valid(30)); assertTrue(HeartRateWire.valid(220)); assertFalse(HeartRateWire.valid(255)) }
    @Test fun wristLocation() { assertArrayEquals(byteArrayOf(2), HeartRateWire.WRIST) }
}
