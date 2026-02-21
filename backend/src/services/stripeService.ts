import Stripe from 'stripe';
import { ENV } from '../config/env';

let stripeInstance: Stripe | null = null;

function getStripe(): Stripe {
  if (!stripeInstance) {
    if (!ENV.stripeSecretKey) {
      throw new Error('STRIPE_SECRET_KEY is not configured');
    }
    stripeInstance = new Stripe(ENV.stripeSecretKey);
  }
  return stripeInstance;
}

export async function createCustomer(
  orgName: string,
  email: string,
  managerId: string,
): Promise<Stripe.Customer> {
  const stripe = getStripe();
  return stripe.customers.create({
    name: orgName,
    email,
    metadata: { managerId, source: 'flowshift_org' },
  });
}

export async function createCheckoutSession(
  customerId: string,
  lineItems: Array<{ price: string; quantity: number }>,
  orgId: string,
  successUrl: string,
  cancelUrl: string,
): Promise<Stripe.Checkout.Session> {
  const stripe = getStripe();
  return stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',
    line_items: lineItems,
    success_url: successUrl,
    cancel_url: cancelUrl,
    metadata: { orgId },
    subscription_data: { metadata: { orgId } },
  });
}

/**
 * Update the quantity of a specific line item on a subscription.
 * Finds the item by matching the given price ID.
 */
export async function updateSubscriptionItemQuantity(
  subscriptionId: string,
  priceId: string,
  quantity: number,
): Promise<Stripe.Subscription> {
  const stripe = getStripe();
  const sub = await stripe.subscriptions.retrieve(subscriptionId);

  const item = sub.items.data.find((i) => i.price.id === priceId);
  if (!item) throw new Error(`No subscription item found for price ${priceId}`);

  return stripe.subscriptions.update(subscriptionId, {
    items: [{ id: item.id, quantity }],
    proration_behavior: 'create_prorations',
  });
}

export async function createPortalSession(
  customerId: string,
  returnUrl: string,
): Promise<Stripe.BillingPortal.Session> {
  const stripe = getStripe();
  return stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl,
  });
}

export function constructWebhookEvent(
  payload: Buffer,
  sig: string,
): Stripe.Event {
  const stripe = getStripe();
  if (!ENV.stripeWebhookSecret) {
    throw new Error('STRIPE_WEBHOOK_SECRET is not configured');
  }
  return stripe.webhooks.constructEvent(payload, sig, ENV.stripeWebhookSecret);
}
