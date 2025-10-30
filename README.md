
### Dokumentasi Kode

Proyek ini menggunakan beberapa variabel state untuk mengelola tampilan dan logika aplikasi. Berikut adalah daftar variabel utama yang ada di dalam class `_WifiHomePageState` pada file `lib/main.dart`:

#### Variabel Utama UI & Daftar Jaringan

*   **`_wifiNetworks`**: `List<WifiNetwork>`
    *   **Deskripsi**: Menyimpan daftar objek `WifiNetwork` yang merupakan hasil dari pemindaian jaringan Wi-Fi.
    *   **Dipanggil di**:
        *   `_startScan()`: Diisi dengan hasil dari `WiFiForIoTPlugin.loadWifiList()`.
        *   `build()`: Digunakan oleh `ListView.builder` untuk menampilkan setiap jaringan Wi-Fi ke layar.

*   **`_isScanning`**: `bool`
    *   **Deskripsi**: Flag untuk menandakan apakah proses pemindaian Wi-Fi sedang berlangsung.
    *   **Dipanggil di**:
        *   `_startScan()`: Diatur ke `true` saat pemindaian dimulai dan `false` saat selesai.
        *   `build()`: Digunakan untuk menonaktifkan tombol "Pindai Ulang" dan menampilkan `CircularProgressIndicator` saat `true`.

*   **`_connectionStatus`**: `String`
    *   **Deskripsi**: Menyimpan teks status koneksi yang ditampilkan di bagian atas layar (misalnya, "Terhubung ke: NamaWifi" atau "Tidak ada koneksi Wi-Fi").
    *   **Dipanggil di**:
        *   `_updateConnectionStatus()`: Diperbarui berdasarkan status koneksi saat ini.
        *   `build()`: Ditampilkan di dalam widget `Text`.

*   **`_isConnected`**: `bool`
    *   **Deskripsi**: Flag utama yang menandakan apakah perangkat sedang terhubung ke jaringan Wi-Fi.
    *   **Dipanggil di**:
        *   `_updateConnectionStatus()`: Diatur ke `true` jika terhubung, `false` jika tidak.
        *   `build()`: Digunakan untuk menampilkan atau menyembunyikan bagian "Analisa Jaringan" dan tombol "Refresh Analisa".

#### Variabel untuk Analisa Jaringan

Variabel-variabel ini digunakan untuk menyimpan hasil dari analisa latensi dan radio jaringan. Mereka diisi oleh fungsi `_updateNetworkAnalysis()`.

*   **`_gatewayPing`**: `String?`
    *   **Deskripsi**: Menyimpan hasil latensi (ping) ke alamat IP gateway dalam milidetik (ms).
    *   **Dipanggil di**: `_buildNetworkAnalysisSection()` untuk ditampilkan di kartu "Analisa Latensi Jaringan".

*   **`_googlePing`**: `String?`
    *   **Deskripsi**: Menyimpan hasil latensi (ping) ke `google.com` dalam milidetik (ms).
    *   **Dipanggil di**: `_buildNetworkAnalysisSection()` untuk ditampilkan di kartu "Analisa Latensi Jaringan".

*   **`_ontAttenuation`**: `String`
    *   **Deskripsi**: Menyimpan nilai *dummy* untuk redaman ONT. Saat ini di-hardcode ke `'-20 dBm'`.
    *   **Dipanggil di**: `_buildNetworkAnalysisSection()` untuk ditampilkan di kartu "Analisa Latensi Jaringan".

*   **`_wifiBand`**: `String?`
    *   **Deskripsi**: Menyimpan spektrum/band Wi-Fi yang sedang digunakan (misalnya, "2.4 GHz" atau "5 GHz"). Dihitung dari frekuensi.
    *   **Dipanggil di**: `_buildNetworkAnalysisSection()` untuk ditampilkan di kartu "Analisa Radio Jaringan".

*   **`_wifiChannel`**: `int?`
    *   **Deskripsi**: Menyimpan nomor channel Wi-Fi yang sedang digunakan. Dihitung dari frekuensi.
    *   **Dipanggil di**: `_buildNetworkAnalysisSection()` untuk ditampilkan di kartu "Analisa Radio Jaringan".

*   **`_currentSignalStrength`**: `int?`
    *   **Deskripsi**: Menyimpan kekuatan sinyal (RSSI) dari jaringan yang sedang terhubung, dalam satuan dBm.
    *   **Dipanggil di**: `_buildNetworkAnalysisSection()` untuk ditampilkan di kartu "Analisa Radio Jaringan".

*   **`_isAnalyzingLatency`**: `bool`
    *   **Deskripsi**: Flag untuk menandakan apakah proses analisa jaringan (terutama ping) sedang berjalan.
    *   **Dipanggil di**:
        *   `_updateNetworkAnalysis()`: Diatur ke `true` saat analisa dimulai dan `false` saat selesai.
        *   `build()`: Digunakan untuk menonaktifkan tombol "Refresh Analisa" saat `true`.
