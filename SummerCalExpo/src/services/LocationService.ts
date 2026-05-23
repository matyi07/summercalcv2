import * as Location from 'expo-location';

export interface LocationResult {
  latitude: number;
  longitude: number;
  city: string;
}

export class LocationService {
  async requestPermission(): Promise<boolean> {
    const { status } = await Location.requestForegroundPermissionsAsync();
    return status === 'granted';
  }

  async getCurrentLocation(): Promise<LocationResult | null> {
    const hasPermission = await this.requestPermission();
    if (!hasPermission) return null;

    const position = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.Balanced,
    });

    const { latitude, longitude } = position.coords;
    const geocode = await Location.reverseGeocodeAsync({ latitude, longitude });
    const city = geocode[0]?.city ?? geocode[0]?.subregion ?? 'Unknown';

    return { latitude, longitude, city };
  }

  isAuthorized(): Promise<boolean> {
    return Location.hasServicesEnabledAsync();
  }
}
