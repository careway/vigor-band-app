package com.careway.vigor_app

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView

/**
 * Pantalla de "racionalidad de permisos" que exige Health Connect (ACTION_SHOW_PERMISSIONS_RATIONALE y,
 * en Android 14+, VIEW_PERMISSION_USAGE). Es estatica y nativa: explica que se escribe y que no se comparte.
 * Implementada, NO probada en el movil (no se ha abierto desde Health Connect).
 */
class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = getString(R.string.health_rationale_title)
        val pad = (20 * resources.displayMetrics.density).toInt()
        val tv = TextView(this).apply {
            text = getString(R.string.health_rationale_body)
            textSize = 16f
            setPadding(pad, pad, pad, pad)
        }
        setContentView(ScrollView(this).apply { addView(tv) })
    }
}
