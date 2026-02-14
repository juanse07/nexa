import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { ManagerModel } from '../models/manager';

const router = Router();

const updateSchema = z.object({
  first_name: z.string().trim().min(1).max(100).optional(),
  last_name: z.string().trim().min(1).max(100).optional(),
  app_id: z
    .string()
    .regex(/^\d{9}$/)
    .optional(),
  picture: z.string().url().max(2048).optional(),
  isCaricature: z.boolean().optional(), // When true, saves current picture as originalPicture
  preferredCity: z.string().trim().min(1).max(200).optional(),
});

const venueSchema = z.object({
  name: z.string().trim().min(1).max(200),
  address: z.string().trim().min(1).max(500),
  city: z.string().trim().min(1).max(100),
});

const venueUpdateSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  address: z.string().trim().min(1).max(500).optional(),
  city: z.string().trim().min(1).max(100).optional(),
});

const citySchema = z.object({
  name: z.string().trim().min(1).max(200),
  isTourist: z.boolean(),
});

const cityUpdateSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  isTourist: z.boolean().optional(),
});

router.get('/managers/me', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    let manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    }).lean();

    // Auto-provision a manager profile if it doesn't exist yet
    if (!manager) {
      const created = await ManagerModel.create({
        provider: ((req as any).authUser as any).provider,
        subject: ((req as any).authUser as any).sub,
        email: ((req as any).authUser as any).email,
        name: ((req as any).authUser as any).name,
        picture: ((req as any).authUser as any).picture,
      });
      manager = (created.toObject() as any);
    }

    return res.json({
      id: String((manager as any)._id),
      email: (manager as any).email,
      name: (manager as any).name,
      first_name: (manager as any).first_name,
      last_name: (manager as any).last_name,
      picture: (manager as any).picture,
      originalPicture: (manager as any).originalPicture || null,
      caricatureHistory: (manager as any).caricatureHistory || [],
      app_id: (manager as any).app_id,
      provider: (manager as any).provider,
      linked_providers: (manager as any).linked_providers || [],
      auth_phone_number: (manager as any).auth_phone_number || null,
      phone_number: (manager as any).phone_number || null,
      preferredCity: (manager as any).preferredCity, // DEPRECATED
      cities: (manager as any).cities || [],
      venueList: (manager as any).venueList || [],
      venueListUpdatedAt: (manager as any).venueListUpdatedAt,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] GET /me failed', err);
    return res.status(500).json({ message: 'Failed to fetch manager profile', error: (err as Error).message });
  }
});

router.patch('/managers/me', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const parsed = updateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    // If app_id provided, ensure not used by another manager
    if (parsed.data.app_id) {
      const conflict = await ManagerModel.findOne({
        app_id: parsed.data.app_id,
        $or: [
          { provider: { $ne: (req as any).authUser.provider } },
          { subject: { $ne: (req as any).authUser.sub } },
        ],
      }).lean();
      if (conflict) {
        return res.status(409).json({ message: 'This App ID is already in use' });
      }
    }

    // If this is a caricature update, save the current picture as originalPicture
    const { isCaricature, ...updateFields } = parsed.data;
    const setData: Record<string, any> = { ...updateFields, updatedAt: new Date() };

    if (isCaricature && updateFields.picture) {
      const current = await ManagerModel.findOne({
        provider: (req as any).authUser.provider,
        subject: (req as any).authUser.sub,
      }).lean();
      if (current?.picture) {
        setData.originalPicture = current.picture;
      }
    }

    const updated = await ManagerModel.findOneAndUpdate(
      { provider: (req as any).authUser.provider, subject: (req as any).authUser.sub },
      {
        $set: setData,
      },
      { new: true }
    ).lean();
    if (!updated) return res.status(404).json({ message: 'Manager not found' });
    return res.json({
      id: String(updated._id),
      email: updated.email,
      name: updated.name,
      first_name: updated.first_name,
      last_name: updated.last_name,
      picture: updated.picture,
      originalPicture: updated.originalPicture || null,
      app_id: updated.app_id,
      preferredCity: updated.preferredCity, // DEPRECATED
      cities: updated.cities || [],
      venueList: updated.venueList || [],
      venueListUpdatedAt: updated.venueListUpdatedAt,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] PATCH /me failed', err);
    return res.status(500).json({ message: 'Failed to update manager profile', error: (err as Error).message });
  }
});

// POST /managers/me/revert-picture - Revert to original (pre-caricature) picture
router.post('/managers/me/revert-picture', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.originalPicture) {
      return res.status(400).json({ message: 'No original picture to revert to' });
    }

    manager.picture = manager.originalPicture;
    manager.originalPicture = undefined;
    await manager.save();

    return res.json({
      picture: manager.picture,
      originalPicture: null,
      message: 'Reverted to original picture',
    });
  } catch (err) {
    console.error('[managers] POST /me/revert-picture failed', err);
    return res.status(500).json({ message: 'Failed to revert picture', error: (err as Error).message });
  }
});

// DELETE /managers/me/caricatures/:index - Delete a caricature from history
router.delete('/managers/me/caricatures/:index', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const index = parseInt(req.params.index || '0', 10);
    if (isNaN(index) || index < 0) {
      return res.status(400).json({ message: 'Invalid index parameter' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.caricatureHistory || index >= manager.caricatureHistory.length) {
      return res.status(404).json({ message: 'Caricature not found at index' });
    }

    manager.caricatureHistory.splice(index, 1);
    await manager.save();

    return res.json({
      message: 'Caricature deleted',
      caricatureHistory: manager.caricatureHistory,
    });
  } catch (err) {
    console.error('[managers] DELETE /me/caricatures/:index failed', err);
    return res.status(500).json({ message: 'Failed to delete caricature', error: (err as Error).message });
  }
});

// POST /managers/me/venues - Add a new venue
router.post('/managers/me/venues', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const parsed = venueSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    // Add new venue with source='manual'
    const newVenue = { ...parsed.data, source: 'manual' as const };
    manager.venueList = manager.venueList || [];
    manager.venueList.push(newVenue);
    await manager.save();

    return res.status(201).json({
      message: 'Venue added successfully',
      venueList: manager.venueList,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] POST /me/venues failed', err);
    return res.status(500).json({ message: 'Failed to add venue', error: (err as Error).message });
  }
});

// PATCH /managers/me/venues/:index - Update a venue at specific index
router.patch('/managers/me/venues/:index', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const index = parseInt(req.params.index || '0', 10);
    if (isNaN(index) || index < 0) {
      return res.status(400).json({ message: 'Invalid index parameter' });
    }

    const parsed = venueUpdateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    // At least one field must be provided
    if (!parsed.data.name && !parsed.data.address && !parsed.data.city) {
      return res.status(400).json({ message: 'At least one field (name, address, city) must be provided' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.venueList || index >= manager.venueList.length) {
      return res.status(404).json({ message: 'Venue not found at index' });
    }

    // Update venue fields (preserve source)
    const venue = manager.venueList[index];
    if (venue) {
      if (parsed.data.name) venue.name = parsed.data.name;
      if (parsed.data.address) venue.address = parsed.data.address;
      if (parsed.data.city) venue.city = parsed.data.city;
    }

    await manager.save();

    return res.json({
      message: 'Venue updated successfully',
      venueList: manager.venueList,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] PATCH /me/venues/:index failed', err);
    return res.status(500).json({ message: 'Failed to update venue', error: (err as Error).message });
  }
});

// DELETE /managers/me/venues/:index - Delete a venue at specific index
router.delete('/managers/me/venues/:index', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const index = parseInt(req.params.index || '0', 10);
    if (isNaN(index) || index < 0) {
      return res.status(400).json({ message: 'Invalid index parameter' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.venueList || index >= manager.venueList.length) {
      return res.status(404).json({ message: 'Venue not found at index' });
    }

    // Remove venue at index
    manager.venueList.splice(index, 1);
    await manager.save();

    return res.json({
      message: 'Venue deleted successfully',
      venueList: manager.venueList,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] DELETE /me/venues/:index failed', err);
    return res.status(500).json({ message: 'Failed to delete venue', error: (err as Error).message });
  }
});

// POST /managers/me/cities - Add a new city
router.post('/managers/me/cities', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const parsed = citySchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    // Check for duplicate city name
    const existingCity = (manager.cities || []).find(
      (c) => c.name.toLowerCase() === parsed.data.name.toLowerCase()
    );
    if (existingCity) {
      return res.status(409).json({ message: 'This city is already in your list' });
    }

    // Add new city
    manager.cities = manager.cities || [];
    manager.cities.push(parsed.data);
    await manager.save();

    return res.status(201).json({
      message: 'City added successfully',
      cities: manager.cities,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] POST /me/cities failed', err);
    return res.status(500).json({ message: 'Failed to add city', error: (err as Error).message });
  }
});

// PATCH /managers/me/cities/:index - Update a city at specific index
router.patch('/managers/me/cities/:index', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const index = parseInt(req.params.index || '0', 10);
    if (isNaN(index) || index < 0) {
      return res.status(400).json({ message: 'Invalid index parameter' });
    }

    const parsed = cityUpdateSchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', details: parsed.error.format() });
    }

    // At least one field must be provided
    if (parsed.data.name === undefined && parsed.data.isTourist === undefined) {
      return res.status(400).json({ message: 'At least one field (name, isTourist) must be provided' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.cities || index >= manager.cities.length) {
      return res.status(404).json({ message: 'City not found at index' });
    }

    // Check for duplicate city name if updating name
    if (parsed.data.name) {
      const duplicate = manager.cities.find(
        (c, i) => i !== index && c.name.toLowerCase() === parsed.data.name!.toLowerCase()
      );
      if (duplicate) {
        return res.status(409).json({ message: 'This city name is already in your list' });
      }
    }

    // Update city fields
    const city = manager.cities[index];
    if (city) {
      if (parsed.data.name !== undefined) city.name = parsed.data.name;
      if (parsed.data.isTourist !== undefined) city.isTourist = parsed.data.isTourist;
    }

    await manager.save();

    return res.json({
      message: 'City updated successfully',
      cities: manager.cities,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] PATCH /me/cities/:index failed', err);
    return res.status(500).json({ message: 'Failed to update city', error: (err as Error).message });
  }
});

// DELETE /managers/me/cities/:index - Delete a city at specific index
router.delete('/managers/me/cities/:index', requireAuth, async (req, res) => {
  try {
    if (!(req as any).authUser?.provider || !(req as any).authUser?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const index = parseInt(req.params.index || '0', 10);
    if (isNaN(index) || index < 0) {
      return res.status(400).json({ message: 'Invalid index parameter' });
    }

    const manager = await ManagerModel.findOne({
      provider: (req as any).authUser.provider,
      subject: (req as any).authUser.sub,
    });
    if (!manager) return res.status(404).json({ message: 'Manager not found' });

    if (!manager.cities || index >= manager.cities.length) {
      return res.status(404).json({ message: 'City not found at index' });
    }

    const cityToDelete = manager.cities[index];
    if (!cityToDelete) {
      return res.status(404).json({ message: 'City not found at index' });
    }
    const deletedCityName = cityToDelete.name;

    // Remove city at index
    manager.cities.splice(index, 1);

    // Optionally remove venues associated with this city
    if (manager.venueList) {
      manager.venueList = manager.venueList.filter((v) => v.cityName !== deletedCityName);
    }

    await manager.save();

    return res.json({
      message: 'City and associated venues deleted successfully',
      cities: manager.cities,
      venueList: manager.venueList || [],
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[managers] DELETE /me/cities/:index failed', err);
    return res.status(500).json({ message: 'Failed to delete city', error: (err as Error).message });
  }
});

export default router;


