package com.example.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import java.text.SimpleDateFormat
import java.util.*

class LocationTrackerService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    saveLocationToDatabase(location.latitude, location.longitude)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, "LocationServiceChannel")
            .setContentTitle("Life Tracker")
            .setContentText("Recording your route in the background...")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .build()
            
        startForeground(1, notification)
        startLocationUpdates()
        return START_STICKY
    }

    private fun startLocationUpdates() {
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10000) // 10 seconds
            .setMinUpdateDistanceMeters(5f) // Record if moved 5 meters
            .build()
            
        try {
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun saveLocationToDatabase(lat: Double, lon: Double) {
        try {
            val path = getDatabasePath("life_tracker.db").absolutePath
            val db = SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY)
            db.enableWriteAheadLogging() // Allows Flutter to read while Kotlin writes
            
            // Ensure table exists in case Kotlin runs before Flutter initializes the DB
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS pending_points (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    lat REAL NOT NULL,
                    lon REAL NOT NULL,
                    recorded_at TEXT NOT NULL
                )
            """.trimIndent())
            
            // Format time exactly like DateTime.now().toIso8601String()
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
            sdf.timeZone = TimeZone.getTimeZone("UTC")
            val now = sdf.format(Date())
            
            db.execSQL("INSERT INTO pending_points (lat, lon, recorded_at) VALUES (?, ?, ?)", arrayOf(lat, lon, now))
            db.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                "LocationServiceChannel",
                "Location Tracking Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
