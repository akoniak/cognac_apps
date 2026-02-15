import SwiftUI

struct WeatherSectionView: View {
    let viewModel: WeatherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weather Forecast", systemImage: "cloud.sun.fill")
                .font(.title3.bold())

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading forecast...")
                    Spacer()
                }
                .padding(.vertical)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Weather Unavailable", systemImage: "cloud.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadForecast() }
                    }
                }
            } else if viewModel.dailyForecasts.isEmpty {
                ContentUnavailableView(
                    "No Forecast Data",
                    systemImage: "cloud.slash",
                    description: Text("Weather data is not available.")
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.dailyForecasts) { day in
                            WeatherDayCardView(forecast: day)
                        }
                    }
                }
            }
        }
    }
}
