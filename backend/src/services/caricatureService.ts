import pino from 'pino';

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

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
export type ArtStyle = 'cartoon' | 'anime' | 'comic' | 'pixar' | 'watercolor';

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

/** Identity preservation — appended to every prompt */
const IDENTITY_INSTRUCTION = `Using the uploaded image as the ONLY identity reference, preserve the person's face, facial structure, hairline, beard shape, skin tone, and expression so they remain clearly recognizable.`;

const ROLE_DEFINITIONS: Record<CaricatureRole, RoleDefinition> = {
  // ═══════════════════════════════════════════
  // Hospitality & Events
  // ═══════════════════════════════════════════
  bartender: {
    id: 'bartender',
    label: 'Bartender',
    icon: 'local_bar',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Bartender. Wearing a black vest over white shirt, sleeves rolled, bar apron. Behind a well-stocked bar, warm ambient lighting. Shaking a cocktail or presenting a drink with confidence.`,
  },
  server: {
    id: 'server',
    label: 'Server',
    icon: 'restaurant',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Server. Wearing a clean black shirt, neat apron. In a restaurant with warm lighting. Carrying a tray or presenting a dish with poise.`,
  },
  security: {
    id: 'security',
    label: 'Security',
    icon: 'security',
    category: 'Hospitality & Events',
    scene: `Depict this person as Security. Wearing a black fitted shirt, earpiece, sunglasses. At a venue entrance, moody lighting. Standing with a confident, solid stance.`,
  },
  dj: {
    id: 'dj',
    label: 'DJ',
    icon: 'headphones',
    category: 'Hospitality & Events',
    scene: `Depict this person as a DJ. Wearing a modern black outfit, premium headphones tilted on one ear. In a DJ booth with atmospheric lighting, turntables and mixer. Hands on the decks, feeling the music.`,
  },
  host: {
    id: 'host',
    label: 'Host',
    icon: 'emoji_people',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Host. Wearing smart casual outfit. At a venue entrance, warm lighting. Holding a tablet or guest list, warm smile.`,
  },
  coordinator: {
    id: 'coordinator',
    label: 'Coordinator',
    icon: 'event_note',
    category: 'Hospitality & Events',
    scene: `Depict this person as an Event Coordinator. Wearing a smart blazer, headset, tablet in hand. In an event venue with setup in progress. Directing with confidence.`,
  },
  chef: {
    id: 'chef',
    label: 'Chef',
    icon: 'soup_kitchen',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Chef. Wearing a white chef jacket. In a kitchen with stainless steel, gentle steam. Arms crossed confidently or plating a dish.`,
  },
  busser: {
    id: 'busser',
    label: 'Busser',
    icon: 'cleaning_services',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Busser. Wearing a clean black polo, neat apron. In a restaurant dining room. Efficiently working the floor, carrying items.`,
  },
  barback: {
    id: 'barback',
    label: 'Barback',
    icon: 'liquor',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Barback. Wearing a black shirt, bar apron. Behind the bar, bottles and glassware. Carrying bottles or ice, strong steady movements.`,
  },
  manager: {
    id: 'manager',
    label: 'Manager',
    icon: 'business_center',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Manager. Wearing smart business casual, blazer or button-up. In an event venue, staff and guests in the background. Holding a tablet, calm and in charge.`,
  },
  photographer: {
    id: 'photographer',
    label: 'Photographer',
    icon: 'camera_alt',
    category: 'Hospitality & Events',
    scene: `Depict this person as an Event Photographer. Wearing all-black outfit, camera strap. At an event scene, dramatic lighting. Holding a professional camera, ready to shoot.`,
  },
  valet: {
    id: 'valet',
    label: 'Valet',
    icon: 'directions_car',
    category: 'Hospitality & Events',
    scene: `Depict this person as a Valet. Wearing a vest and bow tie. At a venue entrance, nice car beside them, evening lighting. Standing with car keys in hand, sharp poise.`,
  },

  // ═══════════════════════════════════════════
  // Healthcare
  // ═══════════════════════════════════════════
  physician: {
    id: 'physician',
    label: 'Physician',
    icon: 'medical_services',
    category: 'Healthcare',
    scene: `Depict this person as a Physician. Wearing a white lab coat, stethoscope draped around neck. In a modern clinic or hospital hallway, clean bright lighting. Standing confidently with a clipboard, professional and caring demeanor.`,
  },
  nurse: {
    id: 'nurse',
    label: 'Nurse',
    icon: 'favorite',
    category: 'Healthcare',
    scene: `Depict this person as a Nurse. Wearing clean scrubs with a badge, stethoscope. In a hospital ward with soft lighting. Caring expression, holding a tablet or checking on a patient with warmth.`,
  },
  surgeon: {
    id: 'surgeon',
    label: 'Surgeon',
    icon: 'healing',
    category: 'Healthcare',
    scene: `Depict this person as a Surgeon. Wearing surgical scrubs, cap, mask pulled down around neck. In a modern operating room, dramatic overhead lights. Arms crossed confidently, gloves on, ready to operate.`,
  },
  dentist: {
    id: 'dentist',
    label: 'Dentist',
    icon: 'mood',
    category: 'Healthcare',
    scene: `Depict this person as a Dentist. Wearing a white coat, dental mirror in hand. In a modern dental office, bright clean lighting. Warm confident smile, professional setup around them.`,
  },
  veterinarian: {
    id: 'veterinarian',
    label: 'Veterinarian',
    icon: 'pets',
    category: 'Healthcare',
    scene: `Depict this person as a Veterinarian. Wearing a lab coat or scrubs, stethoscope. In an animal clinic, warm lighting. Gently holding or examining a cute dog or cat, compassionate expression.`,
  },
  paramedic: {
    id: 'paramedic',
    label: 'Paramedic',
    icon: 'local_hospital',
    category: 'Healthcare',
    scene: `Depict this person as a Paramedic. Wearing a navy EMT uniform with reflective strips, radio on shoulder. Near an ambulance with emergency lights. Determined, heroic stance, ready for action.`,
  },

  // ═══════════════════════════════════════════
  // Legal & Business
  // ═══════════════════════════════════════════
  lawyer: {
    id: 'lawyer',
    label: 'Lawyer',
    icon: 'gavel',
    category: 'Legal & Business',
    scene: `Depict this person as a Lawyer. Wearing a sharp tailored suit, confident power pose. In a grand courtroom or law office with bookshelves of legal books. Holding a leather briefcase or standing at a podium, commanding presence.`,
  },
  accountant: {
    id: 'accountant',
    label: 'Accountant',
    icon: 'calculate',
    category: 'Legal & Business',
    scene: `Depict this person as an Accountant. Wearing business professional attire, glasses optional. In a sleek modern office with monitors showing charts and spreadsheets. Confident expression, pen in hand or gesturing at financial data.`,
  },
  ceo: {
    id: 'ceo',
    label: 'CEO',
    icon: 'trending_up',
    category: 'Legal & Business',
    scene: `Depict this person as a CEO. Wearing an impeccable suit, standing in a corner office with floor-to-ceiling windows overlooking a city skyline. Power pose, arms crossed or hands on a executive desk. Emanating authority and vision.`,
  },
  realtor: {
    id: 'realtor',
    label: 'Realtor',
    icon: 'home',
    category: 'Legal & Business',
    scene: `Depict this person as a Realtor. Wearing smart business casual, holding house keys and a tablet. Standing in front of a beautiful luxury home with a "SOLD" sign. Warm, confident smile, golden hour lighting.`,
  },
  consultant: {
    id: 'consultant',
    label: 'Consultant',
    icon: 'assessment',
    category: 'Legal & Business',
    scene: `Depict this person as a Business Consultant. Wearing modern business attire, blazer with no tie. In a glass-walled conference room with a whiteboard full of strategy diagrams. Presenting confidently, gesturing at the board.`,
  },

  // ═══════════════════════════════════════════
  // Tech
  // ═══════════════════════════════════════════
  software_engineer: {
    id: 'software_engineer',
    label: 'Software Engineer',
    icon: 'code',
    category: 'Tech',
    scene: `Depict this person as a Software Engineer. Wearing a tech company hoodie or casual shirt. At a desk with multiple monitors showing code, futuristic ambient lighting. Focused expression, hands on keyboard, coffee nearby.`,
  },
  data_scientist: {
    id: 'data_scientist',
    label: 'Data Scientist',
    icon: 'insights',
    category: 'Tech',
    scene: `Depict this person as a Data Scientist. Wearing smart casual with glasses. In front of large screens with data visualizations, neural network diagrams, and 3D charts in neon colors. Thoughtful analytical expression.`,
  },
  ux_designer: {
    id: 'ux_designer',
    label: 'UX Designer',
    icon: 'design_services',
    category: 'Tech',
    scene: `Depict this person as a UX Designer. Wearing creative casual attire, stylish. At a workspace with a large tablet, colorful wireframes and UI mockups on screens. Holding a stylus, creative and focused expression.`,
  },

  // ═══════════════════════════════════════════
  // Trades & Construction
  // ═══════════════════════════════════════════
  construction_worker: {
    id: 'construction_worker',
    label: 'Construction',
    icon: 'construction',
    category: 'Trades & Construction',
    scene: `Depict this person as a Construction Worker. Wearing a hard hat, high-vis vest, work boots. At an active construction site with steel beams and cranes. Strong confident stance, holding blueprints or tools, tough and capable.`,
  },
  electrician: {
    id: 'electrician',
    label: 'Electrician',
    icon: 'electrical_services',
    category: 'Trades & Construction',
    scene: `Depict this person as an Electrician. Wearing a work uniform with tool belt full of specialized tools. Working on an electrical panel, sparks of light around wires. Skilled and focused expression, safety goggles on forehead.`,
  },
  plumber: {
    id: 'plumber',
    label: 'Plumber',
    icon: 'plumbing',
    category: 'Trades & Construction',
    scene: `Depict this person as a Plumber. Wearing work overalls with tool belt, wrench in hand. In a clean modern setting, working on polished copper pipes. Skilled and confident, professional setup.`,
  },
  mechanic: {
    id: 'mechanic',
    label: 'Mechanic',
    icon: 'build',
    category: 'Trades & Construction',
    scene: `Depict this person as a Mechanic. Wearing a work jumpsuit or dark tee, some grease marks. In a professional auto shop, tools organized, a sports car on a lift. Holding a wrench, confident knowing smile.`,
  },
  welder: {
    id: 'welder',
    label: 'Welder',
    icon: 'local_fire_department',
    category: 'Trades & Construction',
    scene: `Depict this person as a Welder. Wearing a leather apron, welding helmet flipped up on forehead. In a workshop with metal sparks flying, dramatic orange glow. Strong stance, holding a welding torch, intense and skilled.`,
  },
  carpenter: {
    id: 'carpenter',
    label: 'Carpenter',
    icon: 'carpenter',
    category: 'Trades & Construction',
    scene: `Depict this person as a Carpenter. Wearing a flannel shirt, tool belt with hammer and measuring tape. In a woodworking shop surrounded by beautiful wood projects. Sanding or assembling a piece, sawdust in the air, warm lighting.`,
  },
  architect: {
    id: 'architect',
    label: 'Architect',
    icon: 'architecture',
    category: 'Trades & Construction',
    scene: `Depict this person as an Architect. Wearing smart casual with a blazer, rolled sleeves. In a modern studio with architectural models and blueprints spread out. Examining a building model, visionary expression, natural light.`,
  },

  // ═══════════════════════════════════════════
  // Creative
  // ═══════════════════════════════════════════
  musician: {
    id: 'musician',
    label: 'Musician',
    icon: 'music_note',
    category: 'Creative',
    scene: `Depict this person as a Musician. Wearing a stylish stage outfit, leather jacket or band tee. On a stage with dramatic spotlights and a crowd silhouette. Playing a guitar or at a microphone, lost in the music, pure passion.`,
  },
  artist: {
    id: 'artist',
    label: 'Artist',
    icon: 'palette',
    category: 'Creative',
    scene: `Depict this person as an Artist. Wearing paint-splattered casual clothes, creative look. In a bright art studio with large colorful canvases. Holding a paintbrush, vibrant paint on palette, inspired expression.`,
  },
  filmmaker: {
    id: 'filmmaker',
    label: 'Filmmaker',
    icon: 'videocam',
    category: 'Creative',
    scene: `Depict this person as a Filmmaker. Wearing a director's casual outfit, possibly a cap. On a film set with cameras, lights, and crew. Sitting in a director's chair or looking through a viewfinder, creative vision.`,
  },
  writer: {
    id: 'writer',
    label: 'Writer',
    icon: 'edit',
    category: 'Creative',
    scene: `Depict this person as a Writer. Wearing comfortable intellectual attire, glasses optional. In a cozy study with bookshelves, warm lamp light, a typewriter or laptop. Deep in thought with a cup of coffee, surrounded by papers and books.`,
  },
  fashion_designer: {
    id: 'fashion_designer',
    label: 'Fashion Designer',
    icon: 'checkroom',
    category: 'Creative',
    scene: `Depict this person as a Fashion Designer. Wearing chic stylish clothing, measuring tape around neck. In a fashion studio with mannequins, fabric rolls, and sketches pinned to the wall. Draping fabric, artistic and confident.`,
  },

  // ═══════════════════════════════════════════
  // Emergency & Service
  // ═══════════════════════════════════════════
  firefighter: {
    id: 'firefighter',
    label: 'Firefighter',
    icon: 'local_fire_department',
    category: 'Emergency & Service',
    scene: `Depict this person as a Firefighter. Wearing full turnout gear, helmet in hand or on head. In front of a fire truck with emergency lights. Heroic stance, axe or hose, dramatic smoky background with warm orange glow.`,
  },
  police_officer: {
    id: 'police_officer',
    label: 'Police Officer',
    icon: 'local_police',
    category: 'Emergency & Service',
    scene: `Depict this person as a Police Officer. Wearing a sharp navy uniform with badge, duty belt. Standing next to a patrol car with lights, urban backdrop. Confident protective stance, serving and protecting.`,
  },
  pilot: {
    id: 'pilot',
    label: 'Pilot',
    icon: 'flight',
    category: 'Emergency & Service',
    scene: `Depict this person as a Pilot. Wearing a crisp white pilot uniform with captain stripes, aviator sunglasses. On an airport tarmac with a commercial jet behind them, sunset sky. Confident walk, carrying a flight case.`,
  },
  military: {
    id: 'military',
    label: 'Military',
    icon: 'military_tech',
    category: 'Emergency & Service',
    scene: `Depict this person as a Military Service Member. Wearing a decorated dress uniform with medals and insignia. Standing at attention with an American flag backdrop, dramatic lighting. Pride, honor, and strength in their posture.`,
  },

  // ═══════════════════════════════════════════
  // Education
  // ═══════════════════════════════════════════
  teacher: {
    id: 'teacher',
    label: 'Teacher',
    icon: 'school',
    category: 'Education',
    scene: `Depict this person as a Teacher. Wearing smart casual professional attire. In a bright colorful classroom with a chalkboard, books, and educational decor. Smiling warmly, holding a book or writing on the board, inspiring presence.`,
  },
  professor: {
    id: 'professor',
    label: 'Professor',
    icon: 'history_edu',
    category: 'Education',
    scene: `Depict this person as a University Professor. Wearing a tweed blazer with elbow patches, glasses. In a prestigious lecture hall or university library. At a podium or surrounded by books, intellectual and distinguished.`,
  },

  // ═══════════════════════════════════════════
  // Sports & Fitness
  // ═══════════════════════════════════════════
  athlete: {
    id: 'athlete',
    label: 'Athlete',
    icon: 'sports',
    category: 'Sports & Fitness',
    scene: `Depict this person as a Professional Athlete. Wearing athletic gear, jersey or performance wear. In a stadium with floodlights and crowd silhouette. Victory pose or in action, intense determination, sweat glistening, champion energy.`,
  },
  personal_trainer: {
    id: 'personal_trainer',
    label: 'Personal Trainer',
    icon: 'fitness_center',
    category: 'Sports & Fitness',
    scene: `Depict this person as a Personal Trainer. Wearing athletic wear, muscular or fit build. In a modern gym with weights and equipment. Demonstrating an exercise or motivating, energetic and powerful stance.`,
  },
  yoga_instructor: {
    id: 'yoga_instructor',
    label: 'Yoga Instructor',
    icon: 'self_improvement',
    category: 'Sports & Fitness',
    scene: `Depict this person as a Yoga Instructor. Wearing sleek yoga attire. In a serene outdoor setting or zen studio with soft natural light, plants. In a graceful yoga pose, peaceful and centered expression, calming atmosphere.`,
  },

  // ═══════════════════════════════════════════
  // Science
  // ═══════════════════════════════════════════
  scientist: {
    id: 'scientist',
    label: 'Scientist',
    icon: 'science',
    category: 'Science',
    scene: `Depict this person as a Scientist. Wearing a lab coat, safety goggles on forehead. In a cutting-edge laboratory with beakers, microscopes, and glowing experiments. Examining a test tube, brilliant and curious expression.`,
  },
  astronaut: {
    id: 'astronaut',
    label: 'Astronaut',
    icon: 'rocket_launch',
    category: 'Science',
    scene: `Depict this person as an Astronaut. Wearing a white NASA-style spacesuit, helmet off or visor up. In space or on a launchpad with Earth or stars in the background. Awe-inspiring pose, floating or standing heroically, cosmic adventure.`,
  },
};

const ART_STYLE_DEFINITIONS: Record<ArtStyle, ArtStyleDefinition> = {
  cartoon: {
    id: 'cartoon',
    label: 'Cartoon',
    icon: 'brush',
    rendering: `Style: fun cartoon caricature with bold outlines, slightly exaggerated features, vibrant colors, and playful energy. Think premium cartoon portrait commission — clean, polished, with personality. NOT a photograph.

Output: square 1:1 profile picture, centered composition, clean background that complements the scene.`,
    negativePrompt: 'photograph, photorealistic, realistic, DSLR, camera, raw photo, lens blur, film grain, stock photo',
  },
  anime: {
    id: 'anime',
    label: 'Anime',
    icon: 'auto_awesome',
    rendering: `Style: Japanese anime-style portrait rendered with clean sharp linework, cel-shading, and vivid saturated colors. Apply anime rendering (smooth skin shading, sharp hair highlights, vibrant color palette) while keeping the person's ACTUAL facial proportions, eye size, and features accurate. Think premium anime portrait commission — polished, recognizable, not generic. NOT a photograph, NOT western cartoon.

Output: square 1:1 profile picture, centered composition, anime-style background.`,
    negativePrompt: 'photograph, photorealistic, realistic, DSLR, camera, raw photo, western cartoon, 3D render, chibi, super deformed',
  },
  comic: {
    id: 'comic',
    label: 'Comic Book',
    icon: 'menu_book',
    rendering: `Style: bold comic book illustration with thick ink outlines, dramatic cel-shading, halftone dot patterns, and rich saturated colors. Superhero comic aesthetic — dynamic and punchy. Keep the person's ACTUAL facial proportions and features accurate while applying the comic rendering technique (bold lines, flat color fills, dramatic shadows). Think premium comic book cover portrait. NOT a photograph.

Output: square 1:1 profile picture, centered composition, dynamic comic-style background.`,
    negativePrompt: 'photograph, photorealistic, realistic, DSLR, camera, raw photo, soft lighting, pastel colors, distorted face',
  },
  pixar: {
    id: 'pixar',
    label: 'Pixar 3D',
    icon: 'movie',
    rendering: `Style: 3D animated character in Disney/Pixar rendering style with smooth skin texture, warm cinematic lighting, and subsurface scattering. Apply the Pixar RENDERING (soft 3D shading, rim lighting, depth of field) while keeping the person's ACTUAL facial proportions, eye size, nose shape, and features recognizable. Think premium Pixar-style portrait — polished, charming, clearly them. NOT a photograph, NOT 2D flat illustration.

Output: square 1:1 profile picture, centered composition, cinematic depth of field background.`,
    negativePrompt: 'photograph, photorealistic, realistic, DSLR, camera, raw photo, 2D, flat illustration, sketch, distorted proportions, oversized eyes',
  },
  watercolor: {
    id: 'watercolor',
    label: 'Watercolor',
    icon: 'palette',
    rendering: `Style: elegant watercolor portrait with soft washes of color, visible artistic brush strokes, paper texture bleeding through, and gentle paint drips at edges. Apply the watercolor MEDIUM (soft color blending, wet edges, paper grain) while keeping the person's ACTUAL facial proportions and features accurate and recognizable. Think premium hand-painted portrait commission. NOT a photograph, NOT digital sharp.

Output: square 1:1 profile picture, centered composition, watercolor wash background.`,
    negativePrompt: 'photograph, photorealistic, realistic, DSLR, camera, raw photo, digital, sharp edges, vector, flat color, distorted face',
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
 * Build the full prompt combining role scene + art style rendering + identity preservation.
 */
function buildPrompt(role: CaricatureRole, artStyle: ArtStyle): { prompt: string; negativePrompt: string } {
  const roleDef = ROLE_DEFINITIONS[role];
  const styleDef = ART_STYLE_DEFINITIONS[artStyle];
  if (!roleDef) throw new Error(`Unknown role: ${role}`);
  if (!styleDef) throw new Error(`Unknown art style: ${artStyle}`);

  const prompt = `${roleDef.scene}\n\n${styleDef.rendering}\n\n${IDENTITY_INSTRUCTION}`;
  return { prompt, negativePrompt: styleDef.negativePrompt };
}

/**
 * Generate a caricature from a profile photo using Together AI FLUX.1 Kontext.
 */
export async function generateCaricature(
  imageUrl: string,
  role: CaricatureRole,
  artStyle: ArtStyle = 'cartoon',
): Promise<Buffer> {
  const apiKey = process.env.TOGETHER_API_KEY;
  if (!apiKey) {
    throw new Error('Together AI API key is not configured');
  }

  const { prompt, negativePrompt } = buildPrompt(role, artStyle);

  logger.info({ role, artStyle, promptLength: prompt.length }, 'Generating caricature');

  const response = await fetch('https://api.together.xyz/v1/images/generations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'black-forest-labs/FLUX.1-kontext-dev',
      prompt,
      negative_prompt: negativePrompt,
      image_url: imageUrl,
      width: 1024,
      height: 1024,
      steps: 28,
      n: 1,
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

  const b64 = result.data?.[0]?.b64_json;
  if (!b64) {
    throw new Error('No image data returned from Together AI');
  }

  return Buffer.from(b64, 'base64');
}
