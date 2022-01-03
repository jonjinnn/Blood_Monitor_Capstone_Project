package com.example.ven_vitals_android


import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.graphics.ColorUtils
import java.util.*


class PopUpWindow : AppCompatActivity() {
    private var popupTitle = ""
    private var popupText = ""
    private var popupButton = ""
    private var darkStatusBar = false
    private lateinit var startTime: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
        setContentView(R.layout.popup_window)
        setDateAndTime()

        // Get the data
        val bundle = intent.extras
        popupTitle = bundle?.getString("popuptitle", "Title") ?: ""
        popupText = bundle?.getString("popuptext", "Text") ?: ""
        popupButton = bundle?.getString("popupbtn", "Button") ?: ""
        darkStatusBar = bundle?.getBoolean("darkstatusbar", false) ?: false
        val popup_title = findViewById<TextView>(R.id.popup_window_title);
        val popup_text = findViewById<TextView>(R.id.popup_window_text);
        val popup_button = findViewById<Button>(R.id.popup_window_button);
        val popup_background = findViewById<ConstraintLayout>(R.id.popup_window_background);
        val popup_view_border = findViewById<CardView>(R.id.popup_window_view_with_border);



        // Set the data
        popup_title.text = popupTitle
        popup_text.text = popupText
        popup_button.text = popupButton

        // Set the Status bar appearance for different API levels
        if (Build.VERSION.SDK_INT in 19..20) {
            setWindowFlag(this, true)
        }
        if (Build.VERSION.SDK_INT >= 19) {
            window.decorView.systemUiVisibility =
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        }
        if (Build.VERSION.SDK_INT >= 21) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // If you want dark status bar, set darkStatusBar to true
                if (darkStatusBar) {
                    this.window.decorView.systemUiVisibility =
                            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                }
                this.window.statusBarColor = Color.TRANSPARENT
                setWindowFlag(this, false)
            }
        }

        // Fade animation for the background of Popup Window
        val alpha = 100 //between 0-255
        val alphaColor = ColorUtils.setAlphaComponent(Color.parseColor("#000000"), alpha)
        val colorAnimation = ValueAnimator.ofObject(ArgbEvaluator(), Color.TRANSPARENT, alphaColor)
        colorAnimation.duration = 500 // milliseconds
        colorAnimation.addUpdateListener { animator ->
            popup_background.setBackgroundColor(animator.animatedValue as Int)
        }
        colorAnimation.start()


        // Fade animation for the Popup Window
        popup_view_border.alpha = 0f
        popup_view_border.animate().alpha(1f).setDuration(500).setInterpolator(
                DecelerateInterpolator()
        ).start()


        // Close the Popup Window when you press the button
        popup_button.setOnClickListener {
            val intent = Intent(this, SessionInfoActivity::class.java)
            intent.putExtra("SESSION_START_TIME", startTime)
            intent.putExtra("SESSION_END_TIME", getCurrentTime())
            intent.putExtra("SESSION_DATE", getCurrentDate())
            startActivity(intent)
            onBackPressed()
        }
    }

    private fun setWindowFlag(activity: Activity, on: Boolean) {
        val win = activity.window
        val winParams = win.attributes
        if (on) {
            winParams.flags = winParams.flags or WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS
        } else {
            winParams.flags = winParams.flags and WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS.inv()
        }
        win.attributes = winParams
    }


    override fun onBackPressed() {
        // Fade animation for the background of Popup Window when you press the back button
        val alpha = 100 // between 0-255
        val alphaColor = ColorUtils.setAlphaComponent(Color.parseColor("#000000"), alpha)
        val colorAnimation = ValueAnimator.ofObject(ArgbEvaluator(), alphaColor, Color.TRANSPARENT)
        val popup_background = findViewById<ConstraintLayout>(R.id.popup_window_background)
        colorAnimation.duration = 500 // milliseconds
        colorAnimation.addUpdateListener { animator ->
            popup_background.setBackgroundColor(
                    animator.animatedValue as Int
            )
        }

        // Fade animation for the Popup Window when you press the back button
        val popup_view_border = findViewById<CardView>(R.id.popup_window_view_with_border)
        popup_view_border.animate().alpha(0f).setDuration(500).setInterpolator(
                DecelerateInterpolator()
        ).start()

        // After animation finish, close the Activity
        colorAnimation.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                finish()
                overridePendingTransition(0, 0)
            }
        })
        colorAnimation.start()
    }

    private fun getCurrentDate(): String {
        val c = Calendar.getInstance()
        val year = c.get(Calendar.YEAR)
        val month = c.get(Calendar.MONTH)
        val day = c.get(Calendar.DAY_OF_MONTH)

        println("getCurrentDate month: $month")
        // month is indexed 0 - 11
        val monthIndexed = month.toInt() + 1

        return monthIndexed.toString().plus("/").plus(day).plus("/").plus(year)
    }

    private fun getCurrentTime(): String {
        val c = Calendar.getInstance()
        val hour = c.get(Calendar.HOUR_OF_DAY)
        val minute = c.get(Calendar.MINUTE)
        val second = c.get(Calendar.SECOND)

        return hour.toString().plus(":").plus(minute).plus(":").plus(second)
    }

    private fun setDateAndTime() {

        val time = getCurrentTime()
        val date = getCurrentDate()

        startTime = time

        println("start time: $time")
        println("date: $date")
    }

}
