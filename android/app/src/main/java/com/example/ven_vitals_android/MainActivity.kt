package com.example.ven_vitals_android

import android.content.Intent
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.widget.Button

const val BLUETOOTH_VERSION = false

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        if (BLUETOOTH_VERSION) connectBluetooth() // Initiates Bluetooth connection process

        val startButton = findViewById<Button>(R.id.startButton)
        startButton.setOnClickListener { // Waits for user to press Start
            displayGraph()
        }

        // val exportButton = findViewById<Button>(R.id.exportButton)
        //val progressBar = findViewById<android.widget.ProgressBar>(R.id.progressBar);

        //exportButton.setOnClickListener {
        //    progressBar.visibility = View.VISIBLE
        //}
    }

    // Goes to ConnectBluetooth when called
    private fun connectBluetooth() {
        val intent = Intent(this, ConnectBluetooth::class.java)
        startActivity(intent)
    }

    // Goes to DisplayGraphActivity when called
    private fun displayGraph() {
        val intent = Intent(this, DisplayGraphActivity::class.java)
        startActivity(intent)
    }

    // Perform an action if specific result is returned (for future development)
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when(requestCode) {
            // If resultCode -> do Something
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}