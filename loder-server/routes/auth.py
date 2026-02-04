import os
import uuid
import requests
from flask import Blueprint, request, jsonify
from database import get_db
from config import GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/google', methods=['POST'])
def google_auth():
    """
    Authenticate with Google OAuth.
    Expects: { "idToken": "..." } or { "code": "...", "redirectUri": "..." }
    """
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    email = None
    name = None
    google_id = None
    picture_url = None

    # Option 1: ID Token verification (for mobile/desktop apps)
    if 'idToken' in data:
        id_token = data['idToken']
        # Verify with Google
        try:
            response = requests.get(
                f'https://oauth2.googleapis.com/tokeninfo?id_token={id_token}'
            )
            if response.status_code != 200:
                return jsonify({'error': 'Invalid token'}), 401

            token_info = response.json()
            email = token_info.get('email')
            name = token_info.get('name', token_info.get('email', '').split('@')[0])
            google_id = token_info.get('sub')
            picture_url = token_info.get('picture')

            if not email:
                return jsonify({'error': 'Email not found in token'}), 400

        except Exception as e:
            return jsonify({'error': f'Token verification failed: {str(e)}'}), 401

    # Option 2: Authorization code exchange (for web flow)
    elif 'code' in data:
        code = data['code']
        redirect_uri = data.get('redirectUri', 'com.googleusercontent.apps.397708767571-b87cc4q5a6h6lokubas6ho8squ9ipv02:/oauth2callback')

        if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
            return jsonify({'error': 'Google OAuth not configured'}), 500

        try:
            # Exchange code for tokens
            token_response = requests.post(
                'https://oauth2.googleapis.com/token',
                data={
                    'code': code,
                    'client_id': GOOGLE_CLIENT_ID,
                    'client_secret': GOOGLE_CLIENT_SECRET,
                    'redirect_uri': redirect_uri,
                    'grant_type': 'authorization_code'
                }
            )

            if token_response.status_code != 200:
                return jsonify({'error': 'Failed to exchange code'}), 401

            tokens = token_response.json()
            access_token = tokens.get('access_token')

            # Get user info
            userinfo_response = requests.get(
                'https://www.googleapis.com/oauth2/v2/userinfo',
                headers={'Authorization': f'Bearer {access_token}'}
            )

            if userinfo_response.status_code != 200:
                return jsonify({'error': 'Failed to get user info'}), 401

            userinfo = userinfo_response.json()
            email = userinfo.get('email')
            name = userinfo.get('name', email.split('@')[0] if email else 'User')
            google_id = userinfo.get('id')
            picture_url = userinfo.get('picture')

            if not email:
                return jsonify({'error': 'Email not found'}), 400

        except Exception as e:
            return jsonify({'error': f'Code exchange failed: {str(e)}'}), 401

    else:
        return jsonify({'error': 'idToken or code required'}), 400

    # Find or create user by email
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute('SELECT id, email, name, avatar_path FROM users WHERE email = ?', (email,))
    row = cursor.fetchone()

    if row:
        # Existing user
        user_id = row['id']
        # Update name and avatar if changed
        updates = []
        params = []
        if name and name != row['name']:
            updates.append('name = ?')
            params.append(name)
        # Update avatar_path with Google picture if user doesn't have custom avatar
        if picture_url and (not row['avatar_path'] or row['avatar_path'].startswith('http')):
            updates.append('avatar_path = ?')
            params.append(picture_url)

        if updates:
            params.append(user_id)
            cursor.execute(f'UPDATE users SET {", ".join(updates)} WHERE id = ?', params)
            conn.commit()

        avatar = picture_url if (picture_url and (not row['avatar_path'] or row['avatar_path'].startswith('http'))) else row['avatar_path']
        conn.close()
        return jsonify({
            'id': user_id,
            'email': row['email'],
            'name': name or row['name'],
            'avatarPath': avatar,
            'isNew': False
        })

    # Create new user (use email as device_id for Google users)
    user_id = str(uuid.uuid4())
    cursor.execute(
        'INSERT INTO users (id, device_id, email, name, avatar_path) VALUES (?, ?, ?, ?, ?)',
        (user_id, f"google:{email}", email, name, picture_url)
    )
    conn.commit()
    conn.close()

    return jsonify({
        'id': user_id,
        'email': email,
        'name': name,
        'avatarPath': picture_url,
        'isNew': True
    }), 201
