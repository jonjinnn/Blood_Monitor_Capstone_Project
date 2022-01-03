package com.example.ven_vitals_android

class PatientData {
    private var dataPacketsList: ArrayList<DataPacket>? = arrayListOf()

    fun addDataPacket(newDataPacket: DataPacket) {
        dataPacketsList?.add(newDataPacket)
    }

    fun getAllData(): ArrayList<DataPacket>? {
        return this.dataPacketsList
    }
}