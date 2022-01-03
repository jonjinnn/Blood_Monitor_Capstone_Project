package com.example.ven_vitals_android

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.util.*

/*
    Bluetooth connection initialization process implemented using
    https://punchthrough.com/android-ble-guide
*/

private const val ENABLE_BLUETOOTH_REQUEST_CODE = 1
private const val LOCATION_PERMISSION_REQUEST_CODE = 2

var maxTime: Double = 0.0
var previousTime: Double = 0.0
var history: MutableList<Double> = mutableListOf()
lateinit var bluetoothGB:BluetoothGatt

class ConnectBluetooth : AppCompatActivity() {
    // Tasks that are run when the application first opens
    // TODO: Some functions may not be needed
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        startBleScan()
    }

    //         //
    /* SCANNER */
    //         //

    // Gets the scanner object, only when bluetoothAdapter is initialized
    private val bleScanner by lazy {
        bluetoothAdapter.bluetoothLeScanner
    }

    // Grabs the Bluetooth adapter
    private val bluetoothAdapter: BluetoothAdapter by lazy {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothManager.adapter
    }

    // Scan filter, not important
    private val scanSettings = ScanSettings.Builder()
        .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
        .build()

    //                       //
    /* BLUETOOTH PERMISSIONS */
    //                       //

    // Calls promptEnableBluetooth() if Bluetooth is disabled
    override fun onResume() {
        super.onResume()
        if (!bluetoothAdapter.isEnabled) {
            promptEnableBluetooth()
        }
    }

    // Asks to turn on Bluetooth if it is disabled
    // TODO: Make the warning message more informative
    private fun promptEnableBluetooth() {
        if (!bluetoothAdapter.isEnabled) {
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            startActivityForResult(enableBtIntent, ENABLE_BLUETOOTH_REQUEST_CODE)
        }
    }

    // Continuously ask the user to turn on Bluetooth if they disable it
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            ENABLE_BLUETOOTH_REQUEST_CODE -> {
                if (resultCode != Activity.RESULT_OK) {
                    promptEnableBluetooth()
                }
            }
        }
    }

    //                      //
    /* LOCATION PERMISSIONS */
    //                      //

    // Grabs the location permission attribute
    private val isLocationPermissionGranted get() = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)

    // Checks if the attribute is equal to PERMISSION_GRANTED
    private fun Context.hasPermission(permissionType: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permissionType) ==
                PackageManager.PERMISSION_GRANTED
    }

    // Ask for Location Permission, or start the bluetooth scan
    private fun startBleScan() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !isLocationPermissionGranted) {
            requestLocationPermission()
        }
        else {
            bleScanner.startScan(null, scanSettings, scanCallback)
        }
    }

    // Stops the scan when the button is pressed
    private fun stopBleScan() {
        bleScanner.stopScan(scanCallback)
    }

    // Request Location Permission dialog
    // TODO: Provide more visually appealing dialog
    private fun requestLocationPermission() {
        if (isLocationPermissionGranted) return // Location has already been granted

        // Function that is called when user presses OK
        val positiveButtonClick = { _: DialogInterface, _: Int ->
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), LOCATION_PERMISSION_REQUEST_CODE)
        }

        // Create an alert prompting the user to enable location permissions
        val alert = AlertDialog.Builder(this)
        with(alert) {
            setTitle("Initial Setup")
            setMessage(
                "Vena Vitals requires the app to be granted " +
                        "location access in order to scan for BLE devices."
            )
            setCancelable(false)
            setPositiveButton("OK", positiveButtonClick)
        }

        // Make this alert show right now
        runOnUiThread {
            alert.show()
        }
    }

    // When the user enables location permissions, the application will
    // go back to the startBleScan() function and start the scan,
    // else continuously ask for location permissions
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            LOCATION_PERMISSION_REQUEST_CODE -> {
                if (grantResults.firstOrNull() == PackageManager.PERMISSION_DENIED) requestLocationPermission()
                else startBleScan()
            }
        }
    }

    //               //
    /* DEVICE OBJECT */
    //               //

    // Notify user when a compatible device has been found
    private val scanCallback = object : ScanCallback() {
        // Connect to device with a specified name
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            with(result.device) {
                if (name !== null && name.equals("DRGcBP")) {
                    // TODO: *** IMPORTANT *** The device name may different for other PCB boards
                    connectGatt(applicationContext, false, gattCallback)
                    stopBleScan()
                }
            }
        }
    }

    // Gatt object that deals with all asynchronous calls
    // TODO: Make informative notification if connection fails
    private val gattCallback = object : BluetoothGattCallback() {
        // Go back to main page when device has connected
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val deviceAddress = gatt.device.address

            if (status == BluetoothGatt.GATT_SUCCESS) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.w("gattCallback", "Successfully connected to $deviceAddress")
                    // Perform certain actions when we successfully connect
                    runOnUiThread {
                        bluetoothGB = gatt
                        finish()
                    }
                }
                else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    Log.w("gattCallback", "Successfully disconnected from $deviceAddress")
                    gatt.close()
                }
            }
            else {
                Log.w("gattCallback", "Error $status encountered for $deviceAddress! Disconnecting...")
                gatt.close()
            }
        }

        // Change what happens here whenever readCharacteristic() is called
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            // Either read characteristic,
            // characteristic has read disabled,
            // or an error occurred
            with(characteristic) {
                when (status) {
                    BluetoothGatt.GATT_SUCCESS -> {
                        // The value of the characteristic is the ByteArray (byte[]), which
                        // contains the data from the sensor; algorithm from FirstViewController.swift
                        val data = value
                        getValues(data)
                    }
                    BluetoothGatt.GATT_READ_NOT_PERMITTED -> {
                        Log.e("readCharacteristic()", "Read not permitted for $uuid!")
                    }
                    else -> {
                        Log.e("readCharacteristic()", "Characteristic read failed for $uuid, error: $status")
                    }
                }
            }
        }

        // discoverServices() is called whenever we want to start continuously reading data
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            with(gatt) {
                // Consider connection setup as complete when execution reaches this point
                getPressure() // Enables notifications
            }
        }

        // Read data when application is notified
        override fun onDescriptorWrite(gatt: BluetoothGatt?, descriptor: BluetoothGattDescriptor?, status: Int) {
            descriptor?.characteristic?.let { gatt?.readCharacteristic(it) }
        }

        // Called whenever a characteristic gets changed/updated
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            with(characteristic) {
                getValues(value)
            }
        }
    }

    //                          //
    /* ENABLE CONTINUOUS UPDATE */
    //                          //

    // Helper functions to check if a characteristic is readable/writable
    private fun BluetoothGattCharacteristic.isReadable(): Boolean = containsProperty(BluetoothGattCharacteristic.PROPERTY_READ)
    private fun BluetoothGattCharacteristic.containsProperty(property: Int): Boolean { return properties and property != 0 }

    // BluetoothGatt function that accesses the blood pressure data stream
    private fun BluetoothGatt.getPressure() {
        val hdpServiceUuid = UUID.fromString("71ee1400-1232-11ea-8d71-362b9e155667") // Heart Device Profile
        val heartRateUuid1 = UUID.fromString("71ee1401-1232-11ea-8d71-362b9e155667") // *** Cap 1
        val heartRate1 = getService(hdpServiceUuid)?.getCharacteristic(heartRateUuid1)
        if (heartRate1?.isReadable() == true) {
            enableNotifications(heartRate1) // Enables continuous reading of data
        }
        val heartRateUuid2 = UUID.fromString("71ee1402-1232-11ea-8d71-362b9e155667") // *** Cap 2
        val heartRate2 = getService(hdpServiceUuid)?.getCharacteristic(heartRateUuid2)
        if (heartRate2?.isReadable() == true) {
            enableNotifications(heartRate2) // Enables continuous reading of data
        }
    }

    // Helper functions that check for different characteristics
    private fun BluetoothGattCharacteristic.isIndicatable(): Boolean = containsProperty(BluetoothGattCharacteristic.PROPERTY_INDICATE)
    private fun BluetoothGattCharacteristic.isNotifiable(): Boolean = containsProperty(BluetoothGattCharacteristic.PROPERTY_NOTIFY)

    // First checks if the characteristic is indicatable and notifiable,
    // then subscribes to notifications (new data updates)
    private fun BluetoothGatt.enableNotifications(characteristic: BluetoothGattCharacteristic) {
        val payload = when {
            characteristic.isIndicatable() -> BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            characteristic.isNotifiable() -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            else -> {
                Log.e("enableNotifications()", "${characteristic.uuid} doesn't support notifications/indications")
                return
            }
        }
        Log.e("ConnectionManager", payload.toString())
        setCharacteristicNotification(characteristic,true)
        characteristic.descriptors.forEach { descriptor ->
            descriptor.let {
                it.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                writeDescriptor(it)
            }
        }
    }

}