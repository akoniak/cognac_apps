import SwiftUI

struct CameraFeedsSection: View {
    let viewModel: MonitoringViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Camera Feeds", systemImage: "video.fill")
                .font(.title3.bold())

            if viewModel.isLoading && viewModel.snapshots.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Loading cameras...")
                    Spacer()
                }
                .padding(.vertical)
            } else if let error = viewModel.errorMessage, viewModel.snapshots.isEmpty {
                ContentUnavailableView {
                    Label("Cameras Unavailable", systemImage: "video.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadSnapshots() }
                    }
                }
            } else if viewModel.snapshots.isEmpty {
                ContentUnavailableView(
                    "No Cameras",
                    systemImage: "video.slash",
                    description: Text("No camera feeds configured.")
                )
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.snapshots) { snapshot in
                        NavigationLink(value: snapshot) {
                            CameraCardView(snapshot: snapshot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
