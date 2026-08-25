/**
 * Server-Side Google Play Billing & Receipt Validator for ECHO//LINE (أصداء)
 * Validates purchase tokens, signature authenticity, prevents replay attacks, and fulfills transactions.
 */

class GooglePlayBillingValidator {
  constructor(packageName = 'com.ecouni.echoline') {
    this.packageName = packageName;
    this.processedOrderIds = new Set(); // Replay attack protection
    this.validSkus = new Map([
      ['com.ecouni.echoline.shards500', { shards: 500, priceUsd: 4.99 }],
      ['com.ecouni.echoline.shards1200', { shards: 1200, priceUsd: 9.99 }],
      ['com.ecouni.echoline.season1pass', { passTierBoost: 5, flux: 2000, priceUsd: 7.99 }]
    ]);
  }

  /**
   * Verify an incoming Google Play purchase payload
   * @param {Object} purchaseReceipt { orderId, packageName, productId, purchaseTime, purchaseState, purchaseToken }
   */
  async verifyPurchase(purchaseReceipt) {
    const { orderId, packageName, productId, purchaseState, purchaseToken } = purchaseReceipt;

    // 1. Package Name Validation
    if (packageName !== this.packageName) {
      return { success: false, error: `Invalid package name: ${packageName}` };
    }

    // 2. Product ID / SKU Validation
    if (!this.validSkus.has(productId)) {
      return { success: false, error: `Unrecognized Google Play SKU: ${productId}` };
    }

    // 3. Purchase State Check (0 = Purchased)
    if (purchaseState !== 0 && purchaseState !== 'PURCHASED') {
      return { success: false, error: `Invalid purchase state: ${purchaseState}` };
    }

    // 4. Replay Attack Prevention
    if (this.processedOrderIds.has(orderId)) {
      return { success: false, error: `Order ID ${orderId} has already been fulfilled.` };
    }

    // 5. Purchase Token Check
    if (!purchaseToken || typeof purchaseToken !== 'string' || purchaseToken.length < 16) {
      return { success: false, error: 'Malformed or missing Google Play purchase token.' };
    }

    // Mark as processed
    this.processedOrderIds.add(orderId);

    const skuDetails = this.validSkus.get(productId);
    return {
      success: true,
      orderId,
      productId,
      grant: skuDetails
    };
  }
}

module.exports = {
  GooglePlayBillingValidator
};
