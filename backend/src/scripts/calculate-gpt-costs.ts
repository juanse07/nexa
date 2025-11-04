/**
 * GPT API Cost Calculator
 * Calculates annual costs based on projected usage patterns
 *
 * Note: GPT-5 pricing not yet available - using GPT-4o and GPT-4o-mini as reference
 */

interface UsageProjection {
  // Database volumes (annual)
  eventsPerYear: number;
  totalUsers: number;
  totalManagers: number;
  totalClients: number;
  totalTeams: number;
  totalRoles: number;

  // Query patterns
  queriesPerUserPerDay: number;

  // Token averages from database analysis
  avgTokensPerEvent: number;
  avgTokensPerUser: number;
  avgTokensPerManager: number;
  avgTokensPerClient: number;
  avgTokensPerTeam: number;
  avgTokensPerRole: number;
  avgTokensPerConversation: number;
  avgTokensPerMessage: number;
}

interface ModelPricing {
  name: string;
  inputCostPer1M: number;  // USD per 1M input tokens
  outputCostPer1M: number; // USD per 1M output tokens
}

interface CostBreakdown {
  modelName: string;
  dailyQueries: number;
  annualQueries: number;
  avgInputTokensPerQuery: number;
  avgOutputTokensPerQuery: number;
  totalInputTokensPerYear: number;
  totalOutputTokensPerYear: number;
  inputCostPerYear: number;
  outputCostPerYear: number;
  totalCostPerYear: number;
  costPerQuery: number;
  costPerUser: number;
}

// Current OpenAI pricing (as of January 2025)
const MODELS: ModelPricing[] = [
  {
    name: 'GPT-4o',
    inputCostPer1M: 2.50,   // $2.50 per 1M input tokens
    outputCostPer1M: 10.00  // $10.00 per 1M output tokens
  },
  {
    name: 'GPT-4o-mini',
    inputCostPer1M: 0.150,  // $0.15 per 1M input tokens
    outputCostPer1M: 0.600  // $0.60 per 1M output tokens
  },
  {
    name: 'GPT-3.5-turbo',
    inputCostPer1M: 0.50,   // $0.50 per 1M input tokens
    outputCostPer1M: 1.50   // $1.50 per 1M output tokens
  }
];

// Placeholder pricing for GPT-5 (adjust when released)
const GPT5_MODELS: ModelPricing[] = [
  {
    name: 'GPT-5 (estimated)',
    inputCostPer1M: 5.00,   // Estimated - likely higher than GPT-4o
    outputCostPer1M: 15.00  // Estimated
  },
  {
    name: 'GPT-5-mini (estimated)',
    inputCostPer1M: 0.30,   // Estimated - likely 2x GPT-4o-mini
    outputCostPer1M: 1.20   // Estimated
  }
];

/**
 * Calculate cost breakdown for a specific model
 */
function calculateCosts(
  usage: UsageProjection,
  model: ModelPricing,
  avgInputTokens: number,
  avgOutputTokens: number
): CostBreakdown {
  const dailyQueries = usage.totalUsers * usage.queriesPerUserPerDay;
  const annualQueries = dailyQueries * 365;

  const totalInputTokensPerYear = annualQueries * avgInputTokens;
  const totalOutputTokensPerYear = annualQueries * avgOutputTokens;

  const inputCostPerYear = (totalInputTokensPerYear / 1_000_000) * model.inputCostPer1M;
  const outputCostPerYear = (totalOutputTokensPerYear / 1_000_000) * model.outputCostPer1M;
  const totalCostPerYear = inputCostPerYear + outputCostPerYear;

  return {
    modelName: model.name,
    dailyQueries,
    annualQueries,
    avgInputTokensPerQuery: avgInputTokens,
    avgOutputTokensPerQuery: avgOutputTokens,
    totalInputTokensPerYear,
    totalOutputTokensPerYear,
    inputCostPerYear,
    outputCostPerYear,
    totalCostPerYear,
    costPerQuery: totalCostPerYear / annualQueries,
    costPerUser: totalCostPerYear / usage.totalUsers
  };
}

/**
 * Format number as USD currency
 */
function formatUSD(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(amount);
}

/**
 * Format large numbers with commas
 */
function formatNumber(num: number): string {
  return new Intl.NumberFormat('en-US').format(Math.round(num));
}

/**
 * Main cost analysis
 */
function analyzeGPTCosts() {
  // Your projected usage
  const usage: UsageProjection = {
    // Annual volumes
    eventsPerYear: 250,
    totalUsers: 300,
    totalManagers: 1,
    totalClients: 20,
    totalTeams: 2,
    totalRoles: 15,

    // Query patterns
    queriesPerUserPerDay: 10,

    // Token averages from database analysis (using GPT token counts)
    avgTokensPerEvent: 266,
    avgTokensPerUser: 350,
    avgTokensPerManager: 637,
    avgTokensPerClient: 43,
    avgTokensPerTeam: 50,
    avgTokensPerRole: 43,
    avgTokensPerConversation: 85,
    avgTokensPerMessage: 104
  };

  console.log('\n' + '='.repeat(100));
  console.log('💰 GPT API COST ANALYSIS');
  console.log('='.repeat(100) + '\n');

  // Usage summary
  console.log('📊 USAGE PROJECTION:\n');
  console.log(`   Users:                    ${usage.totalUsers.toLocaleString()}`);
  console.log(`   Queries per user per day: ${usage.queriesPerUserPerDay}`);
  console.log(`   Daily queries:            ${formatNumber(usage.totalUsers * usage.queriesPerUserPerDay)}`);
  console.log(`   Annual queries:           ${formatNumber(usage.totalUsers * usage.queriesPerUserPerDay * 365)}`);
  console.log(`   Events per year:          ${usage.eventsPerYear.toLocaleString()}\n`);

  // Context size estimation
  console.log('🔍 CONTEXT SIZE ESTIMATION:\n');

  // Typical query context includes:
  // - System prompt (~200 tokens)
  // - User profile (~350 tokens)
  // - Recent conversation history (~3 messages × 104 tokens = 312 tokens)
  // - Relevant event data (~2 events × 266 tokens = 532 tokens)
  // - Available roles/teams (~5 roles × 43 tokens = 215 tokens)
  const systemPromptTokens = 200;
  const userContextTokens = usage.avgTokensPerUser; // 350
  const conversationHistoryTokens = 3 * usage.avgTokensPerMessage; // 312
  const eventContextTokens = 2 * usage.avgTokensPerEvent; // 532
  const roleContextTokens = 5 * usage.avgTokensPerRole; // 215

  const avgInputTokensPerQuery =
    systemPromptTokens +
    userContextTokens +
    conversationHistoryTokens +
    eventContextTokens +
    roleContextTokens;

  console.log(`   System prompt:            ${systemPromptTokens} tokens`);
  console.log(`   User profile:             ${userContextTokens} tokens`);
  console.log(`   Conversation history:     ${conversationHistoryTokens} tokens (3 messages)`);
  console.log(`   Event context:            ${eventContextTokens} tokens (2 events)`);
  console.log(`   Role/team data:           ${roleContextTokens} tokens (5 roles)`);
  console.log(`   ${'─'.repeat(50)}`);
  console.log(`   TOTAL INPUT per query:    ${avgInputTokensPerQuery} tokens\n`);

  // Output estimation (GPT responses are typically 150-300 tokens for chat apps)
  const avgOutputTokensPerQuery = 200;
  console.log(`   Estimated OUTPUT per query: ${avgOutputTokensPerQuery} tokens\n`);

  // Calculate costs for each model
  console.log('='.repeat(100));
  console.log('💵 ANNUAL COST BREAKDOWN BY MODEL');
  console.log('='.repeat(100) + '\n');

  const allModels = [...MODELS, ...GPT5_MODELS];
  const results: CostBreakdown[] = [];

  for (const model of allModels) {
    const breakdown = calculateCosts(usage, model, avgInputTokensPerQuery, avgOutputTokensPerQuery);
    results.push(breakdown);

    console.log(`📱 ${breakdown.modelName}`);
    console.log(`   ${'-'.repeat(90)}`);
    console.log(`   Pricing:          ${formatUSD(model.inputCostPer1M)}/1M input  |  ${formatUSD(model.outputCostPer1M)}/1M output`);
    console.log(`   Annual queries:   ${formatNumber(breakdown.annualQueries)}`);
    console.log(`   Input tokens/yr:  ${formatNumber(breakdown.totalInputTokensPerYear)} (${formatNumber(breakdown.avgInputTokensPerQuery)} per query)`);
    console.log(`   Output tokens/yr: ${formatNumber(breakdown.totalOutputTokensPerYear)} (${formatNumber(breakdown.avgOutputTokensPerQuery)} per query)`);
    console.log(`   `);
    console.log(`   💰 Input cost:    ${formatUSD(breakdown.inputCostPerYear)}/year`);
    console.log(`   💰 Output cost:   ${formatUSD(breakdown.outputCostPerYear)}/year`);
    console.log(`   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`   🎯 TOTAL ANNUAL:  ${formatUSD(breakdown.totalCostPerYear)}`);
    console.log(`   `);
    console.log(`   Per query:        ${formatUSD(breakdown.costPerQuery)}`);
    console.log(`   Per user/year:    ${formatUSD(breakdown.costPerUser)}`);
    console.log('\n');
  }

  // Comparison table
  console.log('='.repeat(100));
  console.log('📊 COST COMPARISON SUMMARY');
  console.log('='.repeat(100) + '\n');

  console.log(`${'Model'.padEnd(25)} ${'Annual Cost'.padEnd(20)} ${'Per Query'.padEnd(15)} ${'Per User/Year'.padEnd(20)} ${'Savings vs GPT-4o'}`);
  console.log(`${'-'.repeat(25)} ${'-'.repeat(20)} ${'-'.repeat(15)} ${'-'.repeat(20)} ${'-'.repeat(20)}`);

  const gpt4oCost = results.find(r => r.modelName === 'GPT-4o')?.totalCostPerYear || 0;

  for (const result of results) {
    const savings = gpt4oCost - result.totalCostPerYear;
    const savingsPercent = ((savings / gpt4oCost) * 100).toFixed(1);
    const savingsText = savings > 0
      ? `${formatUSD(savings)} (${savingsPercent}%)`
      : 'Baseline';

    console.log(
      `${result.modelName.padEnd(25)} ` +
      `${formatUSD(result.totalCostPerYear).padEnd(20)} ` +
      `${formatUSD(result.costPerQuery).padEnd(15)} ` +
      `${formatUSD(result.costPerUser).padEnd(20)} ` +
      `${savingsText}`
    );
  }

  // Monthly breakdown
  console.log('\n' + '='.repeat(100));
  console.log('📅 MONTHLY COST BREAKDOWN');
  console.log('='.repeat(100) + '\n');

  console.log(`${'Model'.padEnd(25)} ${'Monthly'.padEnd(15)} ${'Weekly'.padEnd(15)} ${'Daily'.padEnd(15)}`);
  console.log(`${'-'.repeat(25)} ${'-'.repeat(15)} ${'-'.repeat(15)} ${'-'.repeat(15)}`);

  for (const result of results) {
    const monthly = result.totalCostPerYear / 12;
    const weekly = result.totalCostPerYear / 52;
    const daily = result.totalCostPerYear / 365;

    console.log(
      `${result.modelName.padEnd(25)} ` +
      `${formatUSD(monthly).padEnd(15)} ` +
      `${formatUSD(weekly).padEnd(15)} ` +
      `${formatUSD(daily)}`
    );
  }

  // Recommendations
  console.log('\n' + '='.repeat(100));
  console.log('💡 RECOMMENDATIONS');
  console.log('='.repeat(100) + '\n');

  const miniCost = results.find(r => r.modelName === 'GPT-4o-mini')?.totalCostPerYear || 0;
  const standardCost = results.find(r => r.modelName === 'GPT-4o')?.totalCostPerYear || 0;
  const savings = standardCost - miniCost;

  console.log(`1. 💵 Cost Savings: GPT-4o-mini costs ${formatUSD(miniCost)}/year vs ${formatUSD(standardCost)}/year for GPT-4o`);
  console.log(`   You save ${formatUSD(savings)}/year (${((savings/standardCost)*100).toFixed(1)}%) using GPT-4o-mini!\n`);

  console.log(`2. 🎯 Hybrid Approach: Consider using GPT-4o-mini for simple queries and GPT-4o for complex ones`);
  console.log(`   - 80% simple queries with mini: ${formatUSD(miniCost * 0.8 + standardCost * 0.2)}/year`);
  console.log(`   - 90% simple queries with mini: ${formatUSD(miniCost * 0.9 + standardCost * 0.1)}/year\n`);

  console.log(`3. 📉 Context Optimization: Reduce input tokens by 30% through smart caching`);
  const optimizedInputTokens = avgInputTokensPerQuery * 0.7;
  const gpt4oMiniModel = MODELS.find(m => m.name === 'GPT-4o-mini');
  if (gpt4oMiniModel) {
    const optimizedCost = calculateCosts(usage, gpt4oMiniModel, optimizedInputTokens, avgOutputTokensPerQuery);
    console.log(`   Optimized GPT-4o-mini cost: ${formatUSD(optimizedCost.totalCostPerYear)}/year (saves ${formatUSD(miniCost - optimizedCost.totalCostPerYear)})\n`);
  }

  console.log(`4. 🚀 Wait for GPT-5: If prices are as estimated, GPT-5-mini might offer better value`);
  console.log(`   Current estimate: ${formatUSD(results.find(r => r.modelName === 'GPT-5-mini (estimated)')?.totalCostPerYear || 0)}/year\n`);

  console.log('='.repeat(100) + '\n');
}

// Run the analysis
analyzeGPTCosts();
