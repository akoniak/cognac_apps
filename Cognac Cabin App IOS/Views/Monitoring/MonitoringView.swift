import SwiftUI

struct MonitoringView: View {
    @State private var monitoringVM = MonitoringViewModel.withMockServices()
    @State private var weatherVM = WeatherViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CameraFeedsSection(viewModel: monitoringVM)
                    WeatherSectionView(viewModel: weatherVM)
                }
                .padding()
            }
            .navigationTitle("Cabin Monitor")
            .navigationDestination(for: CameraSnapshot.self) { snapshot in
                CameraDetailView(snapshot: snapshot)
            }
            .task {
                await monitoringVM.loadSnapshots()
                await weatherVM.loadForecast()
            }
            .refreshable {
                async let cameras: () = monitoringVM.loadSnapshots()
                async let weather: () = weatherVM.loadForecast()
                _ = await (cameras, weather)
            }
        }
    }
}

#Preview {
    MonitoringView()
}
