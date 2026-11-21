package com.careway.vigor_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StartupPermissionsTest {
    private val none = { _: String -> false }; private val all = { _: String -> true }
    @Test fun android12_needs_bluetooth_not_location() {
        assertEquals(listOf(StartupPermissions.Group.BLUETOOTH), StartupPermissions.missing(31, none))
        assertEquals(listOf(StartupPermissions.Group.BLUETOOTH), StartupPermissions.missing(34, none))
    }
    @Test fun android11_needs_location_not_bluetooth() {
        assertEquals(listOf(StartupPermissions.Group.LOCATION), StartupPermissions.missing(29, none))
        assertEquals(listOf(StartupPermissions.Group.LOCATION), StartupPermissions.missing(30, none))
    }
    @Test fun nothing_missing_when_granted() {
        assertTrue(StartupPermissions.missing(34, all).isEmpty()); assertTrue(StartupPermissions.missing(29, all).isEmpty())
    }
    @Test fun one_of_two_bluetooth_permissions_missing_still_counts() {
        val g = { p: String -> p == StartupPermissions.SCAN }
        assertEquals(listOf(StartupPermissions.Group.BLUETOOTH), StartupPermissions.missing(33, g))
    }
    @Test fun blocked_only_if_asked_before_and_no_rationale_for_any_missing() {
        assertFalse(StartupPermissions.blocked(33, false, none) { false })        // nunca se pidio: el sistema aun mostrara su dialogo
        assertTrue(StartupPermissions.blocked(33, true, none) { false })          // pedido y denegado para siempre
        assertFalse(StartupPermissions.blocked(33, true, none) { true })          // pedido y denegado una vez: aun se puede volver a pedir
        assertFalse(StartupPermissions.blocked(33, true, all) { false })          // concedido: no esta bloqueado
    }
}
