import mongoose from 'mongoose';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

/**
 * Token counting utilities
 * Using approximation methods based on character counts
 * More accurate tokenization would require @anthropic-ai/tokenizer and tiktoken packages
 */

interface TokenStats {
  collectionName: string;
  documentCount: number;
  avgClaudeTokens: number;
  avgGptTokens: number;
  avgCharacters: number;
  minTokens: number;
  maxTokens: number;
}

/**
 * Approximate Claude token count
 * Claude's tokenizer typically produces ~3.5-4 chars per token for English text
 */
function estimateClaudeTokens(text: string): number {
  const charCount = text.length;
  // More conservative estimate: 3.5 characters per token
  return Math.ceil(charCount / 3.5);
}

/**
 * Approximate GPT token count
 * GPT-3.5/GPT-4 typically produces ~4 chars per token for English text
 * Using tiktoken would be more accurate
 */
function estimateGptTokens(text: string): number {
  const charCount = text.length;
  // Standard approximation: 4 characters per token
  return Math.ceil(charCount / 4);
}

/**
 * Convert a document to a text representation for token counting
 */
function documentToText(doc: any): string {
  // Remove MongoDB internal fields
  const cleanDoc = { ...doc };
  delete cleanDoc._id;
  delete cleanDoc.__v;

  // Convert to JSON string for token counting
  return JSON.stringify(cleanDoc, null, 0);
}

/**
 * Analyze a single collection
 */
async function analyzeCollection(collectionName: string): Promise<TokenStats | null> {
  try {
    const db = mongoose.connection.db;
    if (!db) {
      throw new Error('Database connection not established');
    }

    const collection = db.collection(collectionName);

    // Get total document count
    const documentCount = await collection.countDocuments();

    if (documentCount === 0) {
      console.log(`⚠️  Collection '${collectionName}' is empty, skipping...`);
      return null;
    }

    // Sample documents (use all if less than 1000, otherwise sample 1000)
    const sampleSize = Math.min(documentCount, 1000);
    const documents = await collection.aggregate([
      { $sample: { size: sampleSize } }
    ]).toArray();

    let totalClaudeTokens = 0;
    let totalGptTokens = 0;
    let totalCharacters = 0;
    let minTokens = Infinity;
    let maxTokens = 0;

    for (const doc of documents) {
      const text = documentToText(doc);
      const charCount = text.length;
      const claudeTokens = estimateClaudeTokens(text);
      const gptTokens = estimateGptTokens(text);

      totalClaudeTokens += claudeTokens;
      totalGptTokens += gptTokens;
      totalCharacters += charCount;

      minTokens = Math.min(minTokens, claudeTokens);
      maxTokens = Math.max(maxTokens, claudeTokens);
    }

    return {
      collectionName,
      documentCount,
      avgClaudeTokens: Math.round(totalClaudeTokens / documents.length),
      avgGptTokens: Math.round(totalGptTokens / documents.length),
      avgCharacters: Math.round(totalCharacters / documents.length),
      minTokens: minTokens === Infinity ? 0 : minTokens,
      maxTokens
    };
  } catch (error) {
    console.error(`❌ Error analyzing collection '${collectionName}':`, error);
    return null;
  }
}

/**
 * Main analysis function
 */
async function analyzeAllCollections() {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/nexa';
    console.log(`🔗 Connecting to MongoDB...`);
    await mongoose.connect(mongoUri);
    console.log(`✅ Connected to MongoDB\n`);

    const db = mongoose.connection.db;
    if (!db) {
      throw new Error('Database connection not established');
    }

    // Get all collections
    const collections = await db.listCollections().toArray();
    console.log(`📊 Found ${collections.length} collections\n`);
    console.log(`${'='.repeat(100)}\n`);

    const results: TokenStats[] = [];

    // Analyze each collection
    for (const collectionInfo of collections) {
      const collectionName = collectionInfo.name;
      console.log(`🔍 Analyzing collection: ${collectionName}...`);

      const stats = await analyzeCollection(collectionName);
      if (stats) {
        results.push(stats);
        console.log(`   ✓ Documents: ${stats.documentCount}`);
        console.log(`   ✓ Avg Claude tokens: ${stats.avgClaudeTokens}`);
        console.log(`   ✓ Avg GPT tokens: ${stats.avgGptTokens}`);
        console.log(`   ✓ Avg characters: ${stats.avgCharacters}`);
        console.log(`   ✓ Range: ${stats.minTokens} - ${stats.maxTokens} tokens\n`);
      }
    }

    // Print summary table
    console.log(`\n${'='.repeat(100)}`);
    console.log(`📈 SUMMARY - Token Count Analysis`);
    console.log(`${'='.repeat(100)}\n`);

    console.log(`${'Collection'.padEnd(30)} ${'Docs'.padEnd(10)} ${'Claude Avg'.padEnd(15)} ${'GPT Avg'.padEnd(15)} ${'Char Avg'.padEnd(15)} ${'Range'}`);
    console.log(`${'-'.repeat(30)} ${'-'.repeat(10)} ${'-'.repeat(15)} ${'-'.repeat(15)} ${'-'.repeat(15)} ${'-'.repeat(20)}`);

    for (const stat of results) {
      console.log(
        `${stat.collectionName.padEnd(30)} ` +
        `${stat.documentCount.toString().padEnd(10)} ` +
        `${stat.avgClaudeTokens.toString().padEnd(15)} ` +
        `${stat.avgGptTokens.toString().padEnd(15)} ` +
        `${stat.avgCharacters.toString().padEnd(15)} ` +
        `${stat.minTokens}-${stat.maxTokens}`
      );
    }

    // Calculate overall averages
    if (results.length > 0) {
      const totalClaudeAvg = Math.round(
        results.reduce((sum, stat) => sum + stat.avgClaudeTokens, 0) / results.length
      );
      const totalGptAvg = Math.round(
        results.reduce((sum, stat) => sum + stat.avgGptTokens, 0) / results.length
      );
      const totalCharAvg = Math.round(
        results.reduce((sum, stat) => sum + stat.avgCharacters, 0) / results.length
      );

      console.log(`${'-'.repeat(100)}`);
      console.log(
        `${'OVERALL AVERAGE'.padEnd(30)} ` +
        `${''.padEnd(10)} ` +
        `${totalClaudeAvg.toString().padEnd(15)} ` +
        `${totalGptAvg.toString().padEnd(15)} ` +
        `${totalCharAvg.toString().padEnd(15)}`
      );
    }

    console.log(`\n${'='.repeat(100)}\n`);
    console.log(`ℹ️  Note: Token counts are approximations based on character count.`);
    console.log(`   For exact counts, install @anthropic-ai/tokenizer and tiktoken packages.\n`);

  } catch (error) {
    console.error('❌ Error during analysis:', error);
    throw error;
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB');
  }
}

// Run the analysis
analyzeAllCollections()
  .then(() => {
    console.log('\n✅ Analysis complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Analysis failed:', error);
    process.exit(1);
  });
