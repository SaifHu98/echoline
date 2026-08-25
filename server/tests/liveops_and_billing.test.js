const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const fs = require('fs');

const { GooglePlayBillingValidator } = require('../src/payments/google_play_billing');
const { ShopService } = require('../src/payments/shop_service');
const { LiveOpsEventManager } = require('../src/liveops/event_manager');

const catalogPath = path.join(__dirname, '../../shared/shop_catalog.json');
const catalogData = JSON.parse(fs.readFileSync(catalogPath, 'utf-8'));

const liveopsPath = path.join(__dirname, '../../shared/liveops_events.json');
const liveopsData = JSON.parse(fs.readFileSync(liveopsPath, 'utf-8'));

test('Google Play Billing & LiveOps Management Suite', async (t) => {
  const billingValidator = new GooglePlayBillingValidator('com.ecouni.echoline');
  const shopService = new ShopService(catalogData);
  const liveopsManager = new LiveOpsEventManager(liveopsData, shopService);

  await t.test('verifies valid Google Play purchase receipt and credits Chrono Shards', async () => {
    const receipt = {
      orderId: 'GPA.1234-5678-9012-34567',
      packageName: 'com.ecouni.echoline',
      productId: 'com.ecouni.echoline.shards500',
      purchaseState: 0,
      purchaseToken: 'mock_valid_purchase_token_xyz_987654321'
    };

    const result = await billingValidator.verifyPurchase(receipt);
    assert.strictEqual(result.success, true);
    assert.strictEqual(result.grant.shards, 500);

    // Credit user wallet
    shopService.creditPurchasedShards('user_hero_01', result.grant.shards);
    const wallet = shopService.getWallet('user_hero_01');
    assert.strictEqual(wallet.chrono_shards, 500);
  });

  await t.test('rejects replay attack with duplicate Google Play orderId', async () => {
    const duplicateReceipt = {
      orderId: 'GPA.1234-5678-9012-34567', // already processed
      packageName: 'com.ecouni.echoline',
      productId: 'com.ecouni.echoline.shards500',
      purchaseState: 0,
      purchaseToken: 'mock_valid_purchase_token_xyz_987654321'
    };

    const result = await billingValidator.verifyPurchase(duplicateReceipt);
    assert.strictEqual(result.success, false);
    assert.match(result.error, /already been fulfilled/);
  });

  await t.test('purchases cosmetic outfit using Chrono Shards balance', async () => {
    // User currently has 500 shards
    const purchaseRes = shopService.purchaseItem('user_hero_01', 'item_outfit_past_artisan');
    assert.strictEqual(purchaseRes.success, true);
    assert.strictEqual(purchaseRes.remainingWallet.chrono_shards, 0);

    const wallet = shopService.getWallet('user_hero_01');
    assert.strictEqual(wallet.unlocked_items.has('skin_past_artisan'), true);
  });

  await t.test('tracks liveops quest progress and claims tournament reward', async () => {
    const userId = 'user_hero_01';

    // Simulate achieving 3 perfect harmonies
    liveopsManager.recordProgress(userId, 'achieve_perfect_harmony', 3);

    const claimRes = liveopsManager.claimQuestReward(userId, 'quest_achieve_perfect_harmony');
    assert.strictEqual(claimRes.success, true);
    assert.strictEqual(claimRes.reward.amount, 250);

    // Wallet should now have 250 shards
    const wallet = shopService.getWallet(userId);
    assert.strictEqual(wallet.chrono_shards, 250);
  });
});
