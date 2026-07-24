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
import android.content.ContentValues                                                                                                           
import android.util.Log
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors


class LocationTrackerService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var db: SQLiteDatabase? = null                                                                                                     
    private val dbExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var activeSessionId: String? = null

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        openDatabase()
        
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    saveLocationToDatabase(location.latitude, location.longitude)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        activeSessionId = intent?.getStringExtra("sessionId") ?: activeSessionId
        
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, "LocationServiceChannel")
            .setContentTitle("Life Tracker")
            .setContentText("Recording your route in the Background.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .build()
            
        startForeground(1, notification)
        startLocationUpdates()
        return START_REDELIVER_INTENT
    }

    private fun startLocationUpdates() {
        // Optimized for battery using hardware batching
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 15000) 
            .setMinUpdateDistanceMeters(5f)
            .setMaxUpdateDelayMillis(30000) // Hardware batching up to 30 seconds
            .build()
            
        try {
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun saveLocationToDatabase(lat: Double, lon: Double) {
        val currentSessionId = activeSessionId ?: return
        
        // This pushes the disk I/O off the main UI thread!
        dbExecutor.execute {
            val database = db ?: return@execute
            try {
                database.beginTransaction()
                
                val pointId = UUID.randomUUID().toString()
                val timestamp = System.currentTimeMillis()

                val values = ContentValues().apply {
                    put("id", pointId)
                    put("session_id", currentSessionId)
                    put("lat", lat)
                    put("lon", lon)
                    put("timestamp", timestamp)
                }
                database.insert("gps_points", null, values)
                
                // Outbox Pattern
                val outboxValues = ContentValues().apply {
                    put("event_type", "POINTS_APPEND")
                    put("payload", "{\"point_id\":\"\$pointId\"}")
                    put("created_at", timestamp)
                }
                database.insert("outbox_events", null, outboxValues)
                
                database.setTransactionSuccessful()
            } catch (e: Exception) {
                Log.e("LocationTracker", "Failed to save location", e)
            } finally {
                database.endTransaction()
            }
        }
    }

    override fun onDestroy() {                                                                                                                 
        super.onDestroy()                                                                                                                      
        fusedLocationClient.removeLocationUpdates(locationCallback)                                                                            
        dbExecutor.shutdown()                                                                                    
        db?.close()                                                                                                
        Log.i("LocationTracker", "Service destroyed, DB closed")                                                                               
    }  

    override fun onBind(intent: Intent?): IBinder? = null

    private fun openDatabase() {                                                                                                               
        try {                                                                                                                                  
            val dbPath = getDatabasePath("life_tracker_v3.db").absolutePath                                                                       
            db = SQLiteDatabase.openOrCreateDatabase(dbPath, null)
            db?.execSQL("PRAGMA foreign_keys=ON;")                                                                                                            
            
            db?.execSQL("""                                                                                                                    
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    start_time INTEGER NOT NULL,
                    end_time INTEGER,
                    status TEXT NOT NULL,
                    sync_state TEXT NOT NULL
                )                                                                                                                             
            """.trimIndent())
            
            db?.execSQL("""                                                                                                                    
                CREATE TABLE IF NOT EXISTS gps_points (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    lat REAL NOT NULL,
                    lon REAL NOT NULL,
                    timestamp INTEGER NOT NULL,
                    FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE
                )                                                                                                                             
            """.trimIndent())
            
            db?.execSQL("""                                                                                                                    
                CREATE TABLE IF NOT EXISTS outbox_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_type TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    retry_count INTEGER NOT NULL DEFAULT 0
                )                                                                                                                             
            """.trimIndent())
            
            Log.i("LocationTracker", "Database opened v2")                                                                                        
        } catch (e: Exception) {                                                                                                               
            Log.e("LocationTracker", "Failed to open database", e)                                                                             
        }                                                                                                                                      
    }

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
