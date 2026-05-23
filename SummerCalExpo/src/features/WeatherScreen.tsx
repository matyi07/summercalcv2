import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  Switch,
  RefreshControl,
} from 'react-native';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { useWeatherStore } from '../store/weatherStore';
import { useSettingsStore } from '../store/settingsStore';
import { WeatherService } from '../services/WeatherService';
import { LocationService } from '../services/LocationService';

function getWeatherEmoji(condition: string): string {
  const lower = condition.toLowerCase();
  if (lower.includes('sun') || lower.includes('clear')) return '☀️';
  if (lower.includes('partly') && lower.includes('cloud')) return '⛅';
  if (lower.includes('cloud') || lower.includes('overcast')) return '☁️';
  if (lower.includes('fog') || lower.includes('mist') || lower.includes('rime')) return '🌫️';
  if (lower.includes('rain') || lower.includes('drizzle')) return '🌧️';
  if (lower.includes('snow')) return '❄️';
  if (lower.includes('storm') || lower.includes('thunder')) return '⛈️';
  if (lower.includes('wind')) return '💨';
  return '🌡️';
}

function celsiusToFahrenheit(c: number): number {
  return Math.round(c * 9 / 5 + 32);
}

interface HourlyData {
  time: string;
  temperature: number;
  weatherCode: number;
  precipitationProb: number;
}

interface DailyData {
  date: string;
  maxTemp: number;
  minTemp: number;
  weatherCode: number;
  precipitationProb: number;
  windSpeed: number;
}

function formatHour(timeStr: string): string {
  const date = new Date(timeStr);
  const hours = date.getHours();
  if (hours === 0) return '12 AM';
  if (hours < 12) return `${hours} AM`;
  if (hours === 12) return '12 PM';
  return `${hours - 12} PM`;
}

function formatDay(dateStr: string): string {
  const date = new Date(dateStr + 'T00:00:00');
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  if (date.toDateString() === today.toDateString()) return 'Today';
  if (date.toDateString() === tomorrow.toDateString()) return 'Tomorrow';
  return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

const weatherService = new WeatherService();

export function WeatherScreen() {
  const { currentSnapshot, loading, error, setWeather, setLoading, setError } = useWeatherStore();
  const settings = useSettingsStore((s) => s.settings);

  const [currentLoc, setCurrentLoc] = useState<{ lat: number; lng: number } | null>(null);
  const [locationGranted, setLocationGranted] = useState<boolean | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [useCelsius, setUseCelsius] = useState(true);

  const [hourlyData, setHourlyData] = useState<HourlyData[]>([]);
  const [dailyData, setDailyData] = useState<DailyData[]>([]);

  const [rainAlertEnabled, setRainAlertEnabled] = useState(settings?.weatherAlertsEnabled ?? true);
  const [rainThreshold, setRainThreshold] = useState(settings?.rainThreshold ?? 0.5);
  const [heatAlertEnabled, setHeatAlertEnabled] = useState(true);
  const [heatThreshold, setHeatThreshold] = useState(settings?.heatThresholdCelsius ?? 35);
  const [coldAlertEnabled, setColdAlertEnabled] = useState(true);
  const [coldThreshold, setColdThreshold] = useState(settings?.coldThresholdCelsius ?? 0);

  function formatTemp(c: number): string {
    if (useCelsius) return `${Math.round(c)}°C`;
    return `${celsiusToFahrenheit(c)}°F`;
  }

  async function fetchFullWeather(lat: number, lng: number) {
    setLoading(true);
    setError(null);

    try {
      const snapshot = await weatherService.fetchWeather(lat, lng);
      if (snapshot) setWeather(snapshot);

      const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current_weather=true&hourly=temperature_2m,precipitation_probability,weathercode&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode,windspeed_10m_max&timezone=auto&forecast_days=7`;

      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch weather data');
      const data = await response.json();

      if (data.hourly) {
        const hours: HourlyData[] = [];
        const now = new Date();
        for (let i = 0; i < data.hourly.time.length && i < 24; i++) {
          hours.push({
            time: data.hourly.time[i],
            temperature: data.hourly.temperature_2m[i],
            weatherCode: data.hourly.weathercode?.[i] ?? 0,
            precipitationProb: data.hourly.precipitation_probability?.[i] ?? 0,
          });
        }
        setHourlyData(hours);
      }

      if (data.daily) {
        const days: DailyData[] = [];
        for (let i = 0; i < data.daily.time.length && i < 7; i++) {
          days.push({
            date: data.daily.time[i],
            maxTemp: data.daily.temperature_2m_max[i],
            minTemp: data.daily.temperature_2m_min[i],
            weatherCode: data.daily.weathercode?.[i] ?? 0,
            precipitationProb: data.daily.precipitation_probability_max?.[i] ?? 0,
            windSpeed: data.daily.windspeed_10m_max?.[i] ?? 0,
          });
        }
        setDailyData(days);
      }
    } catch (err: any) {
      setError(err?.message || 'Failed to load weather data');
    } finally {
      setLoading(false);
    }
  }

  async function initLocationAndWeather() {
    const locationService = new LocationService();
    const granted = await locationService.requestPermission();
    setLocationGranted(granted);
    if (!granted) return;

    const loc = await locationService.getCurrentLocation();
    if (loc) {
      setCurrentLoc({ lat: loc.latitude, lng: loc.longitude });
      await fetchFullWeather(loc.latitude, loc.longitude);
    }
  }

  useEffect(() => {
    initLocationAndWeather();
  }, []);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    if (currentLoc) {
      await fetchFullWeather(currentLoc.lat, currentLoc.lng);
    }
    setRefreshing(false);
  }, [currentLoc]);

  if (locationGranted === null) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={Colors.primary} />
      </View>
    );
  }

  if (locationGranted === false) {
    return (
      <View style={styles.centered}>
        <Text style={styles.largeEmoji}>🌤️</Text>
        <Text style={styles.permissionTitle}>Enable location to see weather</Text>
        <Text style={styles.permissionSubtitle}>Location access is needed to fetch your local weather forecast.</Text>
      </View>
    );
  }

  if (loading && !currentSnapshot && hourlyData.length === 0) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color={Colors.primary} />
        <Text style={styles.loadingLabel}>Loading weather...</Text>
      </View>
    );
  }

  const snapshot = currentSnapshot;
  const condition = snapshot?.condition ?? 'Clear';
  const temp = snapshot?.temperatureCelsius ?? 0;
  const feelsLike = temp;
  const precipChance = snapshot?.precipitationChance ?? 0;
  const windSpeed = snapshot?.windSpeedKph;
  const summary = snapshot?.summary ?? condition;

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.contentContainer}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          tintColor={Colors.primary}
          colors={[Colors.primary]}
        />
      }
    >
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Weather</Text>
        <View style={styles.unitToggle}>
          <TouchableUnit
            active={useCelsius}
            onPress={() => setUseCelsius(true)}
            label="°C"
          />
          <TouchableUnit
            active={!useCelsius}
            onPress={() => setUseCelsius(false)}
            label="°F"
          />
        </View>
      </View>

      {error && (
        <View style={styles.errorBar}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}

      <View style={styles.currentCard}>
        <Text style={styles.weatherEmoji}>{getWeatherEmoji(condition)}</Text>
        <Text style={styles.temperature}>{formatTemp(temp)}</Text>
        <View style={styles.feelsRow}>
          <Text style={styles.feelsText}>Feels like {formatTemp(feelsLike)}</Text>
        </View>
        <Text style={styles.conditionText}>{summary}</Text>
        {windSpeed != null && (
          <Text style={styles.windText}>Wind: {windSpeed} km/h</Text>
        )}
        <Text style={styles.precipText}>
          Precipitation: {Math.round(precipChance * 100)}%
        </Text>
      </View>

      {hourlyData.length > 0 && (
        <View style={styles.sectionContainer}>
          <Text style={styles.sectionTitle}>Hourly Forecast</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.hourlyRow}>
            {hourlyData.map((h, i) => (
              <View key={i} style={styles.hourlyCard}>
                <Text style={styles.hourlyTime}>
                  {i === 0 ? 'Now' : formatHour(h.time)}
                </Text>
                <Text style={styles.hourlyEmoji}>
                  {getWeatherEmoji(weatherService.weatherCodeToCondition(h.weatherCode))}
                </Text>
                <Text style={styles.hourlyTemp}>{formatTemp(h.temperature)}</Text>
                <Text style={styles.hourlyPrecip}>
                  {h.precipitationProb}%
                </Text>
              </View>
            ))}
          </ScrollView>
        </View>
      )}

      {dailyData.length > 0 && (
        <View style={styles.sectionContainer}>
          <Text style={styles.sectionTitle}>7-Day Forecast</Text>
          <View style={styles.dailyList}>
            {dailyData.map((d, i) => (
              <View key={i} style={styles.dailyRow}>
                <Text style={styles.dailyDay}>{formatDay(d.date)}</Text>
                <Text style={styles.dailyEmoji}>
                  {getWeatherEmoji(weatherService.weatherCodeToCondition(d.weatherCode))}
                </Text>
                <View style={styles.dailyBar}>
                  <View
                    style={[
                      styles.dailyBarFill,
                      {
                        width: `${Math.min(100, Math.max(10, (d.maxTemp + 10) / 55 * 100))}%`,
                      },
                    ]}
                  />
                </View>
                <Text style={styles.dailyTemp}>
                  {formatTemp(d.maxTemp)} / {formatTemp(d.minTemp)}
                </Text>
              </View>
            ))}
          </View>
        </View>
      )}

      <View style={styles.sectionContainer}>
        <Text style={styles.sectionTitle}>Alert Thresholds</Text>

        <View style={styles.alertRow}>
          <View style={styles.alertInfo}>
            <Text style={styles.alertEmoji}>🌧️</Text>
            <View>
              <Text style={styles.alertLabel}>Rain alert</Text>
              <Text style={styles.alertThreshold}>{Math.round(rainThreshold * 100)}% chance</Text>
            </View>
          </View>
          <Switch
            value={rainAlertEnabled}
            onValueChange={setRainAlertEnabled}
            trackColor={{ false: Colors.border, true: Colors.rain }}
            thumbColor={rainAlertEnabled ? '#FFFFFF' : Colors.textTertiary}
          />
        </View>

        <View style={styles.sliderContainer}>
          <View style={styles.sliderTrack}>
            {[0, 20, 40, 60, 80, 100].map((val) => (
              <TouchablePct
                key={val}
                value={val / 100}
                selected={Math.abs(rainThreshold * 100 - val) <= 5}
                onPress={() => setRainThreshold(val / 100)}
              />
            ))}
          </View>
        </View>

        <View style={styles.alertDivider} />

        <View style={styles.alertRow}>
          <View style={styles.alertInfo}>
            <Text style={styles.alertEmoji}>🔥</Text>
            <View>
              <Text style={styles.alertLabel}>Heat alert</Text>
              <Text style={styles.alertThreshold}>{formatTemp(heatThreshold)}</Text>
            </View>
          </View>
          <Switch
            value={heatAlertEnabled}
            onValueChange={setHeatAlertEnabled}
            trackColor={{ false: Colors.border, true: Colors.heat }}
            thumbColor={heatAlertEnabled ? '#FFFFFF' : Colors.textTertiary}
          />
        </View>

        <View style={styles.sliderContainer}>
          <View style={styles.sliderTrack}>
            {[20, 25, 30, 35, 40, 45].map((val) => (
              <TouchablePct
                key={val}
                value={val}
                selected={Math.abs(heatThreshold - val) <= 2.5}
                onPress={() => setHeatThreshold(val)}
                label={formatTemp(val)}
              />
            ))}
          </View>
        </View>

        <View style={styles.alertDivider} />

        <View style={styles.alertRow}>
          <View style={styles.alertInfo}>
            <Text style={styles.alertEmoji}>❄️</Text>
            <View>
              <Text style={styles.alertLabel}>Cold alert</Text>
              <Text style={styles.alertThreshold}>{formatTemp(coldThreshold)}</Text>
            </View>
          </View>
          <Switch
            value={coldAlertEnabled}
            onValueChange={setColdAlertEnabled}
            trackColor={{ false: Colors.border, true: Colors.cold }}
            thumbColor={coldAlertEnabled ? '#FFFFFF' : Colors.textTertiary}
          />
        </View>

        <View style={styles.sliderContainer}>
          <View style={styles.sliderTrack}>
            {[-10, -5, 0, 5, 10, 15].map((val) => (
              <TouchablePct
                key={val}
                value={val}
                selected={Math.abs(coldThreshold - val) <= 2.5}
                onPress={() => setColdThreshold(val)}
                label={formatTemp(val)}
              />
            ))}
          </View>
        </View>
      </View>

      <View style={styles.bottomSpacer} />
    </ScrollView>
  );
}

function TouchableUnit({
  active,
  onPress,
  label,
}: {
  active: boolean;
  onPress: () => void;
  label: string;
}) {
  return (
    <View
      style={{
        paddingHorizontal: Spacing.md,
        paddingVertical: Spacing.xs,
        borderRadius: BorderRadius.full,
      }}
    >
      <Text
        style={[
          styles.unitText,
          active && styles.unitTextActive,
        ]}
        onPress={onPress}
      >
        {label}
      </Text>
    </View>
  );
}

function TouchablePct({
  value,
  selected,
  onPress,
  label,
}: {
  value: number;
  selected: boolean;
  onPress: () => void;
  label?: string;
}) {
  return (
    <View
      style={{
        borderRadius: BorderRadius.full,
        width: 20,
        height: 20,
        backgroundColor: selected ? Colors.primary : Colors.border,
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      <Text
        style={{
          position: 'absolute',
          top: -20,
          fontSize: FontSize.xs,
          color: Colors.textTertiary,
          fontWeight: '500',
        }}
      >
        {label ?? `${Math.round(typeof value === 'number' && value <= 1 ? value * 100 : value)}`}
      </Text>
      <View
        style={{
          width: 24,
          height: 24,
          borderRadius: 12,
        }}
      />
      <Text
        onPress={onPress}
        style={{
          position: 'absolute',
          width: 40,
          height: 30,
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  contentContainer: {
    paddingBottom: Spacing.xxxl,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xxxl,
    backgroundColor: Colors.background,
  },
  largeEmoji: {
    fontSize: 56,
    marginBottom: Spacing.lg,
  },
  permissionTitle: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.text,
    textAlign: 'center',
    marginBottom: Spacing.sm,
  },
  permissionSubtitle: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
  },
  loadingLabel: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    marginTop: Spacing.md,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.xxl,
    paddingBottom: Spacing.md,
  },
  headerTitle: {
    fontSize: FontSize.xxl,
    fontWeight: '700',
    color: Colors.text,
  },
  unitToggle: {
    flexDirection: 'row',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.full,
    padding: 2,
  },
  unitText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.textSecondary,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
  },
  unitTextActive: {
    color: Colors.primary,
  },
  errorBar: {
    backgroundColor: '#FFEBEE',
    marginHorizontal: Spacing.lg,
    marginBottom: Spacing.md,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.md,
  },
  errorText: {
    fontSize: FontSize.sm,
    color: Colors.error,
    fontWeight: '500',
  },
  currentCard: {
    backgroundColor: Colors.card,
    marginHorizontal: Spacing.lg,
    borderRadius: BorderRadius.xl,
    paddingVertical: Spacing.xxxl,
    paddingHorizontal: Spacing.xxl,
    alignItems: 'center',
    ...Shadow.md,
  },
  weatherEmoji: {
    fontSize: 64,
    marginBottom: Spacing.md,
  },
  temperature: {
    fontSize: FontSize.title,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.xs,
  },
  feelsRow: {
    marginBottom: Spacing.xs,
  },
  feelsText: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
  },
  conditionText: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: Spacing.sm,
  },
  windText: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
  },
  precipText: {
    fontSize: FontSize.md,
    color: Colors.rain,
    fontWeight: '500',
  },
  sectionContainer: {
    marginTop: Spacing.xxl,
    paddingHorizontal: Spacing.lg,
  },
  sectionTitle: {
    fontSize: FontSize.lg,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.md,
  },
  hourlyRow: {
    gap: Spacing.sm,
    paddingRight: Spacing.lg,
  },
  hourlyCard: {
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.lg,
    paddingVertical: Spacing.lg,
    paddingHorizontal: Spacing.lg,
    alignItems: 'center',
    minWidth: 72,
    ...Shadow.sm,
  },
  hourlyTime: {
    fontSize: FontSize.xs,
    fontWeight: '600',
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
  },
  hourlyEmoji: {
    fontSize: FontSize.xxl,
    marginBottom: Spacing.sm,
  },
  hourlyTemp: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: Spacing.xs,
  },
  hourlyPrecip: {
    fontSize: FontSize.xs,
    color: Colors.rain,
    fontWeight: '500',
  },
  dailyList: {
    backgroundColor: Colors.card,
    borderRadius: BorderRadius.xl,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    ...Shadow.sm,
  },
  dailyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: Colors.surface,
  },
  dailyDay: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    width: 110,
  },
  dailyEmoji: {
    fontSize: FontSize.xl,
    width: 36,
    textAlign: 'center',
  },
  dailyBar: {
    flex: 1,
    height: 4,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.full,
    marginHorizontal: Spacing.sm,
    overflow: 'hidden',
  },
  dailyBarFill: {
    height: '100%',
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.full,
  },
  dailyTemp: {
    fontSize: FontSize.sm,
    fontWeight: '500',
    color: Colors.textSecondary,
    width: 95,
    textAlign: 'right',
  },
  alertRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.md,
  },
  alertInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
  },
  alertEmoji: {
    fontSize: FontSize.xxl,
  },
  alertLabel: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
  },
  alertThreshold: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    marginTop: 2,
  },
  alertDivider: {
    height: 1,
    backgroundColor: Colors.surface,
    marginVertical: Spacing.sm,
  },
  sliderContainer: {
    paddingVertical: Spacing.xs,
    paddingBottom: Spacing.lg,
  },
  sliderTrack: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.xl,
  },
  bottomSpacer: {
    height: Spacing.xxxl,
  },
});
