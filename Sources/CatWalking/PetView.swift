import SwiftUI

struct PetView: View {
    @ObservedObject var engine: PetEngine

    private var bubbleBodyOffsetY: CGFloat {
        260 * engine.petSize.height / 512 - 10
    }

    private var bubbleTailOffsetY: CGFloat {
        bubbleBodyOffsetY - 3
    }

    var body: some View {
        VStack(spacing: 0) {
            if let bubbleText = engine.speechBubbleText {
                VStack(spacing: 0) {
                    Text(bubbleText)
                        .font(.system(size: max(13, engine.petSize.width * 0.08), weight: .medium))
                        .foregroundStyle(Color(nsColor: engine.speechBubbleTextColor))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(nsColor: engine.speechBubbleColor))
                        )
                        .offset(y: bubbleBodyOffsetY)

                    SpeechBubbleTail()
                        .fill(Color(nsColor: engine.speechBubbleColor))
                        .frame(width: 18, height: 10)
                        .offset(y: bubbleTailOffsetY)
                }
                .padding(.bottom, 0)
            }

            Image(nsImage: engine.currentFrame)
                .resizable()
                .interpolation(.none)
                .antialiased(false)
                .frame(width: engine.petSize.width, height: engine.petSize.height)
        }
        .frame(width: engine.contentSize.width, height: engine.contentSize.height, alignment: .bottom)
        .background(Color.clear)
    }
}

private struct SpeechBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
