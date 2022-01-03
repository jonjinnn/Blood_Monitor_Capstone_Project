package com.example.ven_vitals_android

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import com.github.doyaaaaaken.kotlincsv.dsl.csvReader
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.components.YAxis
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineData
import com.github.mikephil.charting.data.LineDataSet
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import java.io.File
import java.util.*
import java.util.concurrent.BlockingQueue
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.collections.ArrayList

var dataPackets: BlockingQueue<DataPacket> = LinkedBlockingQueue()
var sampleData = ArrayList<DataPacket>()
var patientData = PatientData()

class DisplayGraphActivity : AppCompatActivity() {

    private var entries1 = ArrayList<Entry>()
    private var entries2 = ArrayList<Entry>()
    private lateinit var chart1: LineChart
    private lateinit var chart2: LineChart
    private lateinit var lineData1: LineData
    private lateinit var lineData2: LineData

    private lateinit var dateTextView: TextView
    private lateinit var timeTextView: TextView
    private lateinit var stopButton: Button
    private lateinit var dacPlus: Button
    private lateinit var dacMinus: Button
    private lateinit var startTime: String
    private lateinit var dacTotal: TextView
    private lateinit var peakMax: TextView
    private lateinit var troughMin: TextView

    private var dacValue: Double = 0.0;
    private var maxCap: Double = Double.MIN_VALUE
    private var minCap: Double = Double.MAX_VALUE
    private var inputLag = 300
    private var inputCounter = 0;
    private var isCalibrated = false
    private var upperBound: Double = 0.0
    private var lowerBound: Double = 0.0
    private var obtainedMax = false
    private var obtainedMin = false

    private var maxValueList = ArrayList<Double>()
    private var minValueList = ArrayList<Double>()

    // Peak Detection Algorithm variables
    private var peakIndex: Double = 0.0
    private var peakValue: Double = 0.0
    private var troughIndex: Double = 0.0
    private var troughValue: Double = 0.0

    private var avgCount: Double = 0.0
    private var avgTotal: Double = 0.0
    private var baseline: Double = 0.0


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_display_graph)

        //println(">>>>>>>>>>>>>>>coroutine activity thread: ${Thread.currentThread().name}")

        chart1 = findViewById(R.id.chart1)
        chart2 = findViewById(R.id.chart2)
        dateTextView = findViewById(R.id.date)
        timeTextView = findViewById(R.id.time)
        dacTotal = findViewById(R.id.dacTotal)
        peakMax = findViewById(R.id.peakMax)
        troughMin = findViewById(R.id.troughMin)

        stopButton = findViewById(R.id.stopButton)
        dacPlus = findViewById(R.id.dacPlus)
        dacMinus = findViewById(R.id.dacMinus)

        createRunFile()
        setDateAndTime()

        setChartStyle(chart1)
        setChartStyle(chart2)

        // just to make list non empty, otherwise sometimes it doesnt work
        // todo: make sure to remove first entry from actual data being recorded
        entries1.add(Entry(0f, 3f))
        entries2.add(Entry(0f, 3f))


        val dataSet = LineDataSet(entries1, "cap1")
        val dataSet2 = LineDataSet(entries2, "cap2")

        setDataSetStyle(dataSet)
        setDataSetStyle(dataSet2)

        lineData1 = LineData(dataSet)
        lineData2 = LineData(dataSet2)

        chart1.data = lineData1
        chart2.data = lineData2

        chart1.notifyDataSetChanged()
        chart2.notifyDataSetChanged()

        val isRunning = AtomicBoolean(true)

        // Actions to perform when Stop Button is pressed
        stopButton.setOnClickListener {
            if (BLUETOOTH_VERSION) bluetoothGB.close()

            isRunning.set(false)
            val intent = Intent(this, PopUpWindow::class.java)
            intent.putExtra("popuptitle", "Notice")
            intent.putExtra("popuptext", "Current Session Ended. Please turn off PCB Board")
            intent.putExtra("popupbtn", "OK")
            intent.putExtra("darkstatusbar", false)
            startActivity(intent)

            /*for (i in maxValueList.indices) {
                println("max: " + maxValueList[i])
                println("min: " + minValueList[i])
            }*/
        }

        // DAC adjustment button onclick
        ("DAC: $dacValue").also { dacTotal.text = it }

        dacPlus.setOnClickListener {
            dacValue += 1.0;
            ("DAC: $dacValue").also { dacTotal.text = it }

            // need to reset avg total and count after changing DAC value for peak & trough detection algorithm
            avgTotal = 0.0
            avgCount = 0.0
        }
        dacMinus.setOnClickListener {
            dacValue -= 1.0;
            ("DAC: $dacValue").also { dacTotal.text = it }

            avgTotal = 0.0
            avgCount = 0.0
        }

        // onServicesDiscovered starts the data stream process
        // TODO: Find a different entry point to the data stream
        if (BLUETOOTH_VERSION) {
            runOnUiThread {
                bluetoothGB.discoverServices()
            }
        }

        // Simulate input of data packets
        // Thread to dequeue from dataPackets
        GlobalScope.launch(Dispatchers.IO) {
            //println(">>>>>>>>>>>>>>>IO thread1: ${Thread.currentThread().name}")
            while (isRunning.get()) {
                val result = async { dataPackets.take() }
                upDateGraph(result.await())
            }
        }

        if (!BLUETOOTH_VERSION) populateSampleData()
    }


    private fun peakTroughDetectionAlgorithm(cap: Double, time: Float) {
        avgCount++
        avgTotal += cap


        // Baseline is average of the signal value of the graph
        baseline = avgTotal / avgCount

        // Peak detection algorithm
        if (cap > baseline) {
            if (peakValue == 0.0 || cap > peakValue) {
                peakIndex = time.toDouble()
                peakValue = cap
            }
        }
        else if (cap < baseline - 0.1 && peakValue != 0.0) {
            ("MAX: " + "%.4f".format(peakValue)).also { peakMax.text = it }

            // Test editing graph
            //val entry = Entry(time, cap.toFloat())
            //lineData1.addEntry(entry, 0)
            //lineData1.setValueTextColor(4)

            peakIndex = 0.0
            peakValue = 0.0
        }

        // Trough detection algorithm
        if (cap < baseline) {
            if (troughValue == 0.0 || cap < troughValue) {
                troughIndex = time.toDouble()
                troughValue = cap
            }
        }
        else if (cap > baseline - 0.2 && troughValue != 0.0) {
            ("MIN: " + "%.4f".format(troughValue)).also { troughMin.text = it };
            troughIndex = 0.0
            troughValue = 0.0
        }

        //Log.i("Avg: ", baseline.toString())
    }

    private fun calibratePeakTrough(cap: Double) {

        // Takes highest and lowest values for the first n inputs, set by inputLag
        if (inputCounter < inputLag) {
            if (maxCap < cap) maxCap = cap
            if (minCap > cap) minCap = cap
            inputCounter++
        }
        else if (!isCalibrated) {
            //println("max: $maxCap")
            //println("min: $minCap")

            val difference: Double = maxCap - minCap
            val midPoint = minCap + difference / 2
            upperBound = midPoint + (difference / 7) * 2
            lowerBound = midPoint - (difference / 7) * 2

            /*
            println("difference: $difference")
            println("mid point: $midPoint")
            println("upper bound: $upperBound")
            println("lower bound: $lowerBound")
            */

            isCalibrated = true
            maxCap = Double.MIN_VALUE
            minCap = Double.MAX_VALUE
        }
    }

    // TODO: Move to Helper functions file
    // Record graph data to csv file that is only accessible by application, used later to be exported to device
    private fun createRunFile() {
        val isSDPresent = android.os.Environment.getExternalStorageState().equals(android.os.Environment.MEDIA_MOUNTED);

        if (isSDPresent) {
            // Variable with storage location path
            var filename = "run.csv"
            var path = getExternalFilesDir(null)
            var fileOut = File(path, filename)
            fileOut.mkdirs()

            // Delete old and create new file
            fileOut.delete()
            fileOut.createNewFile()
        }
        else { // No storage is available, display an error message
            val text = "Storage Unavailable"
            val duration = Toast.LENGTH_LONG
            val toast = Toast.makeText(applicationContext, text, duration)
            toast.setGravity(Gravity.BOTTOM, 10, 10)
            toast.show()
        }
    }

    // Write to run.csv file
    private fun writeToRunFile(time: Float, wallClock: String, cap1: String, cap2: String, accx: String, accy: String, accz: String, gyrox: String, gyroy: String, gyroz: String, magx: String, magy:String, magz: String) {
        // Append info to file
        val appSpecificExternalDir = File(getExternalFilesDir(null), "run.csv")

        appSpecificExternalDir.appendText("$time,$wallClock," +
                    "$cap1,$cap2," +
                    "$accx,$accy,$accz," +
                    "$gyrox,$gyroy,$gyroz" +
                    "$magx,$magy,$magz"
                )
        appSpecificExternalDir.appendText("\n")
    }


    private fun upDateGraph(newData: DataPacket) {
        GlobalScope.launch(Dispatchers.Main){
            val time = newData.time.toFloat()
            val wallClock = newData.wallClock
            // DAC value adjusts cap value here
            val cap = newData.cap1.toDouble() + dacValue

            val cap2 = newData.cap2
            val accx = newData.accx
            val accy = newData.accy
            val accz = newData.accz
            val gyrox = newData.gyrox
            val gyroy = newData.gyroy
            val gyroz = newData.gyroz
            val magx = newData.magx
            val magy = newData.magy
            val magz = newData.magz

            // Write to run.csv
            writeToRunFile(time, wallClock, cap.toString(), cap2, accx, accy, accz, gyrox, gyroy, gyroz, magx, magy, magz)

            // Peak trough detection function call here
            peakTroughDetectionAlgorithm(cap, time)

            val entry = Entry(time, cap.toFloat())

            if (!isCalibrated) calibratePeakTrough(cap)
            else {
                if (cap > upperBound) {
                    if (cap > maxCap) maxCap = cap
                    else obtainedMax = true
                }
                if (cap < lowerBound) {
                    if (cap < minCap) minCap = cap
                    else obtainedMin = true
                }

                if (obtainedMax && obtainedMin) {
                    //println("current cycle max: $maxCap")
                    //println("current cycle min: $minCap")
                    maxValueList.add(maxCap)
                    minValueList.add(minCap)
                    obtainedMax = false
                    obtainedMin = false
                    maxCap = Double.MIN_VALUE
                    minCap = Double.MAX_VALUE
                }
            }

            lineData1.addEntry(entry, 0)
            lineData1.notifyDataChanged()
            chart1.notifyDataSetChanged()
            chart1.setVisibleXRangeMaximum(200f)
            chart1.moveViewToX(lineData1.entryCount.toFloat())
            chart1.setScaleMinima(lineData1.entryCount.toFloat() / 200f, 1f)
            chart1.invalidate()

            lineData2.addEntry(entry, 0)
            lineData2.notifyDataChanged()
            chart2.notifyDataSetChanged()
            chart2.setVisibleXRangeMaximum(200f)
            chart2.moveViewToX(lineData1.entryCount.toFloat())
            chart2.setScaleMinima(lineData1.entryCount.toFloat() / 200f, 1f)
            chart2.invalidate()
        }
    }

    // Open csv file and input data into dataPackets ArrayList
    private fun populateSampleData() {

        //println(">>>>>>>>>>>>>>>populating sample data thread: ${Thread.currentThread().name}")

        val file = assets.open("record.csv")
        csvReader().open(file) {
            readAllAsSequence().forEach { row: List<String> ->
                val listIterator = row.listIterator()

                val time = listIterator.next().toDouble()
                val wallClock = listIterator.next()
                val cap1 = listIterator.next()
                val cap2 = listIterator.next()
                val accx = listIterator.next()
                val accy = listIterator.next()
                val accz = listIterator.next()
                val gyrox = listIterator.next()
                val gyroy = listIterator.next()
                val gyroz = listIterator.next()
                val magx = listIterator.next()
                val magy = listIterator.next()
                val magz = listIterator.next()

                val newPacket = DataPacket(time, wallClock, cap1, cap2, accx, accy, accz, gyrox, gyroy, gyroz, magx, magy, magz)
                sampleData.add(newPacket)
            }
        }
        file.close()  // todo: close file/input stream
        // Thread to enqueue to dataPackets
        GlobalScope.launch(Dispatchers.IO) {
            //println(">>>>>>>>>>>>>>>IO thread2: ${Thread.currentThread().name}")
            val listIterator = sampleData.iterator()
            while (listIterator.hasNext()) {
                Thread.sleep(10)             // time between consecutive packets
                addPacketToQueue(listIterator.next())
            }
            //println(">>>>>>>>>>>>>>>finished inputting data")
        }
    }

    private fun setDateAndTime() {

        val time = getCurrentTime()
        val date = getCurrentDate()

        val dateLabel = "Date: "
        val timeLabel = "Start Time: "
        dateTextView.text = dateLabel.plus(date)
        timeTextView.text = timeLabel.plus(time)
        startTime = time

        println("start time: $time")
        println("date: $date")
    }
}