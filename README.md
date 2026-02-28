# ☕ Balance

**Balance** adalah aplikasi seluler yang dirancang untuk menyederhanakan proses pelaporan operasional harian, khususnya untuk kebutuhan store. Aplikasi ini menggabungkan laporan sales, manajemen barcode, foto grid, serta sinkronisasi dan backup data dalam satu platform terpadu.

Balance hadir untuk menggantikan proses manual yang sebelumnya dilakukan melalui template panjang di WhatsApp dan penggunaan banyak aplikasi terpisah.

---

## 🖼️ Tampilan Aplikasi

Aplikasi Balance 

<img width="2408" height="2043" alt="Balance Apps" src="https://github.com/user-attachments/assets/13d28f00-5ee5-4117-816e-f7581710b759" />

---

## ✨ Fitur Utama

### 📝 Laporan Sales Multi-Shift
- Mendukung hingga **4 shift per hari**
- Perhitungan otomatis:
  - Total Sales
  - Std
  - APC
  - Cup
  - Add
- Format laporan siap kirim ke **WhatsApp**
- Auto-save draft harian untuk mencegah kehilangan data

---

### 🏪 Store Management
- Pengaturan:
  - Nama toko
  - Kode toko
  - Area
  - Tanggal GO
- Konfigurasi jumlah shift
- Penyimpanan lokal menggunakan SharedPreferences

---

### 📦 Barcode Management
- Scan dan simpan barcode barang
- Penyimpanan data lokal
- Sinkronisasi online ke Firebase

---

### ☁️ Sinkronisasi & Backup
- Sinkronisasi data ke Cloud Firestore
- Backup data online
- Riwayat waktu sync & backup
- Sistem cooldown untuk mencegah spam

---

### 🔐 Autentikasi Pengguna
- Login / Register (Email & Password)
- Update nama profil
- Session management
- Error handling spesifik FirebaseAuthException

---

### 💰 Monetisasi
- Banner Ads
- Rewarded Ads (digunakan untuk fitur Sync & Backup)
- Iklan ditempatkan secara strategis tanpa mengganggu pengalaman pengguna

---

## 💻 Teknologi yang Digunakan

| Kategori | Teknologi | Keterangan |
|----------|------------|------------|
| Framework | Flutter | UI & Cross-platform |
| State Management | Provider | Auth & Local State |
| Authentication | Firebase Auth | Login & Register |
| Database | Cloud Firestore | Backup & Sync |
| Local Storage | SharedPreferences | Draft & Setting |
| Ads | Google Mobile Ads | Banner & Rewarded |
| Integration | url_launcher | Kirim laporan ke WhatsApp |

---

## 📂 Struktur State Management

### FirebaseAuthProvider
- Login
- Register
- Logout
- Update profil

### SharedPreferenceProvider
- Simpan nomor WhatsApp
- Simpan jumlah shift

### BarcodeFirebaseService
- Sync barcode
- Backup barcode
- Ambil waktu terakhir sync/backup

### SharedPreferencesService
- Simpan laporan harian
- Simpan draft otomatis
- Kelola data store

---

## 🔄 Alur Kerja Aplikasi

1. User login
2. Isi data store
3. Input laporan per shift
4. Sistem menghitung total dan APC otomatis
5. Data tersimpan sebagai draft
6. Kirim laporan ke WhatsApp
7. Foto grid untuk laporan foto
8. Barcode untuk scan barang
9. Opsional: Sync atau Backup data ke Firebase
