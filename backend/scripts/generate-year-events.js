"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
// Denver Metro venues
const venues = [
    { name: 'The Curtis Hotel', address: '1405 Curtis St, Denver, CO 80202' },
    { name: 'Union Station', address: '1701 Wynkoop St, Denver, CO 80202' },
    { name: 'Denver Botanic Gardens', address: '1007 York St, Denver, CO 80206' },
    { name: 'Mile High Station', address: '2027 W Colfax Ave, Denver, CO 80204' },
    { name: 'The Brown Palace Hotel', address: '321 17th St, Denver, CO 80202' },
    { name: 'Halcyon Hotel', address: '245 Columbine St, Denver, CO 80206' },
    { name: 'The Crawford Hotel', address: '1701 Wynkoop St, Denver, CO 80202' },
    { name: 'ViewHouse Ballpark', address: '2015 Market St, Denver, CO 80202' },
    { name: 'Four Seasons Denver', address: '1111 14th St, Denver, CO 80202' },
    { name: 'Magnolia Hotel', address: '818 17th St, Denver, CO 80202' },
    { name: 'The Grand Hyatt', address: '1750 Welton St, Denver, CO 80202' },
    { name: 'Denver Pavilions', address: '500 16th St, Denver, CO 80202' },
    { name: 'Bellco Theatre', address: '1100 14th St, Denver, CO 80202' },
    { name: 'City Park Golf Course', address: '2500 York St, Denver, CO 80205' },
    { name: 'Denver Museum of Nature & Science', address: '2001 Colorado Blvd, Denver, CO 80205' },
];
// Event types and client names
const eventTypes = [
    { type: 'Wedding Reception', clients: ['Smith-Johnson Wedding', 'Garcia-Martinez Wedding', 'Davis-Wilson Wedding', 'Brown-Taylor Wedding'] },
    { type: 'Corporate Gala', clients: ['TechCorp', 'Pinnacle Industries', 'Summit Solutions', 'Horizon Enterprises'] },
    { type: 'Holiday Party', clients: ['Denver Tech Meetup', 'Colorado Business Network', 'Mile High Professionals'] },
    { type: 'Fundraiser', clients: ['Denver Arts Foundation', 'Colorado Wildlife Fund', 'Children\'s Hospital Gala'] },
    { type: 'Conference Banquet', clients: ['Rocky Mountain Summit', 'Colorado Innovation Forum', 'Western States Conference'] },
    { type: 'Birthday Celebration', clients: ['Anderson 50th', 'Thompson Milestone', 'Roberts Celebration'] },
    { type: 'Networking Event', clients: ['Denver Chamber of Commerce', 'Young Professionals Network', 'Business Leaders Alliance'] },
    { type: 'Awards Ceremony', clients: ['Denver Excellence Awards', 'Colorado Business Awards', 'Innovation Recognition Gala'] },
];
// Uniform requirements
const uniforms = [
    'Black pants, white button-down shirt, black bow tie',
    'All black attire (black shirt, black pants)',
    'Business casual - black pants, company polo provided',
    'Cocktail attire - black dress pants/skirt, white dress shirt',
    'Black slacks, black vest, white shirt (vest provided on-site)',
];
function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}
function randomElement(arr) {
    return arr[randomInt(0, arr.length - 1)];
}
function generateEventDate(year, month) {
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const day = randomInt(1, daysInMonth);
    return new Date(year, month, day);
}
function generateEventTime() {
    // Most events are evening events
    const startHour = randomInt(16, 19); // 4 PM to 7 PM starts
    const duration = randomInt(4, 6); // 4-6 hour events
    const endHour = (startHour + duration) % 24;
    return {
        start: `${startHour.toString().padStart(2, '0')}:00`,
        end: `${endHour.toString().padStart(2, '0')}:00`,
    };
}
async function main() {
    const MONGO_URI = process.env.MONGO_URI;
    if (!MONGO_URI) {
        console.error('❌ MONGO_URI environment variable not found');
        process.exit(1);
    }
    console.log('🔌 Connecting to MongoDB...');
    await mongoose_1.default.connect(MONGO_URI);
    console.log('✅ Connected!\n');
    const db = mongoose_1.default.connection.db;
    const shiftsCollection = db.collection('shifts');
    const userKey = 'google:112603799149919213350';
    console.log(`📝 Generating events for user: ${userKey}\n`);
    // Clear existing test events
    const deleteResult = await shiftsCollection.deleteMany({
        $or: [
            { event_name: { $regex: '^Test Past Event' } },
            { shift_name: { $regex: '^Test Past Event' } }
        ]
    });
    console.log(`🗑️  Deleted ${deleteResult.deletedCount} old test events\n`);
    // Generate events for the past year
    const today = new Date();
    const currentYear = today.getFullYear();
    const currentMonth = today.getMonth();
    const events = [];
    let totalEvents = 0;
    console.log('🎲 Generating events for the past 12 months...\n');
    // Go back 12 months from current month
    for (let monthOffset = 1; monthOffset <= 12; monthOffset++) {
        const targetMonth = currentMonth - monthOffset;
        const year = targetMonth < 0 ? currentYear - 1 : currentYear;
        const month = targetMonth < 0 ? 12 + targetMonth : targetMonth;
        const eventsThisMonth = randomInt(16, 24);
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        console.log(`  ${monthNames[month]} ${year}: Generating ${eventsThisMonth} events`);
        for (let i = 0; i < eventsThisMonth; i++) {
            const eventDate = generateEventDate(year, month);
            const venue = randomElement(venues);
            const eventTypeData = randomElement(eventTypes);
            const client = randomElement(eventTypeData.clients);
            const times = generateEventTime();
            const role = randomElement(['Bartender', 'Server']);
            const hourlyRate = randomInt(20, 30);
            const shiftName = `${eventTypeData.type} - ${role}`;
            const eventName = `${client} ${eventTypeData.type}`;
            // Random additional roles needed
            const serverCount = randomInt(3, 8);
            const bartenderCount = randomInt(2, 4);
            const event = {
                event_name: eventName,
                shift_name: shiftName,
                client_name: client,
                venue_name: venue.name,
                venue_address: venue.address,
                city: 'Denver',
                state: 'Colorado',
                date: eventDate.toISOString().split('T')[0],
                start_time: times.start,
                end_time: times.end,
                roles: [
                    { role: 'Server', count: serverCount },
                    { role: 'Bartender', count: bartenderCount },
                ],
                pay_rate_info: `$${hourlyRate}/hour`,
                uniform: randomElement(uniforms),
                notes: Math.random() > 0.7 ? 'Please arrive 30 minutes early for briefing' : undefined,
                status: 'published',
                visibilityType: 'public',
                accepted_staff: [
                    {
                        userKey: userKey,
                        role: role,
                        response: 'accepted',
                        respondedAt: new Date(eventDate.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString(), // 1 week before event
                    },
                ],
                audience_user_keys: [],
                audience_team_ids: [],
                createdAt: new Date(eventDate.getTime() - 14 * 24 * 60 * 60 * 1000), // 2 weeks before event
                updatedAt: new Date(eventDate.getTime() - 7 * 24 * 60 * 60 * 1000),
            };
            events.push(event);
            totalEvents++;
        }
    }
    console.log(`\n📥 Inserting ${totalEvents} events into database...`);
    await shiftsCollection.insertMany(events);
    console.log(`✅ Successfully inserted ${totalEvents} events\n`);
    // Verify
    const totalInDb = await shiftsCollection.countDocuments();
    const pastEvents = await shiftsCollection.countDocuments({
        date: { $lt: today.toISOString().split('T')[0] },
    });
    const userEvents = await shiftsCollection.countDocuments({
        'accepted_staff.userKey': userKey,
    });
    console.log('📊 Database Summary:');
    console.log(`  Total events in shifts collection: ${totalInDb}`);
    console.log(`  Past events: ${pastEvents}`);
    console.log(`  Events for ${userKey}: ${userEvents}`);
    // Show breakdown by month
    console.log('\n📅 Events by Month (Past 12 months):');
    for (let monthOffset = 1; monthOffset <= 12; monthOffset++) {
        const targetMonth = currentMonth - monthOffset;
        const year = targetMonth < 0 ? currentYear - 1 : currentYear;
        const month = targetMonth < 0 ? 12 + targetMonth : targetMonth;
        const startDate = new Date(year, month, 1).toISOString().split('T')[0];
        const endDate = new Date(year, month + 1, 0).toISOString().split('T')[0];
        const count = await shiftsCollection.countDocuments({
            'accepted_staff.userKey': userKey,
            date: { $gte: startDate, $lte: endDate },
        });
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        console.log(`  ${monthNames[month]} ${year}: ${count} events`);
    }
    await mongoose_1.default.disconnect();
    console.log('\n✅ Done! Past events are ready to view in the staff app.');
}
main().catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
});
//# sourceMappingURL=generate-year-events.js.map