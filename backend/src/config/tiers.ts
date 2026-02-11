export type SubscriptionTier = 'free' | 'lite' | 'starter' | 'pro' | 'business' | 'enterprise';

export interface TierLimits {
  staffLimit: number | null;       // null = unlimited
  staffOverageAllowed: boolean;    // can go over staffLimit with per-staff charge
  eventsPerMonth: number | null;   // null = unlimited
  aiExtraction: boolean;
  aiMessages: number | null;       // null = unlimited
  aiContextEvents: number;
  analytics: boolean;
  customBranding: boolean;         // team logo
  managerSeats: number | null;     // null = unlimited
  bulkCreateLimit: number;         // max events per create_events_bulk call (0 = disabled)
  togetherAiPercent: number;       // 0–100, % of AI requests routed to Together AI (rest go to Groq)
}

/** Per-staff overage rate in USD/month */
export const STAFF_OVERAGE_RATE = 2;

export const TIER_LIMITS: Record<SubscriptionTier, TierLimits> = {
  free: {
    staffLimit: 5,
    staffOverageAllowed: false,
    eventsPerMonth: 3,
    aiExtraction: false,
    aiMessages: 20,
    aiContextEvents: 10,
    analytics: false,
    customBranding: false,
    managerSeats: 1,
    bulkCreateLimit: 0,
    togetherAiPercent: 90,
  },
  lite: {
    staffLimit: 10,
    staffOverageAllowed: true,
    eventsPerMonth: null,
    aiExtraction: true,
    aiMessages: 30,
    aiContextEvents: 15,
    analytics: false,
    customBranding: false,
    managerSeats: 1,
    bulkCreateLimit: 3,
    togetherAiPercent: 90,
  },
  starter: {
    staffLimit: 25,
    staffOverageAllowed: true,
    eventsPerMonth: null,
    aiExtraction: true,
    aiMessages: 50,
    aiContextEvents: 20,
    analytics: false,
    customBranding: true,
    managerSeats: 1,
    bulkCreateLimit: 5,
    togetherAiPercent: 20,
  },
  pro: {
    staffLimit: 60,
    staffOverageAllowed: true,
    eventsPerMonth: null,
    aiExtraction: true,
    aiMessages: null,
    aiContextEvents: 50,
    analytics: true,
    customBranding: true,
    managerSeats: 2,
    bulkCreateLimit: 15,
    togetherAiPercent: 20,
  },
  business: {
    staffLimit: 150,
    staffOverageAllowed: true,
    eventsPerMonth: null,
    aiExtraction: true,
    aiMessages: null,
    aiContextEvents: 50,
    analytics: true,
    customBranding: true,
    managerSeats: 10,
    bulkCreateLimit: 30,
    togetherAiPercent: 20,
  },
  enterprise: {
    staffLimit: null,
    staffOverageAllowed: false,
    eventsPerMonth: null,
    aiExtraction: true,
    aiMessages: null,
    aiContextEvents: 50,
    analytics: true,
    customBranding: true,
    managerSeats: null,
    bulkCreateLimit: 30,
    togetherAiPercent: 20,
  },
};

export function getTierLimits(tier: SubscriptionTier): TierLimits {
  return TIER_LIMITS[tier] || TIER_LIMITS.free;
}

/** Map Qonversion product IDs to subscription tiers */
export const PRODUCT_TO_TIER: Record<string, SubscriptionTier> = {
  flowshift_lite_monthly: 'lite',
  flowshift_lite_yearly: 'lite',
  flowshift_starter_monthly: 'starter',
  flowshift_starter_yearly: 'starter',
  flowshift_pro_monthly: 'pro',
  flowshift_pro_yearly: 'pro',
  flowshift_business_monthly: 'business',
  flowshift_business_yearly: 'business',
};
