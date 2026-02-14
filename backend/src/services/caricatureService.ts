import pino from 'pino';
import crypto from 'crypto';
import { ManagerModel } from '../models/manager';
import { UserModel } from '../models/user';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

// ── Cache Key Generation ──

function hashString(input: string): string {
  return crypto.createHash('md5').update(input).digest('hex').slice(0, 16);
}

/**
 * Generate a cache key from generation parameters.
 * Uses MD5 hash of pictureUrl + role + artStyle + model + overlayText.
 */
export function generateCacheKey(
  pictureUrl: string,
  role: string,
  artStyle: string,
  model: string,
  overlayText?: string,
): string {
  const pictureHash = hashString(pictureUrl);
  const content = `${pictureHash}-${role}-${artStyle}-${model}-${overlayText || ''}`;
  return crypto.createHash('md5').update(content).digest('hex');
}

/**
 * Look up a cached caricature by cache key across all managers and users.
 * Returns the most recent match within maxAgeInDays, or null.
 */
export async function getCachedCaricature(
  cacheKey: string,
  maxAgeInDays: number = 30,
): Promise<{
  url: string;
  role: string;
  artStyle: string;
  model: string;
  overlayText?: string;
  createdAt: Date;
} | null> {
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - maxAgeInDays);

    // Use $elemMatch for precise array element matching
    const query = {
      caricatureHistory: {
        $elemMatch: {
          cacheKey,
          createdAt: { $gte: cutoffDate },
        },
      },
    };

    // Search in manager history
    const managers = await ManagerModel.find(query).select('caricatureHistory').lean();
    logger.info({ cacheKey, managersFound: managers.length }, 'Caricature cache: searched managers');

    for (const manager of managers) {
      const entries = (manager.caricatureHistory as any[]) ?? [];
      const cached = entries.find(
        (item: any) =>
          item.cacheKey === cacheKey &&
          new Date(item.createdAt) >= cutoffDate,
      );
      if (cached) {
        logger.info({ cacheKey, url: cached.url }, 'Caricature cache HIT in managers');
        return {
          url: cached.url,
          role: cached.role,
          artStyle: cached.artStyle,
          model: cached.model,
          overlayText: cached.overlayText,
          createdAt: new Date(cached.createdAt),
        };
      }
    }

    // Search in user history
    const users = await UserModel.find(query).select('caricatureHistory').lean();
    logger.info({ cacheKey, usersFound: users.length }, 'Caricature cache: searched users');

    for (const user of users) {
      const entries = (user.caricatureHistory as any[]) ?? [];
      const cached = entries.find(
        (item: any) =>
          item.cacheKey === cacheKey &&
          new Date(item.createdAt) >= cutoffDate,
      );
      if (cached) {
        logger.info({ cacheKey, url: cached.url }, 'Caricature cache HIT in users');
        return {
          url: cached.url,
          role: cached.role,
          artStyle: cached.artStyle,
          model: cached.model,
          overlayText: cached.overlayText,
          createdAt: new Date(cached.createdAt),
        };
      }
    }

    logger.info({ cacheKey }, 'Caricature cache: no match found');
    return null;
  } catch (error) {
    logger.error({ error, cacheKey }, 'Caricature cache lookup error');
    return null; // Fail gracefully — proceed with generation
  }
}

/** Available caricature roles (scene/context) */
export type CaricatureRole =
  // Hospitality & Events
  | 'bartender' | 'server' | 'security' | 'dj' | 'host'
  | 'coordinator' | 'chef' | 'busser' | 'barback' | 'manager'
  | 'photographer' | 'valet'
  // Healthcare
  | 'physician' | 'nurse' | 'surgeon' | 'dentist' | 'veterinarian' | 'paramedic'
  // Legal & Business
  | 'lawyer' | 'accountant' | 'ceo' | 'realtor' | 'consultant'
  // Tech
  | 'software_engineer' | 'data_scientist' | 'ux_designer'
  // Trades & Construction
  | 'construction_worker' | 'electrician' | 'plumber' | 'mechanic'
  | 'welder' | 'carpenter' | 'architect'
  // Creative
  | 'musician' | 'artist' | 'filmmaker' | 'writer' | 'fashion_designer'
  // Emergency & Service
  | 'firefighter' | 'police_officer' | 'pilot' | 'military'
  // Education
  | 'teacher' | 'professor'
  // Sports & Fitness
  | 'athlete' | 'personal_trainer' | 'yoga_instructor'
  // Science
  | 'scientist' | 'astronaut';

/** Available art styles (rendering) */
export type ArtStyle = 'cartoon' | 'caricature' | 'anime' | 'comic' | 'pixar' | 'watercolor';

/** FLUX.1 Kontext model quality tier */
export type CaricatureModel = 'dev' | 'pro';

const MODEL_MAP: Record<CaricatureModel, string> = {
  dev: 'black-forest-labs/FLUX.1-kontext-dev',
  pro: 'black-forest-labs/FLUX.1-kontext-pro',
};

interface RoleDefinition {
  id: CaricatureRole;
  label: string;
  icon: string;
  category: string;
  scene: string;
}

interface ArtStyleDefinition {
  id: ArtStyle;
  label: string;
  icon: string;
  rendering: string;
  negativePrompt: string;
}

/** Identity preservation + transformation boundary — placed at the top of every prompt */
const IDENTITY_INSTRUCTION = `CRITICAL IDENTITY RULES — follow these exactly:
1. The uploaded photo is the ONLY reference for this person's identity. COPY their face, bone structure, skin tone, hair, and gender EXACTLY.
2. If the person in the photo is female, the result MUST be female. If male, MUST be male. NEVER change gender.
3. Do NOT add facial hair to a clean-shaven face. Do NOT remove existing facial hair.
4. Only change clothing, background, props, and artistic style — the PERSON stays identical.`;

const ROLE_DEFINITIONS: Record<CaricatureRole, RoleDefinition> = {
  // ═══════════════════════════════════════════
  // Hospitality & Events
  // ═══════════════════════════════════════════
  bartender: {
    id: 'bartender',
    label: 'Bartender',
    icon: 'local_bar',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Bartender behind a well-stocked bar, wearing a vest and apron. Confidently shaking a cocktail or presenting a drink.`,
  },
  server: {
    id: 'server',
    label: 'Server',
    icon: 'restaurant',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Server in a restaurant, wearing a neat apron. Carrying a tray or presenting a dish with poise.`,
  },
  security: {
    id: 'security',
    label: 'Security',
    icon: 'security',
    category: 'Hospitality & Events',
    scene: `Depict this person as Security at a venue entrance, wearing a fitted shirt with an earpiece and sunglasses. Standing with a confident, solid stance.`,
  },
  dj: {
    id: 'dj',
    label: 'DJ',
    icon: 'headphones',
    category: 'Hospitality & Events',
    scene: `Depict this person as a DJ in a booth with turntables and mixer, wearing headphones tilted on one ear. Hands on the decks, feeling the music.`,
  },
  host: {
    id: 'host',
    label: 'Host',
    icon: 'emoji_people',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Host at a venue entrance, wearing smart casual. Holding a tablet or guest list with a warm smile.`,
  },
  coordinator: {
    id: 'coordinator',
    label: 'Coordinator',
    icon: 'event_note',
    category: 'Hospitality & Events',
    scene: `Depict this person as an Event Coordinator with a headset and tablet, wearing a smart blazer. Directing confidently at a venue in setup.`,
  },
  chef: {
    id: 'chef',
    label: 'Chef',
    icon: 'soup_kitchen',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Chef in a kitchen, wearing a white chef jacket. Arms crossed confidently or plating a dish, gentle steam around.`,
  },
  busser: {
    id: 'busser',
    label: 'Busser',
    icon: 'cleaning_services',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Busser in a restaurant dining room, wearing a polo and apron. Efficiently working the floor, carrying items.`,
  },
  barback: {
    id: 'barback',
    label: 'Barback',
    icon: 'liquor',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Barback behind the bar, wearing an apron amid bottles and glassware. Carrying bottles or ice with confident steady movements.`,
  },
  manager: {
    id: 'manager',
    label: 'Manager',
    icon: 'business_center',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Manager at an event venue, wearing smart business casual. Holding a tablet, calm and in charge, staff in the background.`,
  },
  photographer: {
    id: 'photographer',
    label: 'Photographer',
    icon: 'camera_alt',
    category: 'Hospitality & Events',
    scene: `Depict this person as an Event Photographer at a scene, wearing all-black with a camera strap. Holding a professional camera, ready to shoot.`,
  },
  valet: {
    id: 'valet',
    label: 'Valet',
    icon: 'directions_car',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Valet at a venue entrance, wearing a sharp vest. Standing with car keys in hand beside a nice car.`,
  },

  // ═══════════════════════════════════════════
  // Healthcare
  // ═══════════════════════════════════════════
  physician: {
    id: 'physician',
    label: 'Physician',
    icon: 'medical_services',
    category: 'Healthcare',
    scene: `Depict this person as a Physician in a clinic or hospital, wearing a white lab coat with a stethoscope. Standing confidently with a clipboard.`,
  },
  nurse: {
    id: 'nurse',
    label: 'Nurse',
    icon: 'favorite',
    category: 'Healthcare',
    scene: `Depict this person as a Nurse in a hospital ward, wearing scrubs with a badge and stethoscope. Caring expression, holding a tablet.`,
  },
  surgeon: {
    id: 'surgeon',
    label: 'Surgeon',
    icon: 'healing',
    category: 'Healthcare',
    scene: `Depict this person as a Surgeon in an operating room, wearing surgical scrubs and cap, mask pulled down. Arms crossed confidently, gloves on.`,
  },
  dentist: {
    id: 'dentist',
    label: 'Dentist',
    icon: 'mood',
    category: 'Healthcare',
    scene: `Depict this person as a Dentist in a dental office, wearing a white coat with a dental mirror in hand. Warm confident smile.`,
  },
  veterinarian: {
    id: 'veterinarian',
    label: 'Veterinarian',
    icon: 'pets',
    category: 'Healthcare',
    scene: `Depict this person as a Veterinarian in an animal clinic, wearing a lab coat or scrubs. Gently holding or examining a cute dog or cat.`,
  },
  paramedic: {
    id: 'paramedic',
    label: 'Paramedic',
    icon: 'local_hospital',
    category: 'Healthcare',
    scene: `Depict this person as a Paramedic near an ambulance, wearing an EMT uniform with reflective strips and a radio. Determined heroic stance.`,
  },

  // ═══════════════════════════════════════════
  // Legal & Business
  // ═══════════════════════════════════════════
  lawyer: {
    id: 'lawyer',
    label: 'Lawyer',
    icon: 'gavel',
    category: 'Legal & Business',
    scene: `Depict this person as a Lawyer in a courtroom or law office, wearing sharp professional attire. Commanding presence, holding a briefcase or at a podium.`,
  },
  accountant: {
    id: 'accountant',
    label: 'Accountant',
    icon: 'calculate',
    category: 'Legal & Business',
    scene: `Depict this person as an Accountant in a modern office, wearing business professional attire. Confident expression, surrounded by monitors showing charts.`,
  },
  ceo: {
    id: 'ceo',
    label: 'CEO',
    icon: 'trending_up',
    category: 'Legal & Business',
    scene: `Depict this person as a CEO in a corner office with city skyline windows, wearing impeccable executive attire. Power pose, emanating authority and vision.`,
  },
  realtor: {
    id: 'realtor',
    label: 'Realtor',
    icon: 'home',
    category: 'Legal & Business',
    scene: `Depict this person as a Realtor in front of a luxury home with a SOLD sign, wearing smart business casual. Holding house keys and a tablet with a warm smile.`,
  },
  consultant: {
    id: 'consultant',
    label: 'Consultant',
    icon: 'assessment',
    category: 'Legal & Business',
    scene: `Depict this person as a Business Consultant in a conference room, wearing a modern blazer. Presenting confidently, gesturing at a whiteboard with strategy diagrams.`,
  },

  // ═══════════════════════════════════════════
  // Tech
  // ═══════════════════════════════════════════
  software_engineer: {
    id: 'software_engineer',
    label: 'Software Engineer',
    icon: 'code',
    category: 'Tech',
    scene: `Depict this person as a Software Engineer at a desk with multiple monitors showing code, wearing casual tech attire. Focused, hands on keyboard, coffee nearby.`,
  },
  data_scientist: {
    id: 'data_scientist',
    label: 'Data Scientist',
    icon: 'insights',
    category: 'Tech',
    scene: `Depict this person as a Data Scientist in front of screens with data visualizations, wearing smart casual. Thoughtful analytical expression.`,
  },
  ux_designer: {
    id: 'ux_designer',
    label: 'UX Designer',
    icon: 'design_services',
    category: 'Tech',
    scene: `Depict this person as a UX Designer at a workspace with wireframes and UI mockups, wearing creative casual. Holding a stylus, focused and creative.`,
  },

  // ═══════════════════════════════════════════
  // Trades & Construction
  // ═══════════════════════════════════════════
  construction_worker: {
    id: 'construction_worker',
    label: 'Construction',
    icon: 'construction',
    category: 'Trades & Construction',
    scene: `Depict this person as a Construction Worker at a construction site, wearing a hard hat and high-vis vest. Confident stance, holding blueprints or tools.`,
  },
  electrician: {
    id: 'electrician',
    label: 'Electrician',
    icon: 'electrical_services',
    category: 'Trades & Construction',
    scene: `Depict this person as an Electrician working on an electrical panel, wearing a work uniform with tool belt. Skilled and focused, safety goggles on forehead.`,
  },
  plumber: {
    id: 'plumber',
    label: 'Plumber',
    icon: 'plumbing',
    category: 'Trades & Construction',
    scene: `Depict this person as a Plumber working on pipes, wearing work overalls with a tool belt and wrench. Skilled and confident.`,
  },
  mechanic: {
    id: 'mechanic',
    label: 'Mechanic',
    icon: 'build',
    category: 'Trades & Construction',
    scene: `Depict this person as a Mechanic in a professional auto shop, wearing a work jumpsuit. Holding a wrench with a confident smile, a car on a lift behind.`,
  },
  welder: {
    id: 'welder',
    label: 'Welder',
    icon: 'local_fire_department',
    category: 'Trades & Construction',
    scene: `Depict this person as a Welder in a workshop with metal sparks, wearing a leather apron with welding helmet flipped up. Confident stance, holding a welding torch.`,
  },
  carpenter: {
    id: 'carpenter',
    label: 'Carpenter',
    icon: 'carpenter',
    category: 'Trades & Construction',
    scene: `Depict this person as a Carpenter in a woodworking shop, wearing a flannel shirt with tool belt. Sanding or assembling a piece, sawdust in the air.`,
  },
  architect: {
    id: 'architect',
    label: 'Architect',
    icon: 'architecture',
    category: 'Trades & Construction',
    scene: `Depict this person as an Architect in a studio with models and blueprints, wearing a smart blazer with rolled sleeves. Examining a building model with a visionary expression.`,
  },

  // ═══════════════════════════════════════════
  // Creative
  // ═══════════════════════════════════════════
  musician: {
    id: 'musician',
    label: 'Musician',
    icon: 'music_note',
    category: 'Creative',
    scene: `Depict this person as a Musician on a stage with spotlights and a crowd silhouette. Playing a guitar or at a microphone, lost in the music.`,
  },
  artist: {
    id: 'artist',
    label: 'Artist',
    icon: 'palette',
    category: 'Creative',
    scene: `Depict this person as an Artist in an art studio with large colorful canvases. Holding a paintbrush, vibrant paint on palette, inspired expression.`,
  },
  filmmaker: {
    id: 'filmmaker',
    label: 'Filmmaker',
    icon: 'videocam',
    category: 'Creative',
    scene: `Depict this person as a Filmmaker on a film set with cameras and lights. Sitting in a director's chair or looking through a viewfinder.`,
  },
  writer: {
    id: 'writer',
    label: 'Writer',
    icon: 'edit',
    category: 'Creative',
    scene: `Depict this person as a Writer in a cozy study with bookshelves. Deep in thought with a cup of coffee, surrounded by books.`,
  },
  fashion_designer: {
    id: 'fashion_designer',
    label: 'Fashion Designer',
    icon: 'checkroom',
    category: 'Creative',
    scene: `Depict this person as a Fashion Designer in a fashion studio with mannequins and fabric rolls. Measuring tape around neck, draping fabric artistically.`,
  },

  // ═══════════════════════════════════════════
  // Emergency & Service
  // ═══════════════════════════════════════════
  firefighter: {
    id: 'firefighter',
    label: 'Firefighter',
    icon: 'local_fire_department',
    category: 'Emergency & Service',
    scene: `Depict this person as a Firefighter in front of a fire truck, wearing turnout gear with helmet. Heroic stance, axe or hose in hand, smoky background.`,
  },
  police_officer: {
    id: 'police_officer',
    label: 'Police Officer',
    icon: 'local_police',
    category: 'Emergency & Service',
    scene: `Depict this person as a Police Officer next to a patrol car, wearing a uniform with badge and duty belt. Confident protective stance.`,
  },
  pilot: {
    id: 'pilot',
    label: 'Pilot',
    icon: 'flight',
    category: 'Emergency & Service',
    scene: `Depict this person as a Pilot on an airport tarmac with a jet behind, wearing a pilot uniform with aviator sunglasses. Confident walk with flight case.`,
  },
  military: {
    id: 'military',
    label: 'Military',
    icon: 'military_tech',
    category: 'Emergency & Service',
    scene: `Depict this person as a Military Service Member in a decorated dress uniform with medals, American flag backdrop. Standing at attention with pride and honor.`,
  },

  // ═══════════════════════════════════════════
  // Education
  // ═══════════════════════════════════════════
  teacher: {
    id: 'teacher',
    label: 'Teacher',
    icon: 'school',
    category: 'Education',
    scene: `Depict this person as a Teacher in a bright classroom with a chalkboard and books. Smiling warmly, holding a book or writing on the board.`,
  },
  professor: {
    id: 'professor',
    label: 'Professor',
    icon: 'history_edu',
    category: 'Education',
    scene: `Depict this person as a University Professor in a lecture hall or library, wearing academic professional attire. At a podium, intellectual and distinguished.`,
  },

  // ═══════════════════════════════════════════
  // Sports & Fitness
  // ═══════════════════════════════════════════
  athlete: {
    id: 'athlete',
    label: 'Athlete',
    icon: 'sports',
    category: 'Sports & Fitness',
    scene: `Depict this person as a Professional Athlete in a stadium with floodlights, wearing athletic gear. Victory pose or in action, intense determination.`,
  },
  personal_trainer: {
    id: 'personal_trainer',
    label: 'Personal Trainer',
    icon: 'fitness_center',
    category: 'Sports & Fitness',
    scene: `Depict this person as a Personal Trainer in a modern gym, wearing athletic wear. Demonstrating an exercise or motivating, energetic and powerful.`,
  },
  yoga_instructor: {
    id: 'yoga_instructor',
    label: 'Yoga Instructor',
    icon: 'self_improvement',
    category: 'Sports & Fitness',
    scene: `Depict this person as a Yoga Instructor in a serene setting with soft natural light. In a graceful yoga pose, peaceful and centered.`,
  },

  // ═══════════════════════════════════════════
  // Science
  // ═══════════════════════════════════════════
  scientist: {
    id: 'scientist',
    label: 'Scientist',
    icon: 'science',
    category: 'Science',
    scene: `Depict this person as a Scientist in a laboratory, wearing a lab coat with safety goggles. Examining a test tube, brilliant and curious expression.`,
  },
  astronaut: {
    id: 'astronaut',
    label: 'Astronaut',
    icon: 'rocket_launch',
    category: 'Science',
    scene: `Depict this person as an Astronaut with Earth or stars in the background, wearing a spacesuit with helmet off. Awe-inspiring heroic pose.`,
  },
};

/** Identity-drift rejection — included in ALL negative prompts */
const IDENTITY_NEGATIVE = 'different person, altered face, wrong gender, gender swap, different skin tone, different hair, face swap, identity change';

const ART_STYLE_DEFINITIONS: Record<ArtStyle, ArtStyleDefinition> = {
  cartoon: {
    id: 'cartoon',
    label: 'Cartoon',
    icon: 'brush',
    rendering: `Style: fun cartoon caricature with bold outlines, slightly exaggerated features, vibrant colors, and playful energy. Think premium cartoon portrait commission — clean, polished, with personality. This MUST be a cartoon illustration, NOT a photograph or realistic image.

Output: square 1:1 profile picture, centered composition, clean background that complements the scene.`,
    negativePrompt: `photograph, photorealistic, ${IDENTITY_NEGATIVE}`,
  },
  caricature: {
    id: 'caricature',
    label: 'Caricature',
    icon: 'sentiment_very_satisfied',
    rendering: `Style: classic editorial caricature with deliberately exaggerated distinctive features — amplify the most recognizable aspects of the person's face (prominent nose, jawline, ears, smile, etc.) in a humorous, flattering way. Bold confident ink lines, expressive shading, and a lively hand-drawn editorial illustration feel. Think professional theme-park caricature artist or political cartoon portrait — skilled exaggeration that is instantly recognizable as the person while being playful and fun. This MUST be an illustrated caricature, NOT a photograph or realistic image.

Output: square 1:1 profile picture, centered composition, simple clean background.`,
    negativePrompt: `photograph, photorealistic, flat cartoon, anime, ${IDENTITY_NEGATIVE}`,
  },
  anime: {
    id: 'anime',
    label: 'Anime',
    icon: 'auto_awesome',
    rendering: `Style: Japanese anime-style portrait rendered with clean sharp linework, cel-shading, and vivid saturated colors. Apply anime rendering (smooth skin shading, sharp hair highlights, vibrant color palette) while keeping the person's ACTUAL facial proportions, eye size, and features accurate. Think premium anime portrait commission — polished, recognizable, not generic. This MUST be an anime illustration, NOT a photograph or realistic image.

Output: square 1:1 profile picture, centered composition, anime-style background.`,
    negativePrompt: `photograph, photorealistic, 3D render, chibi, ${IDENTITY_NEGATIVE}`,
  },
  comic: {
    id: 'comic',
    label: 'Comic Book',
    icon: 'menu_book',
    rendering: `Style: bold comic book illustration with thick ink outlines, dramatic cel-shading, halftone dot patterns, and rich saturated colors. Superhero comic aesthetic — dynamic and punchy. Keep the person's ACTUAL facial proportions and features accurate while applying the comic rendering technique (bold lines, flat color fills, dramatic shadows). Think premium comic book cover portrait. This MUST be a comic book illustration, NOT a photograph or realistic image.

Output: square 1:1 profile picture, centered composition, dynamic comic-style background.`,
    negativePrompt: `photograph, photorealistic, pastel colors, ${IDENTITY_NEGATIVE}`,
  },
  pixar: {
    id: 'pixar',
    label: 'Pixar 3D',
    icon: 'movie',
    rendering: `Style: 3D animated character in Disney/Pixar rendering style with smooth skin texture, warm cinematic lighting, and subsurface scattering. Apply the Pixar RENDERING (soft 3D shading, rim lighting, depth of field) while keeping the person's ACTUAL facial proportions, eye size, nose shape, and features recognizable. Think premium Pixar-style portrait — polished, charming, clearly them. This MUST be a 3D animated character, NOT a photograph or realistic image, NOT 2D flat illustration.

Output: square 1:1 profile picture, centered composition, cinematic depth of field background.`,
    negativePrompt: `photograph, photorealistic, 2D flat illustration, ${IDENTITY_NEGATIVE}`,
  },
  watercolor: {
    id: 'watercolor',
    label: 'Watercolor',
    icon: 'palette',
    rendering: `Style: elegant watercolor portrait with soft washes of color, visible artistic brush strokes, paper texture bleeding through, and gentle paint drips at edges. Apply the watercolor MEDIUM (soft color blending, wet edges, paper grain) while keeping the person's ACTUAL facial proportions and features accurate and recognizable. Think premium hand-painted portrait commission. This MUST be a watercolor painting, NOT a photograph or digital image.

Output: square 1:1 profile picture, centered composition, watercolor wash background.`,
    negativePrompt: `photograph, photorealistic, digital, sharp edges, ${IDENTITY_NEGATIVE}`,
  },
};

/** All valid role IDs — used for zod validation */
export const ALL_ROLE_IDS = Object.keys(ROLE_DEFINITIONS) as CaricatureRole[];

/**
 * Get all role definitions for display.
 */
export function getAllRoles(): (RoleDefinition & { locked: boolean })[] {
  return Object.values(ROLE_DEFINITIONS).map((r) => ({
    ...r,
    locked: false,
  }));
}

/**
 * Get all art style definitions for display.
 */
export function getAllArtStyles(): (Omit<ArtStyleDefinition, 'rendering' | 'negativePrompt'> & { locked: boolean })[] {
  return Object.values(ART_STYLE_DEFINITIONS).map((s) => ({
    id: s.id,
    label: s.label,
    icon: s.icon,
    locked: false,
  }));
}

/** Backward compat: returns roles as "styles" */
export function getAvailableStyles(_tier: 'free' | 'pro' = 'free'): RoleDefinition[] {
  return Object.values(ROLE_DEFINITIONS);
}

/** Backward compat */
export function getAllStyles(): (RoleDefinition & { locked: boolean })[] {
  return getAllRoles();
}

/**
 * Build the prompt for a given model tier.
 *
 * - **pro**: Full detailed prompt — the model has strong prompt adherence so
 *   we can include rich scene + style + identity instructions.
 * - **dev**: Shorter, punchier prompt — the dev model drifts with long text,
 *   so we front-load identity locking and keep it concise.
 *
 * Together AI supports `negative_prompt` but NOT `guidance_scale`.
 */
function buildPrompt(role: CaricatureRole, artStyle: ArtStyle, model: CaricatureModel): { prompt: string; negativePrompt: string } {
  const roleDef = ROLE_DEFINITIONS[role];
  const styleDef = ART_STYLE_DEFINITIONS[artStyle];
  if (!roleDef) throw new Error(`Unknown role: ${role}`);
  if (!styleDef) throw new Error(`Unknown art style: ${artStyle}`);

  // NOTE: Dev-specific short prompt commented out — using full pro prompt for both tiers.
  // Uncomment this block to restore the shorter dev prompt if results are worse.
  // if (model === 'dev') {
  //   // Dev model: shorter prompt with identity anchored to "the person in this uploaded photo"
  //   const shortScene = roleDef.scene.replace(
  //     /^Depict this person as/,
  //     'Transform the person in this uploaded photo into',
  //   );
  //   const prompt = [
  //     'IMPORTANT: Keep the EXACT same person from the uploaded photo — same face, same gender, same skin tone, same hair. Do NOT change who they are.',
  //     '',
  //     shortScene,
  //     '',
  //     styleDef.rendering,
  //   ].join('\n');
  //   return { prompt, negativePrompt: styleDef.negativePrompt };
  // }

  // Full detailed prompt — used for BOTH dev and pro tiers
  const genderAnchor = 'Keeping this person\'s exact gender, face, and appearance from the uploaded photo,';
  const anchoredScene = roleDef.scene.replace(/^Depict this person as/, `${genderAnchor} depict them as`);

  const IDENTITY_REMINDER = 'REMINDER: The person\'s gender, face, and all facial features MUST be identical to the uploaded photo. A female face stays female. A male face stays male. No exceptions.';
  const prompt = `${IDENTITY_INSTRUCTION}\n\n${anchoredScene}\n\n${styleDef.rendering}\n\n${IDENTITY_REMINDER}`;
  return { prompt, negativePrompt: styleDef.negativePrompt };
}

/** Randomized text style options per art style — keeps each generation fresh */
const TEXT_STYLES: Record<ArtStyle, string[]> = {
  cartoon: [
    'bold white letters with a black outline',
    'playful yellow bubble letters with a dark shadow',
    'large neon green letters with a thick black outline',
    'bold red and white retro-style letters',
    'chunky orange block letters with a dark drop shadow',
    'bright cyan letters in a fun rounded font',
  ],
  caricature: [
    'bold white letters with a dark shadow',
    'elegant gold serif letters',
    'bold black letters on a white ribbon banner',
    'stylish silver metallic letters with a subtle shadow',
    'classic white italic serif letters with a dark outline',
    'bold cream-colored vintage-style letters',
  ],
  anime: [
    'bold white letters with a colorful glow',
    'neon pink anime-style letters with a dark outline',
    'bold cyan letters with a glowing blue outline',
    'dramatic white letters with a red glow effect',
    'bright yellow letters with a purple outline in anime style',
    'bold white letters with a vibrant gradient outline',
  ],
  comic: [
    'bold yellow comic-book letters with a black outline',
    'dramatic white impact-style letters with a red shadow',
    'bold orange letters in a punchy comic style with action lines',
    'large white letters with a bold black outline',
    'bright green comic-style letters with a dark outline and halftone dots',
    'bold red and yellow superhero-style letters',
  ],
  pixar: [
    'clean bold white 3D letters with a soft shadow',
    'elegant gold 3D metallic letters',
    'bold white rounded letters with a subtle warm glow',
    'clean silver 3D letters with soft lighting',
    'playful teal 3D letters with a gentle shadow',
    'bold white letters with a cinematic depth effect',
  ],
  watercolor: [
    'elegant gold script letters',
    'soft white calligraphy letters with a delicate shadow',
    'dark ink brush-style letters',
    'elegant navy blue serif letters',
    'warm brown hand-lettered style text',
    'soft black elegant cursive letters',
  ],
};

function pickRandom(arr: string[]): string {
  return arr[Math.floor(Math.random() * arr.length)]!;
}

/**
 * Build a randomized text instruction that matches the art style.
 * Position is always at the bottom for accessibility.
 */
function buildTextInstruction(text: string, artStyle: ArtStyle): string {
  const style = pickRandom(TEXT_STYLES[artStyle] ?? TEXT_STYLES.cartoon);
  return `Add text saying "${text}" at the bottom of the image in ${style}, clearly readable. Ensure text does not overlap the face.`;
}

/**
 * Generate a caricature from a profile photo using Together AI FLUX.1 Kontext.
 * Text is rendered by appending a text instruction to the prompt — Kontext
 * handles typography natively in a single pass.
 */
export async function generateCaricature(
  imageUrl: string,
  role: CaricatureRole,
  artStyle: ArtStyle = 'cartoon',
  model: CaricatureModel = 'dev',
  count: number = 2,
  overlayText?: string,
): Promise<Buffer[]> {
  const apiKey = process.env.TOGETHER_API_KEY;
  if (!apiKey) {
    throw new Error('Together AI API key is not configured');
  }

  const { prompt: basePrompt, negativePrompt } = buildPrompt(role, artStyle, model);

  // Append text instruction if provided (single-pass — Kontext renders text natively)
  let prompt = basePrompt;
  if (overlayText) {
    prompt += `\n\n${buildTextInstruction(overlayText, artStyle)}`;
  }

  const steps = model === 'pro' ? 50 : 35;
  const size = model === 'pro' ? 1440 : 1152;
  logger.info({ role, artStyle, model, togetherModel: MODEL_MAP[model], steps, size, count, overlayText, promptLength: prompt.length }, 'Generating caricature');

  const response = await fetch('https://api.together.xyz/v1/images/generations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL_MAP[model],
      prompt,
      negative_prompt: negativePrompt,
      image_url: imageUrl,
      width: size,
      height: size,
      steps,
      n: count,
      response_format: 'b64_json',
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    logger.error({ status: response.status, errorText }, 'Together AI image generation failed');
    throw new Error(`Image generation failed (${response.status}): ${errorText}`);
  }

  const result = await response.json() as {
    data?: Array<{ b64_json?: string }>;
  };

  const images = (result.data ?? [])
    .map((d) => d.b64_json)
    .filter((b): b is string => !!b)
    .map((b64) => Buffer.from(b64, 'base64'));

  if (images.length === 0) {
    throw new Error('No image data returned from Together AI');
  }

  return images;
}
