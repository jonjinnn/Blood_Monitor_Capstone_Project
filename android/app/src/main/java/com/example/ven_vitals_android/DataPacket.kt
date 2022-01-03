package com.example.ven_vitals_android

data class DataPacket(val time: Double, val wallClock: String, val cap1: String, val cap2: String, val accx: String, val accy: String,
                      val accz: String, val gyrox: String, val gyroy: String, val gyroz: String, val magx: String, val magy: String, val magz: String)