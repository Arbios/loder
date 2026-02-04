import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.environ.get('DATA_DIR', BASE_DIR)
DATABASE_PATH = os.environ.get('DATABASE_PATH', os.path.join(DATA_DIR, 'loder.db'))
AVATARS_DIR = os.environ.get('AVATARS_DIR', os.path.join(DATA_DIR, 'avatars'))
MAX_AVATAR_SIZE = 1 * 1024 * 1024  # 1MB
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

# Google OAuth Configuration (set via environment variables)
GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID', '')
GOOGLE_CLIENT_SECRET = os.environ.get('GOOGLE_CLIENT_SECRET', '')
