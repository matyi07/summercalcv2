import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  Modal,
  ActivityIndicator,
  Linking,
} from 'react-native';
import * as SecureStore from 'expo-secure-store';
import { PlaceCard } from '../components/PlaceCard';
import { Colors, Spacing, FontSize, BorderRadius, Shadow } from '../constants/theme';
import { usePlacesStore } from '../store/placesStore';
import { PlacesService, PlaceDetails } from '../services/PlacesService';
import { LocationService } from '../services/LocationService';
import { PlaceCandidate as ModelPlace } from '../models';

const CATEGORIES = [
  { key: 'cafe', icon: '☕', label: 'Cafes', query: 'cafe' },
  { key: 'gym', icon: '🏋️', label: 'Gyms', query: 'gym' },
  { key: 'restaurant', icon: '🍽️', label: 'Restaurants', query: 'restaurant' },
  { key: 'park', icon: '🌳', label: 'Parks', query: 'park' },
  { key: 'museum', icon: '🏛️', label: 'Museums', query: 'museum' },
  { key: 'shop', icon: '🛍️', label: 'Shops', query: 'shopping' },
];

const STORAGE_KEY = 'google_places_api_key';

function renderStars(rating: number): string {
  const full = Math.floor(rating);
  const half = rating - full >= 0.5 ? 1 : 0;
  return '★'.repeat(full) + (half ? '½' : '') + '☆'.repeat(5 - full - half);
}

function formatDistance(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

export function PlacesScreen() {
  const {
    results, selectedCategory, searchQuery, loading, error,
    setResults, setCategory, setQuery, setLoading, setError,
  } = usePlacesStore();

  const [localQuery, setLocalQuery] = useState(searchQuery);
  const [detailModalVisible, setDetailModalVisible] = useState(false);
  const [selectedPlaceId, setSelectedPlaceId] = useState<string | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [placeDetail, setPlaceDetail] = useState<PlaceDetails | null>(null);
  const [locationGranted, setLocationGranted] = useState<boolean | null>(null);
  const [locationCoords, setLocationCoords] = useState<{ lat: number; lng: number } | null>(null);

  const locationService = new LocationService();

  useEffect(() => {
    initLocation();
  }, []);

  async function initLocation() {
    const granted = await locationService.requestPermission();
    setLocationGranted(granted);
    if (granted) {
      const loc = await locationService.getCurrentLocation();
      if (loc) {
        setLocationCoords({ lat: loc.latitude, lng: loc.longitude });
      }
    }
  }

  async function doSearch(query: string, category: string) {
    if (!locationCoords) return;

    setLoading(true);
    setError(null);

    try {
      const apiKey = await SecureStore.getItemAsync(STORAGE_KEY);
      if (!apiKey) {
        setError('Google Places API key not found. Add it in Settings.');
        setResults([]);
        setLoading(false);
        return;
      }

      const service = new PlacesService(apiKey);
      const searchTerm = query.trim() || category || 'restaurant';
      const data = await service.searchNearby(searchTerm, locationCoords.lat, locationCoords.lng);
      setResults(data);
    } catch (err: any) {
      setError(err?.message || 'Search failed. Try again.');
      setResults([]);
    } finally {
      setLoading(false);
    }
  }

  function handleSearch() {
    setQuery(localQuery);
    doSearch(localQuery, selectedCategory);
  }

  function handleCategorySelect(cat: typeof CATEGORIES[0]) {
    if (selectedCategory === cat.query) {
      setCategory('');
      doSearch(localQuery, '');
    } else {
      setCategory(cat.query);
      doSearch(localQuery, cat.query);
    }
  }

  async function handlePlacePress(place: ModelPlace) {
    setSelectedPlaceId(place.placeId);
    setDetailModalVisible(true);
    setDetailLoading(true);
    setPlaceDetail(null);

    try {
      const apiKey = await SecureStore.getItemAsync(STORAGE_KEY);
      if (!apiKey) {
        setDetailLoading(false);
        return;
      }

      const service = new PlacesService(apiKey);
      const detail = await service.placeDetails(place.placeId);
      setPlaceDetail(detail);
    } catch {
      setPlaceDetail(null);
    } finally {
      setDetailLoading(false);
    }
  }

  function openInMaps(place: PlaceDetails) {
    const url = `maps:0,0?q=${encodeURIComponent(place.name)}@${place.latitude},${place.longitude}`;
    Linking.openURL(url).catch(() => {
      const fallback = `https://maps.google.com/?q=${encodeURIComponent(place.name)}@${place.latitude},${place.longitude}`;
      Linking.openURL(fallback);
    });
  }

  function mapToCardPlace(place: ModelPlace) {
    return {
      id: place.id,
      name: place.name,
      category: place.category,
      address: place.address,
      isOpen: place.openNow ?? false,
      rating: place.rating ?? 0,
      distance: place.distanceMeters,
    };
  }

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
        <Text style={styles.largeEmoji}>📍</Text>
        <Text style={styles.permissionTitle}>Enable location to find nearby places</Text>
        <Text style={styles.permissionSubtitle}>Location access is needed to search for places near you.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Places</Text>
      </View>

      <View style={styles.searchRow}>
        <View style={styles.searchInputWrapper}>
          <Text style={styles.searchIcon}>🔍</Text>
          <TextInput
            style={styles.searchInput}
            value={localQuery}
            onChangeText={setLocalQuery}
            placeholder="Search places..."
            placeholderTextColor={Colors.textTertiary}
            returnKeyType="search"
            onSubmitEditing={handleSearch}
          />
        </View>
        <TouchableOpacity style={styles.goButton} onPress={handleSearch} activeOpacity={0.7}>
          <Text style={styles.goText}>Go</Text>
        </TouchableOpacity>
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.chipRow}
      >
        {CATEGORIES.map((cat) => (
          <TouchableOpacity
            key={cat.key}
            style={[
              styles.chip,
              selectedCategory === cat.query && styles.chipSelected,
            ]}
            onPress={() => handleCategorySelect(cat)}
            activeOpacity={0.7}
          >
            <Text style={styles.chipIcon}>{cat.icon}</Text>
            <Text
              style={[
                styles.chipLabel,
                selectedCategory === cat.query && styles.chipLabelSelected,
              ]}
            >
              {cat.label}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {error && (
        <View style={styles.errorBar}>
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}

      {loading ? (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color={Colors.primary} />
          <Text style={styles.loadingLabel}>Searching...</Text>
        </View>
      ) : results.length === 0 ? (
        <View style={styles.centered}>
          <Text style={styles.largeEmoji}>🔍</Text>
          <Text style={styles.emptyTitle}>No places found</Text>
          <Text style={styles.emptySubtitle}>Try adjusting your search or category</Text>
        </View>
      ) : (
        <FlatList
          data={results}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <PlaceCard
              place={mapToCardPlace(item)}
              onPress={() => handlePlacePress(item)}
            />
          )}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
        />
      )}

      <Modal
        visible={detailModalVisible}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setDetailModalVisible(false)}
      >
        <View style={styles.modalContainer}>
          <View style={styles.modalHandle}>
            <View style={styles.handleBar} />
          </View>

          <TouchableOpacity
            style={styles.modalClose}
            onPress={() => setDetailModalVisible(false)}
            activeOpacity={0.7}
          >
            <Text style={styles.modalCloseText}>Done</Text>
          </TouchableOpacity>

          {detailLoading ? (
            <View style={styles.centered}>
              <ActivityIndicator size="large" color={Colors.primary} />
            </View>
          ) : placeDetail ? (
            <ScrollView contentContainerStyle={styles.detailContent}>
              <Text style={styles.detailName}>{placeDetail.name}</Text>
              {placeDetail.rating != null && (
                <View style={styles.detailRatingRow}>
                  <Text style={styles.detailStars}>
                    {renderStars(placeDetail.rating)}
                  </Text>
                  <Text style={styles.detailRatingNum}>{placeDetail.rating.toFixed(1)}</Text>
                </View>
              )}
              {placeDetail.address && (
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>📍</Text>
                  <Text style={styles.detailValue}>{placeDetail.address}</Text>
                </View>
              )}
              {placeDetail.phoneNumber && (
                <View style={styles.detailRow}>
                  <Text style={styles.detailLabel}>📞</Text>
                  <Text style={styles.detailValue}>{placeDetail.phoneNumber}</Text>
                </View>
              )}

              <TouchableOpacity
                style={styles.mapsButton}
                onPress={() => openInMaps(placeDetail)}
                activeOpacity={0.7}
              >
                <Text style={styles.mapsButtonText}>Open in Maps</Text>
              </TouchableOpacity>
            </ScrollView>
          ) : (
            <View style={styles.centered}>
              <Text style={styles.emptyTitle}>Could not load details</Text>
            </View>
          )}
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: Spacing.xxxl,
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
  header: {
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.xxl,
    paddingBottom: Spacing.md,
  },
  headerTitle: {
    fontSize: FontSize.xxl,
    fontWeight: '700',
    color: Colors.text,
  },
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    marginBottom: Spacing.md,
    gap: Spacing.sm,
  },
  searchInputWrapper: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.lg,
    paddingHorizontal: Spacing.lg,
  },
  searchIcon: {
    fontSize: FontSize.lg,
    marginRight: Spacing.sm,
  },
  searchInput: {
    flex: 1,
    paddingVertical: Spacing.lg,
    fontSize: FontSize.md,
    color: Colors.text,
  },
  goButton: {
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.lg,
    paddingVertical: Spacing.lg,
    paddingHorizontal: Spacing.xl,
    justifyContent: 'center',
    alignItems: 'center',
  },
  goText: {
    fontSize: FontSize.md,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  chipRow: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.md,
    gap: Spacing.sm,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.full,
    paddingVertical: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    borderWidth: 1,
    borderColor: Colors.border,
    gap: Spacing.xs,
  },
  chipSelected: {
    backgroundColor: Colors.primaryLight,
    borderColor: Colors.primary,
  },
  chipIcon: {
    fontSize: FontSize.md,
  },
  chipLabel: {
    fontSize: FontSize.sm,
    fontWeight: '500',
    color: Colors.textSecondary,
  },
  chipLabelSelected: {
    color: Colors.primaryDark,
    fontWeight: '600',
  },
  errorBar: {
    backgroundColor: '#FFEBEE',
    marginHorizontal: Spacing.lg,
    marginBottom: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.md,
  },
  errorText: {
    fontSize: FontSize.sm,
    color: Colors.error,
    fontWeight: '500',
  },
  loadingLabel: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    marginTop: Spacing.md,
  },
  emptyTitle: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text,
    textAlign: 'center',
    marginBottom: Spacing.sm,
  },
  emptySubtitle: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    textAlign: 'center',
  },
  listContent: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xxxl,
  },
  modalContainer: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  modalHandle: {
    alignItems: 'center',
    paddingTop: Spacing.md,
  },
  handleBar: {
    width: 40,
    height: 5,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.textTertiary,
  },
  modalClose: {
    alignSelf: 'flex-end',
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.md,
  },
  modalCloseText: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.primary,
  },
  detailContent: {
    paddingHorizontal: Spacing.xxl,
    paddingBottom: Spacing.xxxl,
  },
  detailName: {
    fontSize: FontSize.xxl,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.sm,
  },
  detailRatingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.xl,
    gap: Spacing.sm,
  },
  detailStars: {
    fontSize: FontSize.lg,
    color: Colors.warning,
  },
  detailRatingNum: {
    fontSize: FontSize.md,
    color: Colors.textSecondary,
    fontWeight: '500',
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: Spacing.lg,
    gap: Spacing.sm,
  },
  detailLabel: {
    fontSize: FontSize.lg,
    width: 28,
  },
  detailValue: {
    flex: 1,
    fontSize: FontSize.md,
    color: Colors.text,
    lineHeight: 22,
  },
  mapsButton: {
    backgroundColor: Colors.info,
    borderRadius: BorderRadius.lg,
    paddingVertical: Spacing.lg,
    alignItems: 'center',
    marginTop: Spacing.xxl,
  },
  mapsButtonText: {
    fontSize: FontSize.md,
    fontWeight: '700',
    color: '#FFFFFF',
  },
});
