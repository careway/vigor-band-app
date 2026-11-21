package com.careway.vigor_app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenUrlRulesTest {
    @Test fun allows_github_and_openstreetmap_over_https() { assertTrue(OpenUrlRules.allowed("https", "github.com")); assertTrue(OpenUrlRules.allowed("https", "www.openstreetmap.org")) }
    @Test fun rejects_http_other_hosts_and_lookalikes() {
        assertFalse(OpenUrlRules.allowed("http", "github.com")); assertFalse(OpenUrlRules.allowed("https", "evil.com"))
        assertFalse(OpenUrlRules.allowed("https", "github.com.evil.com")); assertFalse(OpenUrlRules.allowed("https", "openstreetmap.org.evil.com")); assertFalse(OpenUrlRules.allowed("javascript", null))
    }
}
