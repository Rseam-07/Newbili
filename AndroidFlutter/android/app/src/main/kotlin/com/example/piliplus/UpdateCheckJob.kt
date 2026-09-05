package com.example.piliplus

import android.app.job.JobParameters
import android.app.job.JobService
import java.util.concurrent.Executors
import java.util.concurrent.Future

class UpdateCheckJob : JobService() {
    private val executor = Executors.newSingleThreadExecutor()
    private var task: Future<*>? = null

    override fun onStartJob(params: JobParameters): Boolean {
        task = executor.submit {
            try { UpdateMonitor.get(this).checkUpdates() }
            finally { if (!Thread.currentThread().isInterrupted) jobFinished(params, false) }
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        task?.cancel(true)
        return true
    }

    override fun onDestroy() {
        task?.cancel(true)
        executor.shutdownNow()
        super.onDestroy()
    }
}
