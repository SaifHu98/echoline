/**
 * Shop & In-Game Economy Service for ECHO//LINE (أصداء)
 * Manages dynamic catalog, currency wallets, and item unlocks.
 */

class ShopService {
  constructor(catalogData) {
    this.catalog = JSON.parse(JSON.stringify(catalogData));
    this.userWallets = new Map(); // userId -> { chrono_flux: 0, chrono_shards: 0, unlocked_items: Set }
  }

  getWallet(userId) {
    let wallet = this.userWallets.get(userId);
    if (!wallet) {
      wallet = {
        chrono_flux: 1000, // Starting bonus
        chrono_shards: 0,
        unlocked_items: new Set()
      };
      this.userWallets.set(userId, wallet);
    }
    return wallet;
  }

  getCatalog() {
    return {
      currencies: this.catalog.currencies,
      categories: this.catalog.categories,
      items: this.catalog.items
    };
  }

  updateItem(itemId, updateFields) {
    const item = this.catalog.items.find(i => i.id === itemId);
    if (!item) return false;
    Object.assign(item, updateFields);
    return true;
  }

  addItem(newItem) {
    this.catalog.items.push(newItem);
    return true;
  }

  deleteItem(itemId) {
    const idx = this.catalog.items.findIndex(i => i.id === itemId);
    if (idx !== -1) {
      this.catalog.items.splice(idx, 1);
      return true;
    }
    return false;
  }

  purchaseItem(userId, itemId) {
    const item = this.catalog.items.find(i => i.id === itemId);
    if (!item) return { success: false, error: 'Item not found in catalog' };

    const wallet = this.getWallet(userId);
    const { currency, amount } = item.price;
    const finalPrice = Math.round(amount * (1.0 - (item.discount_pct || 0) / 100.0));

    if (currency === 'chrono_flux') {
      if (wallet.chrono_flux < finalPrice) {
        return { success: false, error: 'Insufficient Chrono Flux balance' };
      }
      wallet.chrono_flux -= finalPrice;
    } else if (currency === 'chrono_shards') {
      if (wallet.chrono_shards < finalPrice) {
        return { success: false, error: 'Insufficient Chrono Shards balance' };
      }
      wallet.chrono_shards -= finalPrice;
    } else {
      return { success: false, error: 'Direct real money purchases must use Google Play Billing' };
    }

    if (item.grant_contents && item.grant_contents.cosmetic_item_id) {
      wallet.unlocked_items.add(item.grant_contents.cosmetic_item_id);
    }

    return {
      success: true,
      itemId,
      remainingWallet: {
        chrono_flux: wallet.chrono_flux,
        chrono_shards: wallet.chrono_shards
      }
    };
  }

  creditPurchasedShards(userId, shardsAmount) {
    const wallet = this.getWallet(userId);
    wallet.chrono_shards += shardsAmount;
    return wallet;
  }
}

module.exports = {
  ShopService
};
