package com.example.ven_vitals_android

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.github.doyaaaaaken.kotlincsv.dsl.csvReader
import java.io.*

class SessionInfoActivity : AppCompatActivity() {
    private lateinit var sessionStart: TextView
    private lateinit var sessionEnd: TextView
    private lateinit var closeButton: Button
    private lateinit var exportButton: Button
    private lateinit var sessionDate: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_session_info)

        sessionStart = findViewById(R.id.sessionStart)
        sessionEnd = findViewById(R.id.sessionEnd)
        closeButton = findViewById(R.id.closeButton)
        exportButton = findViewById(R.id.exportButton)
        sessionDate = findViewById(R.id.sessionDate)

        val dateLabel = "Date: "
        val startLabel = "Start Time: "
        val endLabel = "End Time: "

        val currentDate = intent.getStringExtra("SESSION_DATE")
        val startTime = intent.getStringExtra("SESSION_START_TIME")
        val endTime = intent.getStringExtra("SESSION_END_TIME")

        sessionDate.text = dateLabel.plus(currentDate)
        sessionStart.text = startLabel.plus(startTime)
        sessionEnd.text = endLabel.plus(endTime)

        // Close all activities and go back to main activity
        closeButton.setOnClickListener {
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
        }

        // Export button listener
        exportButton.setOnClickListener {
            exportFile()
        }
    }

    private fun exportFile() {
        // Create csv file

        val isSDPresent = android.os.Environment.getExternalStorageState().equals(android.os.Environment.MEDIA_MOUNTED)
        //val isSDSupportedDevice = Environment.isExternalStorageRemovable()

        if(isSDPresent) {
            // create public access file on device

            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "text/csv"
                putExtra(Intent.EXTRA_TITLE, "export.csv")
            }
            startActivityForResult(intent, 1)

            val text = "Export Success"
            val duration = Toast.LENGTH_LONG
            val toast = Toast.makeText(applicationContext, text, duration)
            toast.setGravity(Gravity.BOTTOM, 10, 10)
            toast.show()

        }
        else {
            val text = "Storage Unavailable"
            val duration = Toast.LENGTH_LONG
            val toast = Toast.makeText(applicationContext, text, duration)
            toast.setGravity(Gravity.BOTTOM, 10, 10)
            toast.show()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, resultData: Intent?) {
        super.onActivityResult(requestCode, resultCode, resultData)

        if (requestCode == 1
                && resultCode == Activity.RESULT_OK) {
            // The result data contains a URI for the document or directory that
            // the user selected.
            resultData?.data?.also { uri ->
                // Perform operations on the document using its URI.
                contentResolver.openFileDescriptor(uri, "w")?.use { it ->
                    FileOutputStream(it.fileDescriptor).use {
                        // Append info to file
                        val HEADER = "elapsed_time,wall_clock,cap1,cap2,accx,accy,accz,gyrox,gyroy,gyroz,magx,magy,magz"
                        it.write(HEADER.toByteArray())
                        it.write("\n".toByteArray())

                        // Export patient data
                        if (BLUETOOTH_VERSION) { // Bluetooth Version
                            for (data in patientData.getAllData()!!) {
                                it.write(
                                    "${data.time},${data.wallClock},".toByteArray() +
                                            "${data.cap1},0.0,".toByteArray() +
                                            "${data.accx},${data.accy},${data.accz},".toByteArray() +
                                            "${data.gyrox},${data.gyroy},${data.gyroz},".toByteArray() +
                                            "${data.magx},${data.magy},${data.magz}".toByteArray()
                                )
                                it.write("\n".toByteArray())
                            }
                        }
                        else { // CSV Version
                            // Grab data from pre-recorded csv file
                            val file = assets.open("record.csv")
                            csvReader().open(file) {
                                readAllAsSequence().forEach { row: List<String> ->
                                    val listIterator = row.listIterator()
                                    val time = listIterator.next()
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

                                    it.write(
                                        time.toByteArray() + ",".toByteArray() + wallClock.toByteArray() + ",".toByteArray() +
                                                cap1.toByteArray() + ",".toByteArray() + cap2.toByteArray() + ",".toByteArray() +
                                                accx.toByteArray() + ",".toByteArray() + accy.toByteArray() + ",".toByteArray() + accz.toByteArray() + ",".toByteArray() +
                                                gyrox.toByteArray() + ",".toByteArray() + gyroy.toByteArray() + ",".toByteArray() + gyroz.toByteArray() + ",".toByteArray() +
                                                magx.toByteArray() + ",".toByteArray() + magy.toByteArray() + ",".toByteArray() + magz.toByteArray()
                                    )
                                    it.write("\n".toByteArray())
                                }
                            }
                            file.close()
                        }
                    }
                }
            }
        }
    }


}