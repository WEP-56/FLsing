package com.flsing.flsing

import android.app.Application
import com.tencent.mmkv.MMKV

class FlsingApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MMKV.initialize(this)
    }
}
