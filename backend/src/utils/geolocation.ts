/**
 * Geolocation utilities for server-side geofence validation
 */

// Earth's radius in meters
const EARTH_RADIUS_METERS = 6371000;

/**
 * Convert degrees to radians
 */
function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}

/**
 * Calculate the distance between two geographic coordinates using the Haversine formula.
 * This formula calculates the great-circle distance between two points on a sphere.
 *
 * @param lat1 - Latitude of point 1 in degrees
 * @param lon1 - Longitude of point 1 in degrees
 * @param lat2 - Latitude of point 2 in degrees
 * @param lon2 - Longitude of point 2 in degrees
 * @returns Distance in meters
 */
export function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_METERS * c;
}

/**
 * Check if a point is within a circular geofence
 *
 * @param pointLat - Latitude of the point to check
 * @param pointLon - Longitude of the point to check
 * @param centerLat - Latitude of the geofence center
 * @param centerLon - Longitude of the geofence center
 * @param radiusMeters - Radius of the geofence in meters
 * @returns Object with isInside boolean and distance in meters
 */
export function isWithinGeofence(
  pointLat: number,
  pointLon: number,
  centerLat: number,
  centerLon: number,
  radiusMeters: number
): { isInside: boolean; distanceMeters: number } {
  const distanceMeters = calculateDistance(pointLat, pointLon, centerLat, centerLon);

  return {
    isInside: distanceMeters <= radiusMeters,
    distanceMeters: Math.round(distanceMeters),
  };
}

/**
 * Default geofence radius in meters (500m = ~0.3 miles)
 * This is a reasonable default for most venues
 */
export const DEFAULT_GEOFENCE_RADIUS_METERS = 500;

/**
 * Format distance for human-readable display
 *
 * @param meters - Distance in meters
 * @returns Formatted string (e.g., "150m" or "1.2km")
 */
export function formatDistance(meters: number): string {
  if (meters < 1000) {
    return `${Math.round(meters)}m`;
  }
  return `${(meters / 1000).toFixed(1)}km`;
}

/**
 * Validate that coordinates are within valid ranges
 *
 * @param lat - Latitude to validate (-90 to 90)
 * @param lon - Longitude to validate (-180 to 180)
 * @returns true if coordinates are valid
 */
export function isValidCoordinate(lat: number, lon: number): boolean {
  return (
    typeof lat === 'number' &&
    typeof lon === 'number' &&
    !isNaN(lat) &&
    !isNaN(lon) &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180
  );
}
