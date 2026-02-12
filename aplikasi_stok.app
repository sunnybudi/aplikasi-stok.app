import tkinter as tk
from tkinter import ttk, messagebox
import sqlite3
from datetime import datetime

# ================= DATABASE =================
conn = sqlite3.connect("stok_barang.db")
cursor = conn.cursor()

# --- USERS ---
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT
)
""")

cursor.execute("SELECT * FROM users")
if not cursor.fetchone():
    cursor.execute("INSERT INTO users VALUES (NULL,'SUNNYGO','admin')")

# --- STOK ---
cursor.execute("""
CREATE TABLE IF NOT EXISTS stok (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nama_barang TEXT UNIQUE,
    jumlah INTEGER,
    waktu TEXT
)
""")

# --- TRANSAKSI ---
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

conn.commit()

# ================= LOGIN =================
def login():
    global current_user
    u = entry_user.get().strip()
    p = entry_pass.get().strip()

    cursor.execute(
        "SELECT * FROM users WHERE username=? AND password=?",
        (u, p)
    )
    if cursor.fetchone():
        global current_user
        current_user = u
        login_win.withdraw()
        main_app()

    else:
        messagebox.showerror("Login Gagal", "Username / Password salah")

login_win = tk.Tk()
login_win.title("Login Inventory")
login_win.geometry("300x200")

tk.Label(login_win, text="Username").pack(pady=5)
entry_user = tk.Entry(login_win)
entry_user.pack()

tk.Label(login_win, text="Password").pack(pady=5)
entry_pass = tk.Entry(login_win, show="*")
entry_pass.pack()

tk.Button(login_win, text="Login", command=login).pack(pady=15)

# ================= MAIN APP =================
def main_app():
    root = tk.Toplevel()
    root.title("Inventory System (ERP Style)")
    root.geometry("1500x850")

    notebook = ttk.Notebook(root)
    notebook.pack(fill="both", expand=True)

    tab_master = ttk.Frame(notebook)
    tab_in = ttk.Frame(notebook)
    tab_out = ttk.Frame(notebook)
    tab_log = ttk.Frame(notebook)

    notebook.add(tab_master, text="📦 Master Data")
    notebook.add(tab_in, text="📥 Input Stok")
    notebook.add(tab_out, text="📤 Output Stok")
    notebook.add(tab_log, text="📜 Riwayat")

    # ================= UTIL =================
    def now():
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def load_stok(tree):
        tree.delete(*tree.get_children())
        cursor.execute("SELECT nama_barang, jumlah, waktu FROM stok ORDER BY nama_barang")
        for r in cursor.fetchall():
            tree.insert("", "end", values=r)

    def refresh_log():
        tree_log.delete(*tree_log.get_children())
        cursor.execute("""
            SELECT nama_barang, aksi, jumlah, waktu, user
            FROM transaksi 
            ORDER BY id DESC
        """)
        for r in cursor.fetchall():
            tree_log.insert("", "end", values=r)


    def refresh_all():
        print("REFRESH JALAN")
        load_stok(tree_master)
        load_stok(tree_in)
        load_stok(tree_out)
        refresh_log()


    # ================= MASTER DATA =================
    form_master = ttk.Frame(tab_master)
    form_master.pack(fill="x", pady=10)

    ttk.Label(form_master, text="User Login").grid(row=0, column=0)
    ttk.Label(form_master, text=current_user).grid(row=0, column=1, sticky="w", padx=10)

    ttk.Label(form_master, text="Status").grid(row=1, column=0)
    ttk.Label(form_master, text="Active").grid(row=1, column=1, sticky="w", padx=10)

    ttk.Button(
        form_master,
        text="🔄 Refresh",
        command=refresh_all
    ).grid(row=2, column=1, pady=10, sticky="w")

    tree_master = ttk.Treeview(
        tab_master,
        columns=("Barang", "Stok", "Update"),
        show="headings"
    )
    for c in tree_master["columns"]:
        tree_master.heading(c, text=c)
        tree_master.column(c, width=400)
    tree_master.pack(fill="both", expand=True)

    # ===== KLIK KANAN MASTER DATA =====
    menu_master = tk.Menu(root, tearoff=0)
    menu_master.add_command(
        label="🗑 Hapus Data",
        command=lambda: hapus_barang(tree_master)
    )

    def show_menu_master(event):
        row = tree_master.identify_row(event.y)
        if row:
            tree_master.selection_set(row)
            tree_master.focus(row)
            menu_master.tk_popup(event.x_root, event.y_root)

    tree_master.bind("<Button-3>", show_menu_master)

    def hapus_barang(tree):
        selected = tree.focus()
        if not selected:
            return

        nama_barang = tree.item(selected)["values"][0]

        if not messagebox.askyesno(
            "Konfirmasi Hapus",
            f"Yakin mau hapus data:\n\n{nama_barang} ?"
        ):
            return

        # CASE-SENSITIVE DELETE
        cursor.execute(
            "DELETE FROM stok WHERE nama_barang = ? COLLATE BINARY",
            (nama_barang,)
        )

        cursor.execute(
            "INSERT INTO transaksi VALUES (NULL,?,?,?,?,?)",
            (nama_barang, "DELETE", 0, now(), current_user)
        )

        conn.commit()
        refresh_all()

    # ================= INPUT STOK =================
    form_in = ttk.Frame(tab_in)
    form_in.pack(fill="x", pady=10)

    ttk.Label(form_in, text="Barang").grid(row=0, column=0)
    entry_in_barang = ttk.Entry(form_in, width=40)
    entry_in_barang.grid(row=0, column=1, padx=10)

    ttk.Label(form_in, text="Jumlah").grid(row=1, column=0)
    entry_in_jml = ttk.Entry(form_in, width=40)
    entry_in_jml.grid(row=1, column=1, padx=10)

    ttk.Button(form_in, text="📥 Simpan", command=lambda: stok_masuk())\
        .grid(row=2, column=1, pady=10)

    tree_in = ttk.Treeview(
        tab_in,
        columns=("Barang", "Stok", "Update"),
        show="headings"
    )
    for c in tree_in["columns"]:
        tree_in.heading(c, text=c)
        tree_in.column(c, width=400)
    tree_in.pack(fill="both", expand=True)

    def stok_masuk():
        nama = entry_in_barang.get().strip()
        try:
            jml = int(entry_in_jml.get())
        except:
            messagebox.showerror("Error", "Jumlah harus angka")
            return

        if not nama:
            messagebox.showerror("Error", "Nama barang kosong")
            return

        cursor.execute(
        "SELECT id, jumlah, nama_barang FROM stok WHERE nama_barang = ? COLLATE NOCASE",
        (nama,)
        )

        data = cursor.fetchone()

        if data:
            nama_asli = data[2]  
            cursor.execute(
                "UPDATE stok SET jumlah=?, waktu=? WHERE id=?",
                (data[1] + jml, now(), data[0])
            )
            nama = nama_asli  
        else:
            # kalau barang belum ada → buat baru
            cursor.execute(
                "INSERT INTO stok VALUES (NULL,?,?,?)",
                (nama, jml, now())
            )

        # tetap catat transaksi
        cursor.execute(
            "INSERT INTO transaksi VALUES (NULL,?,?,?,?,?)",
            (nama, "MASUK", jml, now(), current_user)
        )

        conn.commit()
        refresh_all()

        entry_in_barang.delete(0, tk.END)
        entry_in_jml.delete(0, tk.END)



    # ================= OUTPUT STOK =================
    form_out = ttk.Frame(tab_out)
    form_out.pack(fill="x", pady=10)

    ttk.Label(form_out, text="Barang").grid(row=0, column=0)
    entry_out_barang = ttk.Entry(form_out, width=40)
    entry_out_barang.grid(row=0, column=1, padx=10)

    ttk.Label(form_out, text="Jumlah").grid(row=1, column=0)
    entry_out_jml = ttk.Entry(form_out, width=40)
    entry_out_jml.grid(row=1, column=1, padx=10)

    ttk.Button(form_out, text="📤 Simpan", command=lambda: stok_keluar())\
        .grid(row=2, column=1, pady=10)

    tree_out = ttk.Treeview(
        tab_out,
        columns=("Barang", "Stok", "Update"),
        show="headings"
    )
    for c in tree_out["columns"]:
        tree_out.heading(c, text=c)
        tree_out.column(c, width=400)
    tree_out.pack(fill="both", expand=True)

    def stok_keluar():
        nama = entry_out_barang.get().strip()
        try:
            jml = int(entry_out_jml.get())
        except:
            return

        cursor.execute(
        "SELECT id, jumlah, nama_barang FROM stok WHERE nama_barang = ? COLLATE NOCASE",
        (nama,)
        )
        
        data = cursor.fetchone()
        if not data:
            messagebox.showerror("Error", "Barang tidak ditemukan")
            return

        if data[1] < jml:
            messagebox.showerror("Error", "Stok tidak cukup")
            return

        nama_asli = data[2]

        cursor.execute(
            "UPDATE stok SET jumlah=?, waktu=? WHERE id=?",
            (data[1] - jml, now(), data[0])
        )

        cursor.execute(
            "INSERT INTO transaksi VALUES (NULL,?,?,?,?,?)",
            (nama_asli, "KELUAR", jml, now(), current_user)
        )
        
        conn.commit()
        refresh_all()

        entry_out_barang.delete(0, tk.END)
        entry_out_jml.delete(0, tk.END)


    # ================= RIWAYAT =================
    tree_log = ttk.Treeview(
        tab_log,
        columns=("Barang", "Aksi", "Jumlah", "Waktu", "User"),
        show="headings"
    )
    # Header tetap perlu dibuat
    for c in tree_log["columns"]:
        tree_log.heading(c, text=c)

    # Atur lebar manual biar proporsional
    tree_log.column("Barang", width=200)
    tree_log.column("Aksi", width=120)
    tree_log.column("Jumlah", width=100)
    tree_log.column("Waktu", width=220)
    tree_log.column("User", width=120)

    tree_log.pack(fill="both", expand=True)

    tree_log.pack(fill="both", expand=True)
    refresh_all()
    root.mainloop()
    

login_win.mainloop()
