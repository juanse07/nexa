import mongoose from 'mongoose';
import { ENV } from '../src/config/env';
import { EventModel } from '../src/models/event';

/**
 * Final Verification - Historical Jobs Ready for Testing
 * Confirms that past events are properly set up for juan.2007@gmail.com
 */

const USER_SUBJECT = '112603799149919213350';
const USER_EMAIL = 'juan.2007@gmail.com';

async function main(): Promise<void> {
  console.log('🔍 Final Verification of Historical Jobs Setup');
  console.log('===============================================');

  try {
    // Connect to database
    if (!ENV.mongoUri) {
      throw new Error('MONGO_URI environment variable is required');
    }

    const dbName = ENV.nodeEnv === 'production' ? 'nexa_prod' : 'nexa_test';
    let uri = ENV.mongoUri.trim();
    if (uri.endsWith('/')) {
      uri = uri.slice(0, -1);
    }

    await mongoose.connect(`${uri}/${dbName}`);
    console.log(`✅ Connected to database: ${dbName}`);

    // Get all events for the user
    const userEvents = await EventModel.find({
      'accepted_staff.userKey': USER_SUBJECT
    }).sort({ date: -1 });

    console.log(`\n📊 Total Events for ${USER_EMAIL}: ${userEvents.length}`);

    // Separate past and future events
    const now = new Date();
    const pastEvents = userEvents.filter(event => {
      const eventDate = new Date(event.date);
      return eventDate < now;
    });
    const futureEvents = userEvents.filter(event => {
      const eventDate = new Date(event.date);
      return eventDate >= now;
    });

    console.log(`📅 Past Events: ${pastEvents.length}`);
    console.log(`📅 Future Events: ${futureEvents.length}`);

    // Status breakdown for past events
    const pastStatusSummary = pastEvents.reduce((acc, event) => {
      acc[event.status] = (acc[event.status] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    console.log('\n📈 Past Events Status Breakdown:');
    Object.entries(pastStatusSummary).forEach(([status, count]) => {
      console.log(`  ${status}: ${count} events`);
    });

    // Calculate total earnings
    let totalEarnings = 0;
    let totalHours = 0;

    pastEvents.forEach(event => {
      const approvedHours = (event as any).approvedHours || 0;
      // Use a reasonable default rate for estimation
      const estimatedRate = 22; // Average hourly rate
      totalHours += approvedHours;
      totalEarnings += approvedHours * estimatedRate;
    });

    console.log('\n💰 Past Events Summary:');
    console.log(`  Total Hours: ${totalHours.toFixed(1)}`);
    console.log(`  Estimated Total Earnings: $${totalEarnings.toFixed(2)}`);

    // Monthly breakdown for the last 6 months
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const recentPastEvents = pastEvents.filter(event => {
      const eventDate = new Date(event.date);
      return eventDate >= sixMonthsAgo;
    });
    const monthlyBreakdown = recentPastEvents.reduce((acc, event) => {
      const eventDate = new Date(event.date);
      const monthKey = eventDate.toISOString().slice(0, 7); // YYYY-MM
      if (!acc[monthKey]) {
        acc[monthKey] = { events: 0, hours: 0 };
      }
      acc[monthKey].events++;
      acc[monthKey].hours += (event as any).approvedHours || 0;
      return acc;
    }, {} as Record<string, { events: number; hours: number }>);

    console.log('\n📅 Last 6 Months Activity:');
    Object.entries(monthlyBreakdown)
      .sort()
      .reverse()
      .forEach(([month, data]) => {
        console.log(`  ${month}: ${data.events} events, ${data.hours.toFixed(1)} hours`);
      });

    // Sample of recent past events
    console.log('\n🔍 Sample Recent Past Events:');
    const sampleEvents = pastEvents.slice(0, 5);

    for (const event of sampleEvents) {
      const eventDate = new Date(event.date);
      const approvedHours = (event as any).approvedHours || 0;
      const estimatedEarnings = approvedHours * 22; // Average rate
      console.log(`  ${eventDate.toISOString().split('T')[0]}: ${event.shift_name || 'Event'} - ${approvedHours}h (~$${estimatedEarnings.toFixed(2)})`);
    }

    // Verify events are ready for Past Events screen
    const readyForPastScreen = pastEvents.filter(event => {
      return (
        event.status === 'completed' &&
        event.accepted_staff &&
        event.accepted_staff.some(staff => staff.userKey === USER_SUBJECT)
      );
    });

    console.log('\n✅ Past Events Screen Readiness:');
    console.log(`  Ready to display: ${readyForPastScreen.length} events`);
    console.log(`  Expected in Past Events tab: ${readyForPastScreen.length} events`);

    if (readyForPastScreen.length > 0) {
      console.log('\n🎉 SUCCESS: Historical jobs are properly configured!');
      console.log('📱 The Past Events screen should now show all historical events for juan.2007@gmail.com');
      console.log('💸 Total estimated earnings from past work: $' + totalEarnings.toFixed(2));
    } else {
      console.log('\n❌ ISSUE: No events are ready for the Past Events screen');
    }

  } catch (error) {
    console.error('❌ Error during verification:', error);
    throw error;
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Database disconnected');
  }
}

if (require.main === module) {
  main();
}