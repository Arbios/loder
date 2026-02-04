import uuid
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from database import get_db
from utils import generate_room_id

rooms_bp = Blueprint('rooms', __name__)

# Users are considered offline after 15 seconds without heartbeat
OFFLINE_THRESHOLD_SECONDS = 15

@rooms_bp.route('/create', methods=['POST'])
def create_room():
    data = request.get_json()
    if not data or 'userId' not in data:
        return jsonify({'error': 'userId is required'}), 400

    user_id = data['userId']
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

    # Create room
    cursor.execute('INSERT INTO rooms (id, created_by) VALUES (?, ?)', (room_id, user_id))

    # Add creator as member
    cursor.execute(
        'INSERT INTO room_members (room_id, user_id, active_app, last_seen) VALUES (?, ?, ?, ?)',
        (room_id, user_id, None, datetime.utcnow())
    )

    conn.commit()
    conn.close()

    return jsonify({'roomId': room_id}), 201

@rooms_bp.route('/<room_id>/join', methods=['POST'])
def join_room(room_id):
    data = request.get_json()
    if not data or 'userId' not in data:
        return jsonify({'error': 'userId is required'}), 400

    user_id = data['userId']
    conn = get_db()
    cursor = conn.cursor()

    # Check if room exists
    cursor.execute('SELECT id FROM rooms WHERE id = ?', (room_id,))
    if not cursor.fetchone():
        conn.close()
        return jsonify({'error': 'Room not found'}), 404

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

    # Update heartbeat
    now = datetime.utcnow()
    cursor.execute('''
        UPDATE room_members
        SET active_app = ?, last_seen = ?
        WHERE room_id = ? AND user_id = ?
    ''', (active_app, now, room_id, user_id))

    conn.commit()

    # Get all members with online status
    threshold = now - timedelta(seconds=OFFLINE_THRESHOLD_SECONDS)
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
            'isOnline': is_online
        })

    conn.close()

    return jsonify({'members': members})
