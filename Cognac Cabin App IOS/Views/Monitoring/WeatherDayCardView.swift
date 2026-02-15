import SwiftUI

struct WeatherDayCardView: View {
    let forecast: DailyForecast

    private var dayName: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(forecast.date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: forecast.date)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(dayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Image(systemName: forecast.sfSymbolName)
                .font(.title2)
                .symbolRenderingMode(.multicolor)

            VStack(spacing: 2) {
                Text("\(Int(forecast.highTemp))°")
                    .font(.headline)

                Text("\(Int(forecast.lowTemp))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(forecast.conditionMain)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 70, height: 130)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
