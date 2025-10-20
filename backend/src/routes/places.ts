import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import axios from 'axios';

const router = Router();

// Schema for autocomplete request
const autocompleteSchema = z.object({
  input: z.string().min(1, 'input is required'),
  biasLat: z.number().optional(),
  biasLng: z.number().optional(),
  biasRadiusM: z.number().optional(),
  components: z.string().optional(),
  sessionToken: z.string().optional(),
});

// Schema for place details request
const placeDetailsSchema = z.object({
  placeId: z.string().min(1, 'placeId is required'),
});

// Schema for resolve address request
const resolveAddressSchema = z.object({
  address: z.string().min(1, 'address is required'),
});

/**
 * POST /api/places/autocomplete
 * Proxy endpoint for Google Places Autocomplete API
 * Returns place predictions for autocomplete input
 */
router.post('/places/autocomplete', requireAuth, async (req, res) => {
  try {
    const validated = autocompleteSchema.parse(req.body);
    const {
      input,
      biasLat = 39.7392, // Default: Denver, CO
      biasLng = -104.9903,
      biasRadiusM = 450000, // 450km
      components = 'country:us',
      sessionToken,
    } = validated;

    const googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!googleMapsKey) {
      console.error('[places/autocomplete] GOOGLE_MAPS_API_KEY not configured');
      return res.status(500).json({ message: 'Google Maps API key not configured on server' });
    }

    // Build query parameters
    const params = new URLSearchParams({
      input,
      key: googleMapsKey,
      location: `${biasLat},${biasLng}`,
      radius: biasRadiusM.toString(),
      region: 'us',
    });

    if (components) {
      params.append('components', components);
    }

    if (sessionToken) {
      params.append('sessiontoken', sessionToken);
    }

    const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?${params.toString()}`;

    console.log(`[places/autocomplete] Query: "${input.substring(0, 20)}"`);

    const response = await axios.get(url);

    if (response.status !== 200) {
      console.error('[places/autocomplete] Google API error:', response.status, response.data);
      return res.status(response.status).json({
        message: `Google Places API error: ${response.statusText}`,
      });
    }

    const data = response.data;

    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      console.error('[places/autocomplete] API status:', data.status, data.error_message);
      return res.status(400).json({
        message: `Places autocomplete failed: ${data.status}`,
        error: data.error_message,
      });
    }

    // Return the predictions
    return res.json({
      status: data.status,
      predictions: data.predictions || [],
    });
  } catch (err: any) {
    console.error('[places/autocomplete] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: err.message || 'Failed to get place predictions' });
  }
});

/**
 * POST /api/places/details
 * Proxy endpoint for Google Places Details API
 * Returns detailed information about a specific place
 */
router.post('/places/details', requireAuth, async (req, res) => {
  try {
    const validated = placeDetailsSchema.parse(req.body);
    const { placeId } = validated;

    const googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!googleMapsKey) {
      console.error('[places/details] GOOGLE_MAPS_API_KEY not configured');
      return res.status(500).json({ message: 'Google Maps API key not configured on server' });
    }

    const params = new URLSearchParams({
      place_id: placeId,
      key: googleMapsKey,
      fields: 'formatted_address,geometry,address_components',
    });

    const url = `https://maps.googleapis.com/maps/api/place/details/json?${params.toString()}`;

    console.log(`[places/details] PlaceID: ${placeId.substring(0, 12)}...`);

    const response = await axios.get(url);

    if (response.status !== 200) {
      console.error('[places/details] Google API error:', response.status, response.data);
      return res.status(response.status).json({
        message: `Google Places API error: ${response.statusText}`,
      });
    }

    const data = response.data;

    if (data.status !== 'OK') {
      console.error('[places/details] API status:', data.status, data.error_message);
      return res.status(400).json({
        message: `Places details failed: ${data.status}`,
        error: data.error_message,
      });
    }

    // Return the place details
    return res.json({
      status: data.status,
      result: data.result,
    });
  } catch (err: any) {
    console.error('[places/details] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: err.message || 'Failed to get place details' });
  }
});

/**
 * POST /api/places/resolve-address
 * Convenience endpoint that combines autocomplete + details
 * Resolves a free-form address string to full place details
 */
router.post('/places/resolve-address', requireAuth, async (req, res) => {
  try {
    const validated = resolveAddressSchema.parse(req.body);
    const { address } = validated;

    const googleMapsKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!googleMapsKey) {
      console.error('[places/resolve-address] GOOGLE_MAPS_API_KEY not configured');
      return res.status(500).json({ message: 'Google Maps API key not configured on server' });
    }

    // Step 1: Get autocomplete predictions
    const autocompleteParams = new URLSearchParams({
      input: address,
      key: googleMapsKey,
      location: '39.7392,-104.9903', // Denver, CO
      radius: '450000',
      region: 'us',
      components: 'country:us',
    });

    const autocompleteUrl = `https://maps.googleapis.com/maps/api/place/autocomplete/json?${autocompleteParams.toString()}`;
    const autocompleteResponse = await axios.get(autocompleteUrl);

    if (autocompleteResponse.data.status !== 'OK') {
      return res.json({ status: 'ZERO_RESULTS', result: null });
    }

    const predictions = autocompleteResponse.data.predictions || [];
    if (predictions.length === 0) {
      return res.json({ status: 'ZERO_RESULTS', result: null });
    }

    // Step 2: Get details for first prediction
    const firstPlaceId = predictions[0].place_id;
    const detailsParams = new URLSearchParams({
      place_id: firstPlaceId,
      key: googleMapsKey,
      fields: 'formatted_address,geometry,address_components',
    });

    const detailsUrl = `https://maps.googleapis.com/maps/api/place/details/json?${detailsParams.toString()}`;
    const detailsResponse = await axios.get(detailsUrl);

    if (detailsResponse.data.status !== 'OK') {
      return res.json({ status: 'ZERO_RESULTS', result: null });
    }

    console.log(`[places/resolve-address] Resolved "${address.substring(0, 30)}" to place`);

    return res.json({
      status: 'OK',
      result: detailsResponse.data.result,
    });
  } catch (err: any) {
    console.error('[places/resolve-address] Error:', err);
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid request data', errors: err.issues });
    }
    return res.status(500).json({ message: err.message || 'Failed to resolve address' });
  }
});

export default router;
