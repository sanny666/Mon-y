import SwiftUI
import UIKit

/// Full-screen receipt preview with pinch-to-zoom. Dismiss via close button or background tap.
struct ReceiptImagePreview: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoom)
                .padding(16)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(max(lastZoom * value, 1), 4)
                        }
                        .onEnded { _ in
                            lastZoom = zoom
                            if zoom <= 1.05 {
                                zoom = 1
                                lastZoom = 1
                            }
                        }
                )

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .white.opacity(0.35))
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
    }
}
