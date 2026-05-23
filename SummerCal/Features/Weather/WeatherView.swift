import SwiftUI
import SwiftData

struct WeatherView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WeatherViewModel()

    var body: some View {
        Group {
            if viewModel.locationAuthorizationStatus == .denied || viewModel.locationAuthorizationStatus == .restricted {
                locationDeniedView
            } else {
                weatherContent
            }
        }
        .navigationTitle("Weather")
        .onAppear {
            viewModel.requestLocation()
            viewModel.loadThresholds(modelContext: modelContext)
        }
        .onChange(of: viewModel.locationAuthorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                Task { await viewModel.fetchWeather(modelContext: modelContext) }
            }
        }
        .refreshable {
            await viewModel.fetchWeather(modelContext: modelContext)
        }
    }

    private var locationDeniedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Location Access Required")
                .font(.title3)
                .fontWeight(.bold)

            Text("Enable location access to see weather for your area.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Spacer()
        }
    }

    private var weatherContent: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.currentWeather == nil {
                VStack(spacing: 16) {
                    Spacer(minLength: 100)
                    ProgressView("Loading weather...")
                    Spacer()
                }
            } else {
                VStack(spacing: 16) {
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }

                    alertsSection

                    currentWeatherCard

                    hourlyForecastSection

                    dailyForecastSection

                    alertThresholdsSection
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var alertsSection: some View {
        let alerts = viewModel.checkAlerts()
        guard !alerts.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(spacing: 8) {
                ForEach(alerts, id: \.self) { alert in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(alert)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
        )
    }

    private var currentWeatherCard: some View {
        Group {
            if let weather = viewModel.currentWeather {
                VStack(spacing: 12) {
                    if let name = viewModel.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    Image(systemName: viewModel.weatherIcon(for: weatherCodeFor(weather)))
                        .font(.system(size: 56))
                        .foregroundStyle(.orange.gradient)
                        .symbolRenderingMode(.hierarchical)

                    Text(weather.condition)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(viewModel.formattedTemperature(weather.temperatureCelsius))
                        .font(.system(size: 52, weight: .thin))

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Label(
                                viewModel.formattedTemperature(weather.temperatureCelsius),
                                systemImage: "thermometer.medium"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            Text("Feels like")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        VStack(spacing: 2) {
                            Label(
                                viewModel.formattedWind(weather.windSpeedKph),
                                systemImage: "wind"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            Text("Wind")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        VStack(spacing: 2) {
                            Label(
                                "\(Int(weather.precipitationChance))%",
                                systemImage: "umbrella.percent"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            Text("Precip")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Fetching weather...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(40)
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
            }
        }
    }

    private var hourlyForecastSection: some View {
        Group {
            if !viewModel.hourlyForecast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hourly")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.hourlyForecast.prefix(24)) { snapshot in
                                VStack(spacing: 6) {
                                    Text(hourLabel(for: snapshot.forecastDate))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: viewModel.weatherIcon(for: weatherCodeFor(snapshot)))
                                        .font(.title3)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.orange.gradient)

                                    Text(viewModel.formattedTemperature(snapshot.temperatureCelsius))
                                        .font(.caption)
                                        .fontWeight(.medium)

                                    if snapshot.precipitationChance > 0 {
                                        Text("\(Int(snapshot.precipitationChance))%")
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                    } else {
                                        Text("--")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var dailyForecastSection: some View {
        Group {
            if !viewModel.dailyForecast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("7-Day Forecast")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.dailyForecast.prefix(7).enumerated()), id: \.element.id) { index, day in
                            HStack(spacing: 12) {
                                Text(dayLabel(for: day.forecastDate, index: index))
                                    .font(.subheadline)
                                    .frame(width: 50, alignment: .leading)

                                Image(systemName: viewModel.weatherIcon(for: weatherCodeFor(day)))
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.orange.gradient)
                                    .frame(width: 30)

                                if day.precipitationChance > 0 {
                                    Text("\(Int(day.precipitationChance))%")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .frame(width: 36, alignment: .trailing)
                                } else {
                                    Text("")
                                        .frame(width: 36)
                                }

                                Text(day.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                Text(viewModel.formattedTemperature(day.temperatureCelsius))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)

                            if index < viewModel.dailyForecast.prefix(7).count - 1 {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
        }
    }

    private var alertThresholdsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alert Thresholds")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                HStack {
                    Toggle("Rain Alert", isOn: $viewModel.rainAlertEnabled)
                        .font(.subheadline)
                }
                if viewModel.rainAlertEnabled {
                    HStack {
                        Text("Threshold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.rainThreshold, in: 0...1, step: 0.05)
                        Text("\(Int(viewModel.rainThreshold * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                Divider()

                HStack {
                    Toggle("Heat Alert", isOn: $viewModel.heatAlertEnabled)
                        .font(.subheadline)
                }
                if viewModel.heatAlertEnabled {
                    HStack {
                        Text("Threshold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.heatThreshold, in: 20...50, step: 1)
                        Text(viewModel.formattedTemperature(viewModel.heatThreshold))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                Divider()

                HStack {
                    Toggle("Cold Alert", isOn: $viewModel.coldAlertEnabled)
                        .font(.subheadline)
                }
                if viewModel.coldAlertEnabled {
                    HStack {
                        Text("Threshold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.coldThreshold, in: -20...15, step: 1)
                        Text(viewModel.formattedTemperature(viewModel.coldThreshold))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Button {
                viewModel.saveThresholds(modelContext: modelContext)
            } label: {
                Text("Save Thresholds")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal)
        }
    }

    private func hourLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }

    private func dayLabel(for date: Date, index: Int) -> String {
        if index == 0 { return "Today" }
        if index == 1 { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func weatherCodeFor(_ snapshot: WeatherSnapshot) -> Int {
        switch snapshot.condition {
        case "Clear": return 0
        case "Partly Cloudy": return 1
        case "Fog": return 45
        case "Drizzle": return 51
        case "Freezing Drizzle": return 56
        case "Rain": return 61
        case "Freezing Rain": return 66
        case "Snow": return 71
        case "Snow Grains": return 77
        case "Rain Showers": return 80
        case "Snow Showers": return 85
        case "Thunderstorm": return 95
        case "Thunderstorm with Hail": return 96
        default: return 0
        }
    }
}
