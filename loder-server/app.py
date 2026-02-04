import os
from flask import Flask, render_template_string
from flask_cors import CORS
from database import init_db, get_db
from config import AVATARS_DIR
from routes.users import users_bp
from routes.rooms import rooms_bp
from routes.auth import auth_bp
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app)

# Ensure avatars directory exists
os.makedirs(AVATARS_DIR, exist_ok=True)

# Initialize database
init_db()

# Register blueprints
app.register_blueprint(users_bp, url_prefix='/api/v1/users')
app.register_blueprint(rooms_bp, url_prefix='/api/v1/rooms')
app.register_blueprint(auth_bp, url_prefix='/api/v1/auth')

@app.route('/api/v1/health')
def health():
    return {'status': 'ok'}

DEBUG_HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>Loder Debug - Room {{ room_id }}</title>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; background: #1a1a1a; color: #fff; }
        h1 { color: #4CAF50; }
        .room-id { font-family: monospace; background: #333; padding: 10px; border-radius: 5px; font-size: 24px; }
        .member { padding: 15px; margin: 10px 0; border-radius: 8px; background: #2a2a2a; display: flex; align-items: center; gap: 15px; }
        .avatar { width: 50px; height: 50px; border-radius: 50%; background: #444; display: flex; align-items: center; justify-content: center; }
        .avatar img { width: 100%; height: 100%; border-radius: 50%; object-fit: cover; }
        .status { display: flex; gap: 10px; align-items: center; }
        .badge { padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; }
        .online { background: #4CAF50; color: white; }
        .offline { background: #666; color: #aaa; }
        .active { background: #ff9800; color: white; }
        .inactive { background: #333; color: #666; }
        .user-id { font-family: monospace; font-size: 11px; color: #666; }
        .last-seen { color: #888; font-size: 12px; }
        .refresh-info { color: #666; font-size: 12px; margin-top: 20px; }
        .no-members { color: #888; font-style: italic; }
    </style>
</head>
<body>
    <h1>🔍 Loder Debug</h1>
    <p>Room: <span class="room-id">{{ room_id }}</span></p>
    <p class="refresh-info">Auto-refresh every 2 seconds | Last update: <span id="time">{{ now }}</span></p>

    <h2>Members ({{ members|length }})</h2>
    {% if members %}
        {% for m in members %}
        <div class="member">
            <div class="avatar">
                {% if m.avatar_path %}
                <img src="/api/v1/users/{{ m.user_id }}/avatar" alt="avatar">
                {% else %}
                👤
                {% endif %}
            </div>
            <div>
                <div class="status">
                    <span class="badge {{ 'online' if m.is_online else 'offline' }}">
                        {{ 'ONLINE' if m.is_online else 'OFFLINE' }}
                    </span>
                    <span class="badge {{ 'active' if m.active_app else 'inactive' }}">
                        {{ m.active_app if m.active_app else '💤 Idle' }}
                    </span>
                </div>
                <div class="user-id">{{ m.user_id }}</div>
                <div class="last-seen">Last seen: {{ m.last_seen }}</div>
            </div>
        </div>
        {% endfor %}
    {% else %}
        <p class="no-members">No members in this room</p>
    {% endif %}

    <script>
        setTimeout(() => location.reload(), 2000);
    </script>
</body>
</html>
'''

@app.route('/debug/<room_id>')
def debug_room(room_id):
    conn = get_db()
    cursor = conn.cursor()

    # Check if room exists
    cursor.execute('SELECT id FROM rooms WHERE id = ?', (room_id,))
    if not cursor.fetchone():
        conn.close()
        return f'Room {room_id} not found', 404

    # Get members
    threshold = datetime.utcnow() - timedelta(seconds=15)
    cursor.execute('''
        SELECT u.id as user_id, u.avatar_path, rm.active_app, rm.last_seen
        FROM room_members rm
        JOIN users u ON rm.user_id = u.id
        WHERE rm.room_id = ?
    ''', (room_id,))

    members = []
    for row in cursor.fetchall():
        last_seen = datetime.fromisoformat(row['last_seen']) if row['last_seen'] else None
        is_online = bool(last_seen and last_seen > threshold)
        members.append({
            'user_id': row['user_id'],
            'avatar_path': row['avatar_path'],
            'active_app': row['active_app'] if is_online else None,
            'is_online': is_online,
            'last_seen': row['last_seen']
        })

    conn.close()

    return render_template_string(
        DEBUG_HTML,
        room_id=room_id,
        members=members,
        now=datetime.utcnow().strftime('%H:%M:%S')
    )

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
