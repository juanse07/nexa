"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const dotenv_1 = __importDefault(require("dotenv"));
const user_js_1 = require("../src/models/user.js");
// Load environment variables
dotenv_1.default.config();
/**
 * Reset AI message limits for all staff users
 * Sets ai_messages_used_this_month to 0 for all users
 */
async function resetAIMessageLimits() {
    try {
        // Connect to MongoDB
        const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/test';
        console.log('Connecting to MongoDB...');
        await mongoose_1.default.connect(mongoUri);
        console.log('✅ Connected to MongoDB');
        // Reset message count for all users
        const result = await user_js_1.UserModel.updateMany({}, // All users
        {
            $set: {
                ai_messages_used_this_month: 0,
            }
        });
        console.log(`✅ Reset AI message limits for ${result.modifiedCount} users`);
        console.log(`   Total users found: ${result.matchedCount}`);
        // Optionally, also reset the reset date to next month
        const now = new Date();
        const nextMonth = new Date(now);
        nextMonth.setMonth(nextMonth.getMonth() + 1);
        nextMonth.setDate(1);
        nextMonth.setHours(0, 0, 0, 0);
        const dateResult = await user_js_1.UserModel.updateMany({}, {
            $set: {
                ai_messages_reset_date: nextMonth,
            }
        });
        console.log(`✅ Set reset date to ${nextMonth.toISOString()} for ${dateResult.modifiedCount} users`);
        // Show some stats
        const freeUsers = await user_js_1.UserModel.countDocuments({ subscription_tier: 'free' });
        const proUsers = await user_js_1.UserModel.countDocuments({ subscription_tier: 'pro' });
        const totalUsers = await user_js_1.UserModel.countDocuments({});
        console.log('\n📊 User Statistics:');
        console.log(`   Total users: ${totalUsers}`);
        console.log(`   Free tier: ${freeUsers}`);
        console.log(`   Pro tier: ${proUsers}`);
        console.log(`   No tier set: ${totalUsers - freeUsers - proUsers}`);
    }
    catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
    finally {
        await mongoose_1.default.disconnect();
        console.log('\n✅ Disconnected from MongoDB');
        process.exit(0);
    }
}
// Run the script
resetAIMessageLimits();
//# sourceMappingURL=reset-ai-message-limits.js.map