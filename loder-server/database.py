import sqlite3
from config import DATABASE_PATH

def get_db():
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            device_id TEXT UNIQUE,
            email TEXT UNIQUE,
            name TEXT,
            avatar_path TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # Add email and name columns if they don't exist (migration for existing DBs)
    try:
        cursor.execute('ALTER TABLE users ADD COLUMN email TEXT UNIQUE')
    except:
        pass  # Column already exists

    try:
        cursor.execute('ALTER TABLE users ADD COLUMN name TEXT')
    except:
        pass  # Column already exists

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS rooms (
            id TEXT PRIMARY KEY,
            created_by TEXT NOT NULL,
            password TEXT,
            max_members INTEGER DEFAULT 10,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (created_by) REFERENCES users(id)
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS room_members (
            room_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            active_app TEXT,
            last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            focus_mode BOOLEAN DEFAULT 0,
            PRIMARY KEY (room_id, user_id),
            FOREIGN KEY (room_id) REFERENCES rooms(id),
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    ''')

    # Add focus_mode column if it doesn't exist (migration for existing DBs)
    try:
        cursor.execute('ALTER TABLE room_members ADD COLUMN focus_mode BOOLEAN DEFAULT 0')
    except:
        pass  # Column already exists

    # Activity logs for statistics
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            app_name TEXT NOT NULL,
            duration_seconds INTEGER DEFAULT 5,
            logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (room_id) REFERENCES rooms(id),
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    ''')

    # Index for faster stats queries
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_activity_logs_room_user
        ON activity_logs(room_id, user_id, logged_at)
    ''')

    conn.commit()
    conn.close()
