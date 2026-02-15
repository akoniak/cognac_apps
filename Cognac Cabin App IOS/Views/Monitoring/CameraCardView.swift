import SwiftUI

struct CameraCardView: View {
    let snapshot: CameraSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(uiImage: snapshot.image)
                .resizable()
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.cameraName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)

                    Text(snapshot.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
