import SwiftUI

struct PetView: View {
    @ObservedObject var engine: PetEngine

    var body: some View {
        Image(nsImage: engine.currentFrame)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .frame(width: engine.contentSize.width, height: engine.contentSize.height)
            .background(Color.clear)
    }
}
