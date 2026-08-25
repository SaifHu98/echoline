<?php
require_once __DIR__ . '/config.php';
Auth::require();
require_once __DIR__ . '/includes/Crud.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Crud::handle('shop_items', [
        ['name' => 'sku', 'required' => true, 'sanitize' => true],
        ['name' => 'google_play_sku'],
        ['name' => 'app_store_sku'],
        ['name' => 'name_key', 'required' => true, 'sanitize' => true],
        ['name' => 'description_key'],
        ['name' => 'category'],
        ['name' => 'price_usd', 'required' => true],
        ['name' => 'currency_amount'],
        ['name' => 'bonus_percent', 'required' => true],
        ['name' => 'cosmetic_id'],
        ['name' => 'inventory_json', 'json' => true],
        ['name' => 'is_active', 'required' => true],
        ['name' => 'is_featured', 'required' => true],
        ['name' => 'is_limited', 'required' => true],
        ['name' => 'max_purchases'],
        ['name' => 'sort_order', 'required' => true],
        ['name' => 'image_url'],
    ], 'shop.php');
    exit;
}

$pageTitle = I18n::t('shop.title');
$currentSection = 'shop';
$items = Database::fetchAll('SELECT * FROM shop_items ORDER BY is_active DESC, sort_order ASC');

// Sales stats
$salesByDay = Database::fetchAll(
    "SELECT DATE(created_at) AS day, SUM(amount_usd) AS total, COUNT(*) AS txns
     FROM sales_log WHERE status = 'verified' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     GROUP BY DATE(created_at) ORDER BY day ASC"
);

include __DIR__ . '/includes/header.php';
?>

<div class="page-header">
  <h1><?= I18n::t('shop.title') ?></h1>
  <button class="btn primary" onclick="openShopForm()">+ <?= I18n::t('shop.create') ?></button>
</div>

<div class="grid-stats">
  <?php
  $totalItems = count($items);
  $activeItems = count(array_filter($items, fn($i) => $i['is_active']));
  $featuredItems = count(array_filter($items, fn($i) => $i['is_featured']));
  $totalSales30d = array_sum(array_column($salesByDay, 'total'));
  ?>
  <div class="stat-card stat-cyan"><div class="stat-label">منتجات نشطة</div><div class="stat-val"><?= $activeItems ?>/<?= $totalItems ?></div></div>
  <div class="stat-card stat-amber"><div class="stat-label">منتجات مميزة</div><div class="stat-val"><?= $featuredItems ?></div></div>
  <div class="stat-card stat-green"><div class="stat-label">مبيعات 30 يوم</div><div class="stat-val">$<?= number_format($totalSales30d, 2) ?></div></div>
  <div class="stat-card stat-violet"><div class="stat-label">عدد المعاملات</div><div class="stat-val"><?= number_format(array_sum(array_column($salesByDay, 'txns'))) ?></div></div>
</div>

<div class="panel">
  <h3>المنتجات</h3>
  <table class="data-table">
    <thead>
      <tr>
        <th>SKU</th><th>Google Play</th><th>الاسم</th><th>الفئة</th>
        <th>السعر</th><th>العملات</th><th>المكافأة</th><th>الحالة</th><th>الإجراءات</th>
      </tr>
    </thead>
    <tbody>
      <?php foreach ($items as $i): ?>
        <tr>
          <td><code><?= Security::escape($i['sku']) ?></code></td>
          <td class="text-muted small"><?= Security::escape($i['google_play_sku'] ?? '—') ?></td>
          <td>
            <strong><?= Security::escape($i['name_key']) ?></strong>
            <?php if ($i['is_featured']): ?><span class="badge featured">⭐</span><?php endif; ?>
            <?php if ($i['is_limited']): ?><span class="badge warn">محدود</span><?php endif; ?>
          </td>
          <td><span class="badge"><?= Security::escape($i['category']) ?></span></td>
          <td class="text-amber">$<?= number_format($i['price_usd'], 2) ?></td>
          <td><?= $i['currency_amount'] ? '💎 ' . $i['currency_amount'] : '—' ?></td>
          <td><?= $i['bonus_percent'] ? '+' . $i['bonus_percent'] . '%' : '—' ?></td>
          <td>
            <?php if ($i['is_active']): ?><span class="badge badge-ok">نشط</span><?php else: ?><span class="badge">معطل</span><?php endif; ?>
          </td>
          <td>
            <button class="btn small" onclick='editItem(<?= json_encode($i, JSON_HEX_APOS | JSON_HEX_QUOT) ?>)'>تعديل</button>
            <button class="btn small danger" onclick="deleteItem(<?= $i['id'] ?>)">حذف</button>
          </td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>
</div>

<div class="panel">
  <h3>مخطط المبيعات (آخر 30 يوم)</h3>
  <canvas id="salesChart" style="width:100%; height:240px;"></canvas>
</div>

<div id="shop-modal" class="modal" hidden>
  <div class="modal-content">
    <h2 id="shop-modal-title">منتج جديد</h2>
    <form id="shop-form">
      <input type="hidden" name="<?= CSRF_TOKEN_NAME ?>" value="<?= Security::csrfToken() ?>">
      <input type="hidden" name="action" value="save">
      <input type="hidden" name="id" id="shop-id">
      <div class="grid-form">
        <div class="form-group">
          <label>SKU داخلي *</label>
          <input type="text" name="sku" id="sh-sku" required pattern="[a-z0-9_]+">
        </div>
        <div class="form-group">
          <label>Google Play SKU</label>
          <input type="text" name="google_play_sku" id="sh-gsku" placeholder="com.ecouni.echoline.xxx">
        </div>
        <div class="form-group">
          <label>App Store SKU</label>
          <input type="text" name="app_store_sku" id="sh-asku">
        </div>
        <div class="form-group">
          <label>مفتاح الاسم *</label>
          <input type="text" name="name_key" id="sh-name" required placeholder="shop.item.name">
        </div>
        <div class="form-group">
          <label>مفتاح الوصف</label>
          <input type="text" name="description_key" id="sh-desc">
        </div>
        <div class="form-group">
          <label>الفئة</label>
          <select name="category" id="sh-cat">
            <option value="currency">عملات</option>
            <option value="cosmetic">تجميلي</option>
            <option value="pass">تذكرة</option>
            <option value="bundle">حزمة</option>
            <option value="expansion">توسيع</option>
            <option value="consumable">استهلاكي</option>
            <option value="boost">معزز</option>
          </select>
        </div>
        <div class="form-group">
          <label>السعر (USD) *</label>
          <input type="number" name="price_usd" id="sh-price" step="0.01" min="0" required>
        </div>
        <div class="form-group">
          <label>عدد العملات</label>
          <input type="number" name="currency_amount" id="sh-amt" min="0">
        </div>
        <div class="form-group">
          <label>مكافأة %</label>
          <input type="number" name="bonus_percent" id="sh-bonus" value="0" min="0" max="500">
        </div>
        <div class="form-group">
          <label>ترتيب</label>
          <input type="number" name="sort_order" id="sh-order" value="0">
        </div>
        <div class="form-group">
          <label>معرّف تجميلي</label>
          <input type="text" name="cosmetic_id" id="sh-cosm">
        </div>
        <div class="form-group">
          <label>رابط الصورة</label>
          <input type="url" name="image_url" id="sh-img">
        </div>
        <div class="form-group full">
          <label>محتوى الحزمة (JSON)</label>
          <textarea name="inventory_json" id="sh-inv" rows="3" placeholder='{"currency": 500, "items": ["frame_aureate"]}'></textarea>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_active" value="0">
            <input type="checkbox" name="is_active" id="sh-active" value="1" checked> نشط
          </label>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_featured" value="0">
            <input type="checkbox" name="is_featured" id="sh-feat" value="1"> مميز
          </label>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="hidden" name="is_limited" value="0">
            <input type="checkbox" name="is_limited" id="sh-lim" value="1"> محدود الوقت
          </label>
        </div>
      </div>
      <div class="modal-actions">
        <button type="button" class="btn ghost" onclick="closeShopForm()">إلغاء</button>
        <button type="submit" class="btn primary">حفظ</button>
      </div>
    </form>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<script>
const salesData = <?= json_encode($salesByDay) ?>;
new Chart(document.getElementById('salesChart'), {
  type: 'line',
  data: {
    labels: salesData.map(d => d.day),
    datasets: [{
      label: 'الإيرادات ($)',
      data: salesData.map(d => parseFloat(d.total)),
      borderColor: '#00E5FF',
      backgroundColor: 'rgba(0,229,255,0.1)',
      tension: 0.3, fill: true
    }]
  },
  options: {
    responsive: true, maintainAspectRatio: false,
    plugins: { legend: { labels: { color: '#fff' } } },
    scales: {
      x: { ticks: { color: '#8E9BAE' }, grid: { color: 'rgba(255,255,255,0.05)' } },
      y: { ticks: { color: '#8E9BAE' }, grid: { color: 'rgba(255,255,255,0.05)' } }
    }
  }
});

function openShopForm(it) {
  document.getElementById('shop-modal').hidden = false;
  if (it) {
    document.getElementById('shop-modal-title').textContent = 'تعديل: ' + it.sku;
    document.getElementById('shop-id').value = it.id;
    document.getElementById('sh-sku').value = it.sku;
    document.getElementById('sh-sku').readOnly = true;
    document.getElementById('sh-gsku').value = it.google_play_sku || '';
    document.getElementById('sh-asku').value = it.app_store_sku || '';
    document.getElementById('sh-name').value = it.name_key;
    document.getElementById('sh-desc').value = it.description_key || '';
    document.getElementById('sh-cat').value = it.category;
    document.getElementById('sh-price').value = it.price_usd;
    document.getElementById('sh-amt').value = it.currency_amount || 0;
    document.getElementById('sh-bonus').value = it.bonus_percent;
    document.getElementById('sh-order').value = it.sort_order;
    document.getElementById('sh-cosm').value = it.cosmetic_id || '';
    document.getElementById('sh-img').value = it.image_url || '';
    document.getElementById('sh-inv').value = it.inventory_json || '';
    document.getElementById('sh-active').checked = !!it.is_active;
    document.getElementById('sh-feat').checked = !!it.is_featured;
    document.getElementById('sh-lim').checked = !!it.is_limited;
  } else {
    document.getElementById('shop-form').reset();
    document.getElementById('shop-id').value = '';
    document.getElementById('sh-sku').readOnly = false;
    document.getElementById('shop-modal-title').textContent = 'منتج جديد';
  }
}
function closeShopForm() { document.getElementById('shop-modal').hidden = true; }
function editItem(it) { openShopForm(it); }

document.getElementById('shop-form').addEventListener('submit', async e => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const res = await fetch('shop.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحفظ', 'success'); setTimeout(() => location.reload(), 600); }
  else showToast(j.error || 'خطأ', 'error');
});

async function deleteItem(id) {
  if (!confirm('حذف المنتج؟')) return;
  const fd = new FormData();
  fd.append('action', 'delete'); fd.append('id', id); fd.append('_token', document.getElementById('csrf-token').value);
  const res = await fetch('shop.php', { method: 'POST', body: fd });
  const j = await res.json();
  if (j.success) { showToast('تم الحذف', 'success'); setTimeout(() => location.reload(), 500); }
}
</script>

<?php include __DIR__ . '/includes/footer.php'; ?>