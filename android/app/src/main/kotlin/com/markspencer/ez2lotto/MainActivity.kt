package com.markspencer.ez2lotto

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // SECURITY: Prevent screenshots and screen recording.
        // FLAG_SECURE blocks the system screenshot mechanism and marks the window
        // as secure so it won't appear in app switcher thumbnails.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
