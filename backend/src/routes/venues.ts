import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { ManagerModel } from '../models/manager';
import { VenueModel } from '../models/venue';

const router = Router();

// Validation schemas
const createVenueSchema = z.object({
  name: z.string().trim().min(1).max(200),
  address: z.string().trim().min(1).max(500),
  city: z.string().trim().min(1).max(100),
  state: z.string().trim().max(100).optional(),
  country: z.string().trim().max(100).optional(),
  placeId: z.string().trim().max(500).optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  source: z.enum(['manual', 'ai', 'places']).optional().default('manual'),
});

const updateVenueSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  address: z.string().trim().min(1).max(500).optional(),
  city: z.string().trim().min(1).max(100).optional(),
  state: z.string().trim().max(100).optional(),
  country: z.string().trim().max(100).optional(),
  placeId: z.string().trim().max(500).optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
});

// Helper to get manager from auth
async function getManagerFromAuth(req: any) {
  if (!req.authUser?.provider || !req.authUser?.sub) {
    return null;
  }
  return ManagerModel.findOne({
    provider: req.authUser.provider,
    subject: req.authUser.sub,
  });
}

// GET /api/venues - List all venues for the authenticated manager
router.get('/venues', requireAuth, async (req, res) => {
  try {
    const manager = await getManagerFromAuth(req);
    if (!manager) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const venues = await VenueModel.find({ managerId: manager._id })
      .sort({ name: 1 })
      .lean();

    return res.json({
      venues: venues.map((v) => ({
        id: String(v._id),
        name: v.name,
        address: v.address,
        city: v.city,
        state: v.state,
        country: v.country,
        placeId: v.placeId,
        latitude: v.latitude,
        longitude: v.longitude,
        source: v.source,
        createdAt: v.createdAt,
        updatedAt: v.updatedAt,
      })),
    });
  } catch (err) {
    console.error('[venues] GET /venues failed', err);
    return res.status(500).json({ message: 'Failed to fetch venues', error: (err as Error).message });
  }
});

// Helper to check if city exists in manager's cities list
function cityExistsInManager(manager: any, cityName: string): boolean {
  const existingCities = manager.cities || [];
  const normalizedCity = cityName.trim().toLowerCase();
  return existingCities.some((c: any) => {
    const name = c.name.split(',')[0].trim().toLowerCase();
    return name === normalizedCity;
  });
}

// Helper to add city to manager
async function addCityToManager(manager: any, city: string, state?: string, country?: string): Promise<string> {
  const existingCities = manager.cities || [];
  const finalCountry = country || 'United States';
  const fullCityName = state
    ? `${city}, ${state}, ${finalCountry}`
    : `${city}, ${finalCountry}`;

  manager.cities = [
    ...existingCities,
    { name: fullCityName, isTourist: false }
  ];
  await manager.save();
  console.log(`[venues] Auto-created city "${fullCityName}" for manager ${manager._id}`);
  return fullCityName;
}

// POST /api/venues - Create a new venue
router.post('/venues', requireAuth, async (req, res) => {
  try {
    const manager = await getManagerFromAuth(req);
    if (!manager) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const parsed = createVenueSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Invalid venue data',
        errors: parsed.error.flatten().fieldErrors,
      });
    }

    const venueData = parsed.data;
    const venueCity = venueData.city.trim();

    // Check for duplicate venue name within the same city
    const normalizedName = venueData.name.trim().toLowerCase();
    const normalizedCity = venueCity.toLowerCase();
    const existing = await VenueModel.findOne({
      managerId: manager._id,
      normalizedName,
      city: { $regex: new RegExp(`^${normalizedCity}$`, 'i') },
    });

    if (existing) {
      // Check if the city is visible to the user
      const cityVisible = cityExistsInManager(manager, venueCity);

      if (!cityVisible) {
        // City not in manager's list - this is an "orphaned" venue
        // Update the existing venue with new details instead of blocking
        console.log(`[venues] Updating orphaned venue "${existing.name}" in ${venueCity}`);

        // Update the existing venue
        existing.address = venueData.address;
        existing.state = venueData.state;
        existing.country = venueData.country;
        existing.placeId = venueData.placeId;
        existing.latitude = venueData.latitude;
        existing.longitude = venueData.longitude;
        existing.source = venueData.source;
        await existing.save();

        // Now create the city so they can see it
        const fullCityName = await addCityToManager(manager, venueCity, venueData.state, venueData.country);

        return res.status(200).json({
          id: String(existing._id),
          name: existing.name,
          address: existing.address,
          city: existing.city,
          state: existing.state,
          country: existing.country,
          placeId: existing.placeId,
          latitude: existing.latitude,
          longitude: existing.longitude,
          source: existing.source,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
          cityCreated: true,
          wasUpdated: true, // Let frontend know this was an update
          message: `Updated existing venue and added ${fullCityName} to your cities`,
        });
      }

      // City is visible - return normal duplicate error
      return res.status(409).json({
        message: `A venue with this name already exists in ${venueData.city}`,
        existingVenueId: String(existing._id),
      });
    }

    // No duplicate - create new venue
    const venue = await VenueModel.create({
      managerId: manager._id,
      ...venueData,
    });

    // Auto-create city if it doesn't exist in manager's cities list
    let cityCreated = false;
    if (!cityExistsInManager(manager, venueCity)) {
      await addCityToManager(manager, venueCity, venueData.state, venueData.country);
      cityCreated = true;
    }

    return res.status(201).json({
      id: String(venue._id),
      name: venue.name,
      address: venue.address,
      city: venue.city,
      state: venue.state,
      country: venue.country,
      placeId: venue.placeId,
      latitude: venue.latitude,
      longitude: venue.longitude,
      source: venue.source,
      createdAt: venue.createdAt,
      updatedAt: venue.updatedAt,
      cityCreated, // Let frontend know a new city tab was added
    });
  } catch (err) {
    console.error('[venues] POST /venues failed', err);
    return res.status(500).json({ message: 'Failed to create venue', error: (err as Error).message });
  }
});

// PATCH /api/venues/:id - Update a venue
router.patch('/venues/:id', requireAuth, async (req, res) => {
  try {
    const manager = await getManagerFromAuth(req);
    if (!manager) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const { id } = req.params;

    const parsed = updateVenueSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        message: 'Invalid venue data',
        errors: parsed.error.flatten().fieldErrors,
      });
    }

    const venue = await VenueModel.findOne({
      _id: id,
      managerId: manager._id,
    });

    if (!venue) {
      return res.status(404).json({ message: 'Venue not found' });
    }

    // If name is being changed, check for duplicates within same city
    if (parsed.data.name) {
      const normalizedName = parsed.data.name.trim().toLowerCase();
      const cityToCheck = parsed.data.city || venue.city;
      const existing = await VenueModel.findOne({
        managerId: manager._id,
        normalizedName,
        city: { $regex: new RegExp(`^${cityToCheck}$`, 'i') },
        _id: { $ne: id },
      });

      if (existing) {
        return res.status(409).json({
          message: `A venue with this name already exists in ${cityToCheck}`,
        });
      }
    }

    Object.assign(venue, parsed.data);
    await venue.save();

    return res.json({
      id: String(venue._id),
      name: venue.name,
      address: venue.address,
      city: venue.city,
      state: venue.state,
      country: venue.country,
      placeId: venue.placeId,
      latitude: venue.latitude,
      longitude: venue.longitude,
      source: venue.source,
      createdAt: venue.createdAt,
      updatedAt: venue.updatedAt,
    });
  } catch (err) {
    console.error('[venues] PATCH /venues/:id failed', err);
    return res.status(500).json({ message: 'Failed to update venue', error: (err as Error).message });
  }
});

// DELETE /api/venues/:id - Delete a venue
router.delete('/venues/:id', requireAuth, async (req, res) => {
  try {
    const manager = await getManagerFromAuth(req);
    if (!manager) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const { id } = req.params;

    const result = await VenueModel.deleteOne({
      _id: id,
      managerId: manager._id,
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({ message: 'Venue not found' });
    }

    return res.status(204).send();
  } catch (err) {
    console.error('[venues] DELETE /venues/:id failed', err);
    return res.status(500).json({ message: 'Failed to delete venue', error: (err as Error).message });
  }
});

export default router;
