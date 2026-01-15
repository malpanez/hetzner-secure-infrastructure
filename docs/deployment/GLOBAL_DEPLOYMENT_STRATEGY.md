# Global Deployment Strategy - Two Minds Trading

## 🌍 Overview

Two Minds Trading is a **global trading education platform** selling courses worldwide. This infrastructure must support customers and operations across multiple continents and time zones.

## 🎯 Target Audience

### Primary Markets
- 🇺🇸 **United States** - Primary market, largest customer base
- 🇪🇸 **Spain / Europe** - European market, Spanish-speaking
- 🇲🇽 **Mexico** - North American Spanish market
- 🇦🇷 **Argentina** - South American market
- 🇧🇷 **Brazil** - Portuguese-speaking market

### Future Expansion
- 🇩🇪 Germany
- 🇫🇷 France
- 🌏 Asia-Pacific (future consideration)

## ⏰ Timezone Strategy

### Server Configuration: UTC Only

**Why UTC?**
1. ✅ **Log Correlation** - All system logs use consistent timestamps
2. ✅ **Payment Processing** - Stripe, PayPal, payment gateways use UTC
3. ✅ **Analytics** - Google Analytics reports in UTC
4. ✅ **Team Collaboration** - No confusion across timezones
5. ✅ **Database Consistency** - All timestamps stored in UTC
6. ✅ **API Compatibility** - Industry standard for APIs

**Configuration:**
```yaml
# ansible/inventory/group_vars/all/common.yml
system_timezone: "UTC"
```

❌ **DO NOT USE:**
- `Europe/Dublin` - Regional timezone, confuses global operations
- `America/New_York` - Excludes other markets
- `Europe/Madrid` - Regional preference

### Application Layer: User-Specific Timezones

**WordPress Configuration:**
1. **WordPress Settings:**
   - Set WordPress to UTC: `Settings > General > Timezone > UTC+0`
   - Let users select their timezone in their profile

2. **WooCommerce:**
   - Orders stored in UTC
   - Display in user's local timezone (JavaScript)

3. **Course Access:**
   - Launch times converted to user's timezone via JavaScript
   - Email notifications show user's local time

**Implementation:**
```javascript
// Example: Convert UTC to user's local timezone
const utcDate = new Date('2026-01-15T14:00:00Z');
const localDate = utcDate.toLocaleString('en-US', {
  timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone
});
```

## 🌐 Multi-Language Support

### Installed System Locales

```yaml
additional_locales:
  - en_US.UTF-8     # US English (primary language)
  - en_GB.UTF-8     # British English
  - es_ES.UTF-8     # Spanish (Spain)
  - es_MX.UTF-8     # Spanish (Mexico)
  - es_AR.UTF-8     # Spanish (Argentina)
  - pt_BR.UTF-8     # Portuguese (Brazil)
  - de_DE.UTF-8     # German (future)
  - fr_FR.UTF-8     # French (future)
```

### WordPress Multi-Language

**Recommended Plugins:**
1. **WPML** (WordPress Multilingual) - Premium, best for e-commerce
2. **Polylang** - Free alternative
3. **TranslatePress** - Visual translation editor

**URL Structure:**
- `twomindstrading.com/en/` - English
- `twomindstrading.com/es/` - Spanish
- `twomindstrading.com/pt/` - Portuguese

### Currency Support

**WooCommerce Multi-Currency:**
- Base currency: USD (United States Dollar)
- Supported: EUR, GBP, MXN, ARS, BRL
- Payment gateway: Stripe (supports 135+ currencies)

## 🕐 NTP Configuration - Global Anycast

### Primary NTP Servers (Global Anycast)

```yaml
ntp_servers:
  - time.cloudflare.com    # Cloudflare anycast (99.99% uptime)
  - time.google.com        # Google anycast (highly reliable)
  - 0.de.pool.ntp.org      # Regional pool (low latency from Germany)
  - 1.de.pool.ntp.org
```

**Why Anycast?**
- ✅ Routes to nearest server automatically
- ✅ DDoS resistant
- ✅ High availability (multiple locations)
- ✅ Low latency globally

### Fallback NTP Servers

```yaml
ntp_fallback_servers:
  - 0.europe.pool.ntp.org  # European pool
  - 1.europe.pool.ntp.org
  - time.windows.com       # Microsoft fallback
```

### Verification

```bash
# Check NTP sync status
timedatectl status

# Check NTP sources
ntpq -p

# Force sync (if needed)
sudo systemctl restart systemd-timesyncd
```

## 📍 Server Location Strategy

### Current Deployment: Hetzner Germany (Nuremberg)

**Why Nuremberg?**
1. ✅ **Central Location** - Optimal latency to US, Europe, Latin America
2. ✅ **GDPR Compliance** - EU data protection regulations
3. ✅ **Network Quality** - Excellent connectivity worldwide
4. ✅ **Cost Effective** - Lower costs than US/UK
5. ✅ **Hetzner Reliability** - 99.9% uptime SLA

**Average Latency:**
| Region | Latency |
|--------|---------|
| Germany | 1-5 ms |
| Europe | 10-50 ms |
| US East | 80-100 ms |
| US West | 140-160 ms |
| Mexico | 120-140 ms |
| Argentina | 180-220 ms |
| Brazil | 160-200 ms |

### Future: CDN for Static Assets

**Recommended CDN:**
- Cloudflare (free tier available)
- AWS CloudFront
- Bunny CDN (cost-effective)

**Benefits:**
- Cache static assets (images, CSS, JS) globally
- Reduce server load
- Improve page load times worldwide

## 🗄️ Database Configuration

### UTF-8 Character Set (Emoji Support)

```sql
-- WordPress database configuration
ALTER DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

**Why utf8mb4?**
- ✅ Supports emojis 😊🎯🌍
- ✅ All languages and scripts
- ✅ Required for international content

### Timezone Settings

```sql
-- MySQL/MariaDB should use UTC
SET GLOBAL time_zone = '+00:00';
SET time_zone = '+00:00';
```

## 📧 Email Configuration

### Transactional Email Service

**Recommended:**
1. **SendGrid** - 100 emails/day free
2. **Amazon SES** - $0.10 per 1,000 emails
3. **Mailgun** - Good for high volume

**Configuration:**
- Send from: `noreply@twomindstrading.com`
- Reply-to: `support@twomindstrading.com`
- DKIM/SPF/DMARC properly configured

### Email Localization

WooCommerce can send emails in user's language:
- Order confirmations in Spanish for Spanish customers
- Receipt in Portuguese for Brazilian customers

## 🔒 Security Considerations

### Compliance Requirements

**GDPR (Europe):**
- Cookie consent required
- Privacy policy in local language
- Right to data deletion
- Data processing agreements

**PCI-DSS (Global):**
- Credit card data handled by Stripe (Level 1 PCI compliant)
- No card data stored on server

**CCPA (California, USA):**
- Privacy policy disclosure
- Opt-out of data sale

### Geographic Blocking (Optional)

If needed, block traffic from high-risk countries:

```nginx
# /etc/nginx/conf.d/geo-block.conf
geo $allowed_country {
    default 1;

    # Block these countries (example)
    CN 0;  # China
    RU 0;  # Russia
    KP 0;  # North Korea
}

server {
    if ($allowed_country = 0) {
        return 403;
    }
}
```

⚠️ **WARNING:** Only use geographic blocking if absolutely necessary. It can block legitimate customers using VPNs.

## 📊 Monitoring & Analytics

### Time-Based Analytics

**Google Analytics:**
- Use UTC for reports
- Filter by user location
- Analyze peak times by geography

**WordPress Plugin:**
- WooCommerce Admin Dashboard shows sales by country
- Peak times by timezone

### Server Monitoring

**Key Metrics:**
- Response time from different regions (use Pingdom)
- Error rates by geography
- Payment success rates by country

## 🚀 Deployment Checklist

### Pre-Deployment

- [ ] Set `system_timezone: "UTC"` in `group_vars/all/common.yml`
- [ ] Set `system_locale: "en_US.UTF-8"` (not `en_IE.UTF-8`)
- [ ] Configure all `additional_locales`
- [ ] Configure NTP with global anycast servers
- [ ] Install WordPress multi-language plugin
- [ ] Configure WooCommerce multi-currency
- [ ] Set up CDN (Cloudflare recommended)
- [ ] Configure email service (SendGrid/SES)
- [ ] Add GDPR compliance plugins
- [ ] Test payment processing in multiple currencies

### Post-Deployment

- [ ] Verify timezone: `timedatectl status` shows "UTC"
- [ ] Verify NTP sync: `timedatectl show-timesync --all`
- [ ] Test site from multiple regions (VPN/Proxy)
- [ ] Verify WordPress shows UTC in `wp-admin`
- [ ] Test order placement from US/Europe/Latin America
- [ ] Verify email notifications in correct language
- [ ] Check CDN cache hit rate
- [ ] Monitor response times globally

## 🔧 Troubleshooting

### Issue: Wrong Timezone Displayed

**Symptom:** Course launch times show incorrect time
**Cause:** WordPress timezone not set to UTC
**Fix:**
```php
// wp-config.php
define('WP_DEBUG', false);
update_option('timezone_string', 'UTC');
```

### Issue: Payment Times Don't Match Logs

**Symptom:** Stripe payment time differs from WordPress order time
**Cause:** Server not using UTC
**Fix:**
```bash
ansible-playbook -i inventory/production ansible/playbooks/site.yml --tags common
```

### Issue: NTP Not Syncing

**Symptom:** `timedatectl` shows "System clock unsynchronized"
**Cause:** Firewall blocking NTP (UDP 123)
**Fix:**
```bash
sudo ufw allow 123/udp
sudo systemctl restart systemd-timesyncd
```

## 📚 Additional Resources

- [WordPress Timezone Documentation](https://wordpress.org/support/article/formatting-date-and-time/)
- [WooCommerce Multi-Currency Guide](https://woocommerce.com/document/multi-currency/)
- [Stripe Global Payments](https://stripe.com/global)
- [GDPR Compliance for WordPress](https://wordpress.org/about/privacy/)
- [NTP Pool Project](https://www.ntppool.org/)

## 🎓 Best Practices

1. **Always Store in UTC** - Convert to local timezone only for display
2. **Test Globally** - Use VPN/proxy to test from different regions
3. **Monitor Latency** - Track response times from all target markets
4. **Localize Content** - Not just translation, but cultural adaptation
5. **Payment Options** - Support local payment methods (Boleto in Brazil, OXXO in Mexico)
6. **Compliance First** - GDPR, CCPA compliance is not optional
7. **Performance Budget** - Aim for <3s page load globally
8. **Support Hours** - Consider 24/7 support or clearly state business hours in UTC

---

**Document Version:** 1.0
**Last Updated:** 2026-01-15
**Maintained By:** DevOps Team, Two Minds Trading
