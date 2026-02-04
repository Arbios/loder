import os
import uuid
from flask import Blueprint, request, jsonify, send_file
from database import get_db
from config import AVATARS_DIR, MAX_AVATAR_SIZE, ALLOWED_EXTENSIONS

users_bp = Blueprint('users', __name__)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@users_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data or 'deviceId' not in data:
        return jsonify({'error': 'deviceId is required'}), 400

    device_id = data['deviceId']
    conn = get_db()
    cursor = conn.cursor()

    # Check if user already exists
    cursor.execute('SELECT id, device_id, avatar_path, created_at FROM users WHERE device_id = ?', (device_id,))
    row = cursor.fetchone()

    if row:
        conn.close()
        return jsonify({
            'id': row['id'],
            'deviceId': row['device_id'],
            'avatarPath': row['avatar_path'],
            'isNew': False
        })

    # Create new user
    user_id = str(uuid.uuid4())
    cursor.execute('INSERT INTO users (id, device_id) VALUES (?, ?)', (user_id, device_id))
    conn.commit()
    conn.close()

    return jsonify({
        'id': user_id,
        'deviceId': device_id,
        'avatarPath': None,
        'isNew': True
    }), 201

@users_bp.route('/<user_id>/avatar', methods=['POST'])
def upload_avatar(user_id):
    conn = get_db()
    cursor = conn.cursor()

    # Check if user exists
    cursor.execute('SELECT id FROM users WHERE id = ?', (user_id,))
    if not cursor.fetchone():
        conn.close()
        return jsonify({'error': 'User not found'}), 404

    if 'avatar' not in request.files:
        conn.close()
        return jsonify({'error': 'No avatar file provided'}), 400

    file = request.files['avatar']
    if file.filename == '':
        conn.close()
        return jsonify({'error': 'No file selected'}), 400

    if not allowed_file(file.filename):
        conn.close()
        return jsonify({'error': 'Invalid file type'}), 400

    # Check file size
    file.seek(0, 2)
    size = file.tell()
    file.seek(0)
    if size > MAX_AVATAR_SIZE:
        conn.close()
        return jsonify({'error': 'File too large (max 1MB)'}), 400

    # Save file
    ext = file.filename.rsplit('.', 1)[1].lower()
    filename = f'{user_id}.{ext}'
    filepath = os.path.join(AVATARS_DIR, filename)

    # Remove old avatar if exists
    cursor.execute('SELECT avatar_path FROM users WHERE id = ?', (user_id,))
    row = cursor.fetchone()
    if row and row['avatar_path']:
        old_path = os.path.join(AVATARS_DIR, row['avatar_path'])
        if os.path.exists(old_path):
            os.remove(old_path)

    file.save(filepath)

    # Update database
    cursor.execute('UPDATE users SET avatar_path = ? WHERE id = ?', (filename, user_id))
    conn.commit()
    conn.close()

    return jsonify({'avatarPath': filename})

@users_bp.route('/<user_id>/avatar', methods=['GET'])
def get_avatar(user_id):
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute('SELECT avatar_path FROM users WHERE id = ?', (user_id,))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return jsonify({'error': 'User not found'}), 404

    if not row['avatar_path']:
        return jsonify({'error': 'No avatar set'}), 404

    filepath = os.path.join(AVATARS_DIR, row['avatar_path'])
    if not os.path.exists(filepath):
        return jsonify({'error': 'Avatar file not found'}), 404

    return send_file(filepath)
