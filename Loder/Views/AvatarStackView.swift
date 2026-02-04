import SwiftUI
import AppKit

struct AvatarStackView: View {
    let participants: [Participant]
    let maxVisible: Int = 3
    let size: CGFloat = 16

    var visibleParticipants: [Participant] {
        Array(participants.prefix(maxVisible))
    }

    var overflowCount: Int {
        max(0, participants.count - maxVisible)
    }

    var body: some View {
        HStack(spacing: -4) {
            ForEach(Array(visibleParticipants.enumerated()), id: \.element.id) { index, participant in
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(userId: participant.userId, size: size)
                        .overlay(
                            Circle()
                                .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
                        )

                    // Activity indicator
                    if participant.isOnline && participant.isActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
                            )
                    }
                }
                .zIndex(Double(maxVisible - index))
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}

// Menu bar avatar renderer using cached images
class MenuBarAvatarRenderer {
    static func renderAvatars(participants: [Participant], cachedImages: [String: NSImage]) -> NSImage? {
        let maxVisible = 3
        let avatarSize: CGFloat = 18
        let overlap: CGFloat = 6
        let indicatorSize: CGFloat = 7

        let visibleParticipants = Array(participants.prefix(maxVisible))
        guard !visibleParticipants.isEmpty else { return nil }

        let overflowCount = max(0, participants.count - maxVisible)
        let overflowWidth: CGFloat = overflowCount > 0 ? 20 : 0

        let totalWidth = avatarSize + CGFloat(visibleParticipants.count - 1) * (avatarSize - overlap) + overflowWidth
        let totalHeight = avatarSize

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))

        image.lockFocus()

        // Draw avatars from right to left so leftmost is on top
        for (index, participant) in visibleParticipants.enumerated().reversed() {
            let x = CGFloat(index) * (avatarSize - overlap)
            let rect = NSRect(x: x, y: 0, width: avatarSize, height: avatarSize)

            // Draw avatar circle
            let circlePath = NSBezierPath(ovalIn: rect)

            if let avatarImage = cachedImages[participant.userId] {
                // Clip to circle and draw image
                NSGraphicsContext.saveGraphicsState()
                circlePath.addClip()
                avatarImage.draw(in: rect)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                // Default gray circle
                NSColor.systemGray.setFill()
                circlePath.fill()

                // Draw person icon
                if let personIcon = NSImage(systemSymbolName: "person.fill", accessibilityDescription: nil) {
                    let iconSize: CGFloat = avatarSize * 0.6
                    let iconRect = NSRect(
                        x: x + (avatarSize - iconSize) / 2,
                        y: (avatarSize - iconSize) / 2,
                        width: iconSize,
                        height: iconSize
                    )
                    personIcon.draw(in: iconRect)
                }
            }

            // Draw border
            NSColor.windowBackgroundColor.setStroke()
            circlePath.lineWidth = 2
            circlePath.stroke()

            // Draw activity indicator if active
            if participant.isOnline && participant.isActive {
                let indicatorX = x + avatarSize - indicatorSize
                let indicatorY: CGFloat = 0
                let indicatorRect = NSRect(x: indicatorX, y: indicatorY, width: indicatorSize, height: indicatorSize)

                let indicatorPath = NSBezierPath(ovalIn: indicatorRect)
                NSColor.systemGreen.setFill()
                indicatorPath.fill()
                NSColor.windowBackgroundColor.setStroke()
                indicatorPath.lineWidth = 1.5
                indicatorPath.stroke()
            }
        }

        // Draw overflow count
        if overflowCount > 0 {
            let text = "+\(overflowCount)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let textSize = text.size(withAttributes: attributes)
            let textX = totalWidth - overflowWidth + (overflowWidth - textSize.width) / 2
            let textY = (totalHeight - textSize.height) / 2
            text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attributes)
        }

        image.unlockFocus()

        return image
    }
}
