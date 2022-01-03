package com.example.ven_vitals_android

import android.graphics.Color
import android.util.Log
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.components.YAxis
import com.github.mikephil.charting.data.LineDataSet
import java.util.*

const val accFullScale: Double = 4.0
const val gyroFullScale: Double = (7.6e-3).toDouble()
const val magFullScale: Double = (1 / 16).toDouble()
const val CLK_FREQ = 32768.0  // 32.768kHz
const val CLK_PERIOD:Double = 1/CLK_FREQ

fun getCurrentTime(): String {
    val c = Calendar.getInstance()
    val hour = c.get(Calendar.HOUR_OF_DAY)
    val minute = c.get(Calendar.MINUTE)
    val second = c.get(Calendar.SECOND)

    return hour.toString().plus(":").plus(minute).plus(":").plus(second)
}

fun getCurrentDate(): String {
    val c = Calendar.getInstance()
    val year = c.get(Calendar.YEAR)
    val month = c.get(Calendar.MONTH)
    val day = c.get(Calendar.DAY_OF_MONTH)

    //println("getCurrentDate month: $month")
    // month is indexed 0 - 11
    val monthIndexed = month + 1

    return monthIndexed.toString().plus("/").plus(day).plus("/").plus(year)
}

fun setChartStyle(chart: LineChart) {
    chart.setTouchEnabled(true)
    chart.setPinchZoom(true)
    chart.isDragEnabled = true
    chart.setBackgroundColor(Color.WHITE)
    chart.setDrawGridBackground(false)
    chart.setVisibleXRangeMaximum(200f)
    chart.axisLeft.setDrawGridLines(false)
    chart.xAxis.setDrawGridLines(true)
    chart.xAxis.setDrawLabels(true)
    chart.isAutoScaleMinMaxEnabled = true
    chart.xAxis.textSize = 10f
}

fun setDataSetStyle(dataSet: LineDataSet) {
    dataSet.axisDependency = YAxis.AxisDependency.LEFT
    dataSet.lineWidth = 3f
    dataSet.cubicIntensity = 0.2f
    //dataSet.setColors(Color.BLACK)
}

fun addPacketToQueue(dataPacket: DataPacket) {
    dataPackets.add(dataPacket)
    patientData.addDataPacket(dataPacket)
}

fun signCorrection(num : Double) : Double {
    if(num >= 32768) {
        // This check is to see if it is negative or not by checking if the first bit is 1 i.e. the reading of the small end byte is larger than 32768
        return num - 65536
    }
    return num
}

fun getValues(data: ByteArray) {
    // Mag
    var readMagZ: Double = (data[25].toUByte() * 256u + data[24].toUByte()).toDouble()
    readMagZ = magFullScale * signCorrection(readMagZ)
    var readMagY: Double = (data[23].toUByte() * 256u + data[22].toUByte()).toDouble()
    readMagY = magFullScale * signCorrection(readMagY)
    var readMagX: Double = (data[21].toUByte() * 256u + data[20].toUByte()).toDouble()
    readMagX = magFullScale * signCorrection(readMagX)

    // Gyro
    var readGyroZ: Double = (data[19].toUByte() * 256u + data[18].toUByte()).toDouble()
    readGyroZ = gyroFullScale * signCorrection(readGyroZ) / 32768.0
    var readGyroY: Double = (data[17].toUByte() * 256u + data[16].toUByte()).toDouble()
    readGyroY = gyroFullScale * signCorrection(readGyroY) / 32768.0
    var readGyroX: Double = (data[15].toUByte() * 256u + data[14].toUByte()).toDouble()
    readGyroX = gyroFullScale * signCorrection(readGyroX) / 32768.0

    // Acc
    var readAccZ: Double = (data[13].toUByte() * 256u + data[12].toUByte()).toDouble()
    readAccZ = accFullScale * readAccZ / 32768.0
    var readAccY: Double = (data[11].toUByte() * 256u + data[10].toUByte()).toDouble()
    readAccY = accFullScale * signCorrection(readAccY) / 32768.0
    var readAccX: Double = (data[9].toUByte() * 256u + data[8].toUByte()).toDouble()
    readAccX = accFullScale * signCorrection(readAccX) / 32768.0

    // Cap reading decoding
    var capReading: Double =
        (data[4].toUByte() + data[5].toUByte() * 256u + data[6].toUByte() * 256u * 256u + data[7].toUByte() * 256u * 256u * 256u).toDouble()
    capReading *= 8.0
    capReading /= 16777215.0

    // Time coming from the nRF is in CPU ticks. Use CLK period of the nRF to calculate time elapsed in seconds
    // The num of ticks also resets every ~2 seconds, so need to account for that
    var time: Double = data[1] * 256.0 + data[0]
    time *= CLK_PERIOD

    if (maxTime == 0.0) {
        maxTime = time
        previousTime = time
    }
    if (time > previousTime) {
        val delta = time - previousTime
        previousTime = time
        maxTime += delta

        // Clear every 200 units to lower memory usage
        if (history.size == 200) history = mutableListOf()

        history.add(delta)
    }
    else {
        previousTime = time
        if (history.size > 0) {
            val historySum = history.reduce { sum, element -> sum + element }
            val historyAvg: Double = historySum / history.size.toDouble()
            maxTime += historyAvg
        }
    }

    // Create a data packet, and send it to the application for graphing,
    // and send it to patientData for exporting
    // TODO: Very high storage use, make more efficient
    val patient_packet = DataPacket(maxTime, getCurrentTime(), capReading.toString(), "",
                            readAccZ.toString(), readAccY.toString(), readAccX.toString(),
                            readGyroZ.toString(), readGyroY.toString(), readGyroX.toString(),
                            readMagZ.toString(), readMagY.toString(), readMagX.toString()
    )
    addPacketToQueue(patient_packet) // TODO: Add to PatientData object, not directly to dataPackets array
}
