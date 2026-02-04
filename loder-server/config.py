import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE_PATH = os.path.join(BASE_DIR, 'loder.db')
AVATARS_DIR = os.path.join(BASE_DIR, 'avatars')
MAX_AVATAR_SIZE = 1 * 1024 * 1024  # 1MB
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
