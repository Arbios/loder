from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class User:
    id: str
    device_id: str
    avatar_path: Optional[str]
    created_at: datetime

    def to_dict(self):
        return {
            'id': self.id,
            'deviceId': self.device_id,
            'avatarPath': self.avatar_path,
            'createdAt': self.created_at.isoformat() if self.created_at else None
        }

@dataclass
class Room:
    id: str
    created_by: str
    created_at: datetime

    def to_dict(self):
        return {
            'id': self.id,
            'createdBy': self.created_by,
            'createdAt': self.created_at.isoformat() if self.created_at else None
        }

@dataclass
class RoomMember:
    room_id: str
    user_id: str
    is_active: bool
    last_seen: datetime

    def to_dict(self):
        return {
            'roomId': self.room_id,
            'userId': self.user_id,
            'isActive': self.is_active,
            'lastSeen': self.last_seen.isoformat() if self.last_seen else None
        }
