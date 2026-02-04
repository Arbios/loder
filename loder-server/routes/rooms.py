import uuid
import hashlib
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from database import get_db
from utils import generate_room_id

rooms_bp = Blueprint('rooms', __name__)

# Users are considered offline after 15 seconds without heartbeat
OFFLINE_THRESHOLD_SECONDS = 15
MAX_MEMBERS_PER_ROOM = 10

def hash_password(password):
    """Simple password hashing"""
    if not password:
        return None
    return hashlib.sha256(password.encode()).hexdigest()

@rooms_bp.route('/create', methods=['POST'])
def create_room():
    data = request.get_json()
    if not data or 'userId' not in data:
        return jsonify({'error': 'userId is required'}), 400

    user_id = data['userId']
    password = data.get('password')  # Optional password

    conn = get_db()
    cursor = conn.cursor()

    # Check if user exists
    cursor.execute('SELECT id FROM users WHERE id = ?', (user_id,))
    if not cursor.fetchone():
        conn.close()
        return jsonify({'error': 'User not found'}), 404

    # Generate unique room ID
    for _ in range(10):  # Try up to 10 times to get unique ID
        room_id = generate_room_id()
        cursor.execute('SELECT id FROM rooms WHERE id = ?', (room_id,))
        if not cursor.fetchone():
            break
    else:
        conn.close()
        return jsonify({'error': 'Failed to generate unique room ID'}), 500

    # Create room with optional password
    password_hash = hash_password(password) if password else None
    cursor.execute(
        'INSERT INTO rooms (id, created_by, password, max_members) VALUES (?, ?, ?, ?)',
        (room_id, user_id, password_hash, MAX_MEMBERS_PER_ROOM)
    )

    # Add creator as member
    cursor.execute(
        'INSERT INTO room_members (room_id, user_id, active_app, last_seen) VALUES (?, ?, ?, ?)',
        (room_id, user_id, None, datetime.utcnow())
    )

    conn.commit()
    conn.close()

    return jsonify({'roomId': room_id, 'hasPassword': bool(password)}), 201

@rooms_bp.route('/<room_id>/join', methods=['POST'])
def join_room(room_id):
    data = request.get_json()
    if not data or 'userId' not in data:
        return jsonify({'error': 'userId is required'}), 400

    user_id = data['userId']
    password = data.get('password')

    conn = get_db()
    cursor = conn.cursor()

    # Check if room exists and get password
    cursor.execute('SELECT id, password, max_members FROM rooms WHERE id = ?', (room_id,))
    room = cursor.fetchone()
    if not room:
        conn.close()
        return jsonify({'error': 'Room not found'}), 404

    # Check password if room is protected
    if room['password']:
        if not password:
            conn.close()
            return jsonify({'error': 'Password required', 'passwordRequired': True}), 401
        if hash_password(password) != room['password']:
            conn.close()
            return jsonify({'error': 'Wrong password'}), 401

    # Check if user exists
    cursor.execute('SELECT id FROM users WHERE id = ?', (user_id,))
    if not cursor.fetchone():
        conn.close()
        return jsonify({'error': 'User not found'}), 404

    # Check if already a member
    cursor.execute(
        'SELECT room_id FROM room_members WHERE room_id = ? AND user_id = ?',
        (room_id, user_id)
    )
    if cursor.fetchone():
        conn.close()
        return jsonify({'message': 'Already a member'})

    # Check member count limit
    cursor.execute('SELECT COUNT(*) as count FROM room_members WHERE room_id = ?', (room_id,))
    member_count = cursor.fetchone()['count']
    max_members = room['max_members'] or MAX_MEMBERS_PER_ROOM
    if member_count >= max_members:
        conn.close()
        return jsonify({'error': f'Room is full (max {max_members} members)'}), 403

    # Add as member
    cursor.execute(
        'INSERT INTO room_members (room_id, user_id, active_app, last_seen) VALUES (?, ?, ?, ?)',
        (room_id, user_id, None, datetime.utcnow())
    )

    conn.commit()
    conn.close()

    return jsonify({'message': 'Joined room successfully'})

@rooms_bp.route('/<room_id>/leave', methods=['POST'])
def leave_room(room_id):
    data = request.get_json()
    if not data or 'userId' not in data:
        return jsonify({'error': 'userId is required'}), 400

    user_id = data['userId']
    conn = get_db()
    cursor = conn.cursor()

    # Remove from room
    cursor.execute(
        'DELETE FROM room_members WHERE room_id = ? AND user_id = ?',
        (room_id, user_id)
    )

    conn.commit()
    conn.close()

    return jsonify({'message': 'Left room successfully'})

@rooms_bp.route('/<room_id>', methods=['GET'])
def get_room(room_id):
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute('SELECT id, created_by, created_at FROM rooms WHERE id = ?', (room_id,))
    room = cursor.fetchone()

    if not room:
        conn.close()
        return jsonify({'error': 'Room not found'}), 404

    # Get members with their info
    threshold = datetime.utcnow() - timedelta(seconds=OFFLINE_THRESHOLD_SECONDS)
    cursor.execute('''
        SELECT u.id, u.avatar_path, rm.active_app, rm.last_seen
        FROM room_members rm
        JOIN users u ON rm.user_id = u.id
        WHERE rm.room_id = ?
    ''', (room_id,))

    members = []
    for row in cursor.fetchall():
        last_seen = datetime.fromisoformat(row['last_seen']) if row['last_seen'] else None
        is_online = bool(last_seen and last_seen > threshold)
        members.append({
            'userId': row['id'],
            'avatarPath': row['avatar_path'],
            'activeApp': row['active_app'] if is_online else None,
            'isOnline': is_online,
            'lastSeen': row['last_seen']
        })

    conn.close()

    return jsonify({
        'roomId': room['id'],
        'createdBy': room['created_by'],
        'createdAt': room['created_at'],
        'members': members
    })

@rooms_bp.route('/<room_id>/heartbeat', methods=['POST'])
def heartbeat(room_id):
    data = request.get_json()
    if not data or 'userId' not in data:
        return jsonify({'error': 'userId is required'}), 400

    user_id = data['userId']
    active_app = data.get('activeApp')  # None = idle, String = app name
    focus_mode = data.get('focusMode', False)  # Focus mode hides status

    conn = get_db()
    cursor = conn.cursor()

    # Check if user is member of room
    cursor.execute(
        'SELECT room_id FROM room_members WHERE room_id = ? AND user_id = ?',
        (room_id, user_id)
    )
    if not cursor.fetchone():
        conn.close()
        return jsonify({'error': 'Not a member of this room'}), 403

    # Update heartbeat with focus mode
    now = datetime.utcnow()
    cursor.execute('''
        UPDATE room_members
        SET active_app = ?, last_seen = ?, focus_mode = ?
        WHERE room_id = ? AND user_id = ?
    ''', (active_app, now, focus_mode, room_id, user_id))

    # Log activity for statistics (only if user is active in an app and not in focus mode)
    if active_app and not focus_mode:
        cursor.execute('''
            INSERT INTO activity_logs (room_id, user_id, app_name, duration_seconds, logged_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (room_id, user_id, active_app, 5, now))  # 5 seconds per heartbeat

    conn.commit()

    # Get all members with online status
    threshold = now - timedelta(seconds=OFFLINE_THRESHOLD_SECONDS)
    cursor.execute('''
        SELECT u.id, u.avatar_path, rm.active_app, rm.last_seen, rm.focus_mode
        FROM room_members rm
        JOIN users u ON rm.user_id = u.id
        WHERE rm.room_id = ?
    ''', (room_id,))

    members = []
    for row in cursor.fetchall():
        last_seen = datetime.fromisoformat(row['last_seen']) if row['last_seen'] else None
        is_online = bool(last_seen and last_seen > threshold)
        is_focus = bool(row['focus_mode']) if row['focus_mode'] is not None else False
        members.append({
            'userId': row['id'],
            'avatarPath': row['avatar_path'],
            'activeApp': None if is_focus else (row['active_app'] if is_online else None),
            'isOnline': is_online,
            'focusMode': is_focus
        })

    conn.close()

    return jsonify({'members': members})


@rooms_bp.route('/<room_id>/stats', methods=['GET'])
def get_room_stats(room_id):
    """Get comprehensive statistics for a room"""
    user_id = request.args.get('userId')
    period = request.args.get('period', 'today')  # today, week, all

    conn = get_db()
    cursor = conn.cursor()

    # Check if user is member of room
    if user_id:
        cursor.execute(
            'SELECT room_id FROM room_members WHERE room_id = ? AND user_id = ?',
            (room_id, user_id)
        )
        if not cursor.fetchone():
            conn.close()
            return jsonify({'error': 'Not a member of this room'}), 403

    # Determine time range
    now = datetime.utcnow()
    if period == 'today':
        start_time = now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == 'week':
        start_time = now - timedelta(days=7)
    else:
        start_time = datetime(2000, 1, 1)  # All time

    # Get all members
    cursor.execute('''
        SELECT u.id, u.avatar_path
        FROM room_members rm
        JOIN users u ON rm.user_id = u.id
        WHERE rm.room_id = ?
    ''', (room_id,))
    members = {row['id']: {'userId': row['id'], 'avatarPath': row['avatar_path']} for row in cursor.fetchall()}

    # Get total time per user
    cursor.execute('''
        SELECT user_id, SUM(duration_seconds) as total_seconds
        FROM activity_logs
        WHERE room_id = ? AND logged_at >= ?
        GROUP BY user_id
    ''', (room_id, start_time))

    user_totals = {}
    for row in cursor.fetchall():
        user_totals[row['user_id']] = row['total_seconds'] or 0

    # Get time per app per user
    cursor.execute('''
        SELECT user_id, app_name, SUM(duration_seconds) as total_seconds
        FROM activity_logs
        WHERE room_id = ? AND logged_at >= ?
        GROUP BY user_id, app_name
        ORDER BY total_seconds DESC
    ''', (room_id, start_time))

    user_apps = {}
    for row in cursor.fetchall():
        uid = row['user_id']
        if uid not in user_apps:
            user_apps[uid] = []
        user_apps[uid].append({
            'appName': row['app_name'],
            'totalSeconds': row['total_seconds'] or 0
        })

    # Get hourly activity for today (for timeline chart)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    cursor.execute('''
        SELECT user_id, strftime('%H', logged_at) as hour, SUM(duration_seconds) as total_seconds
        FROM activity_logs
        WHERE room_id = ? AND logged_at >= ?
        GROUP BY user_id, hour
        ORDER BY hour
    ''', (room_id, today_start))

    hourly_activity = {}
    for row in cursor.fetchall():
        uid = row['user_id']
        if uid not in hourly_activity:
            hourly_activity[uid] = {str(h).zfill(2): 0 for h in range(24)}
        hourly_activity[uid][row['hour']] = row['total_seconds'] or 0

    # Get top apps overall
    cursor.execute('''
        SELECT app_name, SUM(duration_seconds) as total_seconds
        FROM activity_logs
        WHERE room_id = ? AND logged_at >= ?
        GROUP BY app_name
        ORDER BY total_seconds DESC
        LIMIT 10
    ''', (room_id, start_time))

    top_apps = [{'appName': row['app_name'], 'totalSeconds': row['total_seconds'] or 0} for row in cursor.fetchall()]

    conn.close()

    # Build response
    member_stats = []
    for uid, member in members.items():
        member_stats.append({
            **member,
            'totalSeconds': user_totals.get(uid, 0),
            'apps': user_apps.get(uid, []),
            'hourlyActivity': hourly_activity.get(uid, {str(h).zfill(2): 0 for h in range(24)})
        })

    # Sort by total time
    member_stats.sort(key=lambda x: x['totalSeconds'], reverse=True)

    return jsonify({
        'roomId': room_id,
        'period': period,
        'members': member_stats,
        'topApps': top_apps,
        'generatedAt': now.isoformat()
    })


@rooms_bp.route('/<room_id>/check', methods=['GET'])
def check_room(room_id):
    """Check if room exists and if it requires password"""
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute('SELECT id, password FROM rooms WHERE id = ?', (room_id,))
    room = cursor.fetchone()
    conn.close()

    if not room:
        return jsonify({'exists': False}), 404

    return jsonify({
        'exists': True,
        'hasPassword': bool(room['password'])
    })
