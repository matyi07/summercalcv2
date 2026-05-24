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
                .foregroundStyle(Color(.systemGray))
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

                    weatherDetailsGrid

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
                VStack(spacing: 8) {
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

                    Image(systemName: viewModel.weatherIcon(for: weather.condition))
                        .font(.system(size: 56))
                        .foregroundStyle(.orange.gradient)
                        .symbolRenderingMode(.hierarchical)

                    Text(weather.condition)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(viewModel.formattedTemperature(weather.temperatureCelsius))
                        .font(.system(size: 56, weight: .thin))

                    if let feelsLike = weather.feelsLikeCelsius {
                        Text("Feels like \(viewModel.formattedTemperature(feelsLike))")
                            .font(.subheadline)
                            .foregroundStyle(Color(.systemGray))
                    }

                    Text(weather.summary)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
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
                        .foregroundStyle(Color(.systemGray))
                }
                .padding(40)
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
            }
        }
    }

    private var weatherDetailsGrid: some View {
        Group {
            if let weather = viewModel.currentWeather {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    detailCell(
                        icon: "humidity.fill",
                        label: "Humidity",
                        value: viewModel.formattedHumidity(weather.humidity),
                        color: .blue
                    )
                    detailCell(
                        icon: "wind",
                        label: "Wind",
                        value: viewModel.formattedWind(weather.windSpeedKph),
                        color: .teal
                    )
                    detailCell(
                        icon: "sun.max.fill",
                        label: "UV Index",
                        value: viewModel.uvIndexLabel(weather.uvIndex),
                        color: .orange
                    )
                    detailCell(
                        icon: "eye.fill",
                        label: "Visibility",
                        value: viewModel.formattedVisibility(weather.visibility),
                        color: .indigo
                    )
                    detailCell(
                        icon: "gauge.with.dots.needle.33percent",
                        label: "Pressure",
                        value: viewModel.formattedPressure(weather.pressure),
                        color: .gray
                    )
                    detailCell(
                        icon: "umbrella.percent.fill",
                        label: "Precipitation",
                        value: "\(Int(weather.precipitationChance * 100))%",
                        color: .blue
                    )
                }
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    private func detailCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color(.systemGray))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var hourlyForecastSection: some View {
        Group {
            if !viewModel.hourlyForecast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hourly Forecast")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.hourlyForecast.prefix(24).enumerated()), id: \.element.id) { _, snapshot in
                                VStack(spacing: 6) {
                                    Text(hourLabel(for: snapshot.forecastDate))
                                        .font(.caption2)
                                        .foregroundStyle(Color(.systemGray))

                                    Image(systemName: viewModel.weatherIcon(for: snapshot.condition))
                                        .font(.title3)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.orange.gradient)

                                    Text(viewModel.formattedTemperature(snapshot.temperatureCelsius))
                                        .font(.caption)
                                        .fontWeight(.medium)

                                    if snapshot.precipitationChance > 0 {
                                        Text("\(Int(snapshot.precipitationChance * 100))%")
                                            .font(.caption2)
                                            .foregroundStyle(.blue)
                                    } else {
                                        Text("--")
                                            .font(.caption2)
                                            .foregroundStyle(Color(.systemGray3))
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

                                Image(systemName: viewModel.weatherIcon(for: day.condition))
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.orange.gradient)
                                    .frame(width: 30)

                                if day.precipitationChance > 0 {
                                    Text("\(Int(day.precipitationChance * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .frame(width: 36, alignment: .trailing)
                                } else {
                                    Text("")
                                        .frame(width: 36)
                                }

                                if let high = day.highTemp, let low = day.lowTemp {
                                    HStack(spacing: 4) {
                                        Text("H:\(String(format: "%.0f", high))°")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("L:\(String(format: "%.0f", low))°")
                                            .font(.caption)
                                            .foregroundStyle(Color(.systemGray))
                                    }
                                } else {
                                    Text(day.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.systemGray))
                                        .lineLimit(1)
                                }

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
                .frame(minHeight: 44)
                if viewModel.rainAlertEnabled {
                    HStack {
                        Text("Threshold")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                        Slider(value: $viewModel.rainThreshold, in: 0...1, step: 0.05)
                            .sensoryFeedback(.selection, trigger: viewModel.rainThreshold)
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
                .frame(minHeight: 44)
                if viewModel.heatAlertEnabled {
                    HStack {
                        Text("Threshold")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                        Slider(value: $viewModel.heatThreshold, in: 20...50, step: 1)
                            .sensoryFeedback(.selection, trigger: viewModel.heatThreshold)
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
                .frame(minHeight: 44)
                if viewModel.coldAlertEnabled {
                    HStack {
                        Text("Threshold")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                        Slider(value: $viewModel.coldThreshold, in: -20...15, step: 1)
                            .sensoryFeedback(.selection, trigger: viewModel.coldThreshold)
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
}
