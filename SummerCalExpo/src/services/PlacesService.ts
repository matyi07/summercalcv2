import { PlaceCandidate } from '../models';
import { v4 as uuidv4 } from 'uuid';

export interface PlaceDetails {
  placeId: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  phoneNumber?: string;
  website?: string;
  rating?: number;
  openingHours?: string[];
  photos?: string[];
}

const POPULAR_CATEGORIES = [
  'Restaurant',
  'Cafe',
  'Park',
  'Museum',
  'Gym',
  'Library',
  'Shopping Mall',
  'Movie Theater',
  'Bowling Alley',
  'Swimming Pool',
  'Beach',
  'Hiking Trail',
  'Art Gallery',
  'Bookstore',
  'Bakery',
];

export class PlacesService {
  private apiKey: string;
  private baseUrl = 'https://maps.googleapis.com/maps/api/place';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  popularCategories(): string[] {
    return [...POPULAR_CATEGORIES];
  }

  async searchNearby(
    query: string,
    latitude: number,
    longitude: number,
    radiusMeters: number = 3000
  ): Promise<PlaceCandidate[]> {
    const url = `${this.baseUrl}/nearbysearch/json?location=${latitude},${longitude}&radius=${radiusMeters}&keyword=${encodeURIComponent(query)}&key=${this.apiKey}`;

    const response = await fetch(url);
    const json = await response.json();

    if (json.status !== 'OK' && json.status !== 'ZERO_RESULTS') return [];

    const now = new Date().toISOString();
    return (json.results ?? []).slice(0, 20).map((r: any) => ({
      id: uuidv4(),
      name: r.name,
      category: r.types?.[0]?.replace(/_/g, ' ') ?? 'Unknown',
      address: r.vicinity ?? '',
      latitude: r.geometry?.location?.lat ?? 0,
      longitude: r.geometry?.location?.lng ?? 0,
      openNow: r.opening_hours?.open_now ?? undefined,
      rating: r.rating ?? undefined,
      placeId: r.place_id,
      distanceMeters: r.geometry
        ? this.haversineDistance(latitude, longitude, r.geometry.location.lat, r.geometry.location.lng)
        : 0,
      createdAt: now,
    }));
  }

  async placeDetails(placeId: string): Promise<PlaceDetails | null> {
    const url = `${this.baseUrl}/details/json?place_id=${placeId}&fields=name,formatted_address,geometry,formatted_phone_number,website,rating,opening_hours,photos&key=${this.apiKey}`;

    const response = await fetch(url);
    const json = await response.json();

    if (json.status !== 'OK' || !json.result) return null;

    const r = json.result;
    return {
      placeId: r.place_id ?? placeId,
      name: r.name ?? '',
      address: r.formatted_address ?? r.vicinity ?? '',
      latitude: r.geometry?.location?.lat ?? 0,
      longitude: r.geometry?.location?.lng ?? 0,
      phoneNumber: r.formatted_phone_number ?? undefined,
      website: r.website ?? undefined,
      rating: r.rating ?? undefined,
      openingHours: r.opening_hours?.weekday_text ?? undefined,
      photos: r.photos?.map((p: any) => {
        const ref = p.photo_reference;
        return `${this.baseUrl}/photo?maxwidth=400&photo_reference=${ref}&key=${this.apiKey}`;
      }) ?? undefined,
    };
  }

  private haversineDistance(
    lat1: number, lon1: number, lat2: number, lon2: number
  ): number {
    const R = 6371000;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c);
  }
}
