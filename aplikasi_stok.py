import streamlit as st
import sqlite3
from datetime import datetime

# ================= DATABASE =================
conn = sqlite3.connect("stok_barang.db", check_same_thread=False)
cursor = conn.cursor()

cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS stok (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nama_barang TEXT UNIQUE,
    jumlah INTEGER,
    waktu TEXT
)
""")

cursor.execute("""
CREATE TABLE IF NOT EXISTS transaksi (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nama_barang TEXT,
    aksi TEXT,
    jumlah INTEGER,
    waktu TEXT,
    user TEXT
)
""")

cursor.execute("SELECT * FROM users")
if not cursor.fetchone():
    cursor.execute("INSERT INTO users VALUES (NULL,'SUNNYGO','admin')")
    conn.commit()

# ================= UTIL =================
def now():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def refresh_data():
    cursor.execute("SELECT nama_barang, jumlah, waktu FROM stok ORDER BY nama_barang")
    stok_data = cursor.fetchall()

    cursor.execute("SELECT nama_barang, aksi, jumlah, waktu, user FROM transaksi ORDER BY id DESC")
    log_data = cursor.fetchall()

    return stok_data, log_data

# ================= LOGIN =================
if "login" not in st.session_state:
    st.session_state.login = False

if not st.session_state.login:
    st.title("🔐 Login Inventory")

    username = st.text_input("Username")
    password = st.text_input("Password", type="password")

    if st.button("Login"):
        cursor.execute("SELECT * FROM users WHERE username=? AND password=?", (username, password))
        if cursor.fetchone():
            st.session_state.login = True
            st.session_state.user = username
            st.rerun()
        else:
            st.error("Username / Password salah")

# ================= MAIN APP =================
else:
    st.title("📦 Inventory System (ERP Style)")
    st.write(f"Login sebagai: **{st.session_state.user}**")

    tab1, tab2, tab3, tab4 = st.tabs(["Master Data", "Input Stok", "Output Stok", "Riwayat"])

    # ================= MASTER =================
    with tab1:
        stok_data, _ = refresh_data()
        st.dataframe(stok_data, use_container_width=True)

    # ================= INPUT =================
    with tab2:
        nama = st.text_input("Nama Barang")
        jml = st.number_input("Jumlah", min_value=0, step=1)

        if st.button("Simpan Stok Masuk"):
            if nama and jml > 0:
                cursor.execute("SELECT id, jumlah, nama_barang FROM stok WHERE nama_barang = ? COLLATE NOCASE", (nama,))
                data = cursor.fetchone()

                if data:
                    cursor.execute("UPDATE stok SET jumlah=?, waktu=? WHERE id=?",
                                   (data[1] + jml, now(), data[0]))
                    nama = data[2]
                else:
                    cursor.execute("INSERT INTO stok VALUES (NULL,?,?,?)",
                                   (nama, jml, now()))

                cursor.execute("INSERT INTO transaksi VALUES (NULL,?,?,?,?,?)",
                               (nama, "MASUK", jml, now(), st.session_state.user))
                conn.commit()
                st.success("Stok berhasil ditambahkan")
                st.rerun()

    # ================= OUTPUT =================
    with tab3:
        nama_out = st.text_input("Nama Barang Keluar")
        jml_out = st.number_input("Jumlah Keluar", min_value=0, step=1)

        if st.button("Simpan Stok Keluar"):
            cursor.execute("SELECT id, jumlah, nama_barang FROM stok WHERE nama_barang = ? COLLATE NOCASE", (nama_out,))
            data = cursor.fetchone()

            if not data:
                st.error("Barang tidak ditemukan")
            elif data[1] < jml_out:
                st.error("Stok tidak cukup")
            else:
                cursor.execute("UPDATE stok SET jumlah=?, waktu=? WHERE id=?",
                               (data[1] - jml_out, now(), data[0]))

                cursor.execute("INSERT INTO transaksi VALUES (NULL,?,?,?,?,?)",
                               (data[2], "KELUAR", jml_out, now(), st.session_state.user))

                conn.commit()
                st.success("Stok berhasil dikurangi")
                st.rerun()

    # ================= RIWAYAT =================
    with tab4:
        _, log_data = refresh_data()
        st.dataframe(log_data, use_container_width=True)

    if st.button("Logout"):
        st.session_state.login = False
        st.rerun()
