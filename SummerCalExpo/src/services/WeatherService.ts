import { WeatherSnapshot } from '../models';
import { v4 as uuidv4 } from 'uuid';

export interface RawWeatherResponse {
  current_weather: {
    temperature: number;
    windspeed: number;
    weathercode: number;
    time: string;
  };
  daily: {
    time: string[];
    temperature_2m_max: number[];
    temperature_2m_min: number[];
    precipitation_probability_max: number[];
    weathercode: number[];
    windspeed_10m_max: number[];
  };
  hourly: {
    time: string[];
    precipitation_probability: number[];
  };
}

const WMO_CODES: Record<number, { condition: string; summary: string }> = {
  0: { condition: 'Clear', summary: 'Clear sky' },
  1: { condition: 'Mainly Clear', summary: 'Mainly clear' },
  2: { condition: 'Partly Cloudy', summary: 'Partly cloudy' },
  3: { condition: 'Overcast', summary: 'Overcast' },
  45: { condition: 'Fog', summary: 'Foggy' },
  48: { condition: 'Rime Fog', summary: 'Depositing rime fog' },
  51: { condition: 'Light Drizzle', summary: 'Light drizzle' },
  53: { condition: 'Moderate Drizzle', summary: 'Moderate drizzle' },
  55: { condition: 'Dense Drizzle', summary: 'Dense drizzle' },
  56: { condition: 'Freezing Drizzle', summary: 'Light freezing drizzle' },
  57: { condition: 'Freezing Drizzle', summary: 'Dense freezing drizzle' },
  61: { condition: 'Light Rain', summary: 'Slight rain' },
  63: { condition: 'Rain', summary: 'Moderate rain' },
  65: { condition: 'Heavy Rain', summary: 'Heavy rain' },
  66: { condition: 'Freezing Rain', summary: 'Light freezing rain' },
  67: { condition: 'Freezing Rain', summary: 'Heavy freezing rain' },
  71: { condition: 'Light Snow', summary: 'Slight snowfall' },
  73: { condition: 'Snow', summary: 'Moderate snowfall' },
  75: { condition: 'Heavy Snow', summary: 'Heavy snowfall' },
  77: { condition: 'Snow Grains', summary: 'Snow grains' },
  80: { condition: 'Rain Showers', summary: 'Slight rain showers' },
  81: { condition: 'Rain Showers', summary: 'Moderate rain showers' },
  82: { condition: 'Rain Showers', summary: 'Violent rain showers' },
  85: { condition: 'Snow Showers', summary: 'Slight snow showers' },
  86: { condition: 'Snow Showers', summary: 'Heavy snow showers' },
  95: { condition: 'Thunderstorm', summary: 'Thunderstorm' },
  96: { condition: 'Thunderstorm', summary: 'Thunderstorm with slight hail' },
  99: { condition: 'Thunderstorm', summary: 'Thunderstorm with heavy hail' },
};

export class WeatherService {
  weatherCodeToCondition(code: number): string {
    const entry = WMO_CODES[code];
    return entry ? entry.condition : 'Unknown';
  }

  async fetchWeather(latitude: number, longitude: number): Promise<WeatherSnapshot | null> {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current_weather=true&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode,windspeed_10m_max&hourly=precipitation_probability&timezone=auto&forecast_days=1`;

    const response = await fetch(url);
    if (!response.ok) return null;
    const data: RawWeatherResponse = await response.json();

    const code = data.current_weather?.weathercode ?? 0;
    const wx = WMO_CODES[code] ?? { condition: 'Clear', summary: 'Clear' };
    const now = new Date().toISOString();
    const today = new Date().toISOString().slice(0, 10);

    const hourlyPrecip = data.hourly?.precipitation_probability ?? [];
    const avgPrecip = hourlyPrecip.length > 0
      ? hourlyPrecip.reduce((a, b) => a + b, 0) / hourlyPrecip.length / 100
      : 0;

    return {
      id: uuidv4(),
      latitude,
      longitude,
      fetchedAt: now,
      forecastDate: today,
      condition: wx.condition,
      temperatureCelsius: data.current_weather?.temperature ?? 0,
      precipitationChance: Math.round(avgPrecip * 100) / 100,
      windSpeedKph: data.current_weather?.windspeed,
      summary: wx.summary,
    };
  }

  shouldNotifyRain(snapshot: WeatherSnapshot, threshold: number): boolean {
    return snapshot.precipitationChance >= threshold;
  }

  shouldNotifyHeat(snapshot: WeatherSnapshot, thresholdCelsius: number): boolean {
    return snapshot.temperatureCelsius >= thresholdCelsius;
  }

  shouldNotifyCold(snapshot: WeatherSnapshot, thresholdCelsius: number): boolean {
    return snapshot.temperatureCelsius <= thresholdCelsius;
  }

  isGoodOutdoorWeather(snapshot: WeatherSnapshot): boolean {
    if (snapshot.precipitationChance >= 0.5) return false;
    if (snapshot.temperatureCelsius > 40) return false;
    if (snapshot.temperatureCelsius < -5) return false;
    const severeConditions = ['Thunderstorm', 'Heavy Rain', 'Heavy Snow', 'Dense Drizzle', 'Freezing Rain'];
    return !severeConditions.includes(snapshot.condition);
  }

  generateWeatherSummary(snapshot: WeatherSnapshot): string {
    let parts: string[] = [];

    const temp = snapshot.temperatureCelsius;
    if (temp >= 35) parts.push('Extremely hot');
    else if (temp >= 28) parts.push('Hot');
    else if (temp >= 20) parts.push('Warm');
    else if (temp >= 10) parts.push('Mild');
    else if (temp >= 0) parts.push('Cool');
    else parts.push('Cold');

    parts.push(`(${Math.round(temp)}°C)`);
    parts.push(snapshot.condition);

    const precip = snapshot.precipitationChance;
    if (precip >= 0.8) parts.push('high rain chance');
    else if (precip >= 0.5) parts.push('moderate rain chance');
    else if (precip >= 0.2) parts.push('slight rain chance');

    if (snapshot.windSpeedKph && snapshot.windSpeedKph > 30) {
      parts.push('windy');
    }

    return parts.join(', ');
  }
}
