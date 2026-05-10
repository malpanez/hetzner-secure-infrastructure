<?php
/**
 * Plugin Name: TMT Performance & SEO Fixes
 * Description: Quita jQuery del front, defiere CSS/JS no crítico, arregla robots.txt, heading order, cookie contrast.
 * Version: 2.0.0
 * Author: Two Minds Trading
 */

if (!defined('ABSPATH')) exit;

/* 1) Quitar jQuery + migrate del FRONT (no admin) */
add_action('wp_enqueue_scripts', function () {
    if (is_admin()) return;
    wp_dequeue_script('jquery');
    wp_dequeue_script('jquery-core');
    wp_dequeue_script('jquery-migrate');
    wp_deregister_script('jquery-migrate');
}, 100);

/* 2) Diferir CSS no crítico (print/onload trick) */
add_filter('style_loader_tag', function ($html, $handle) {
    if (is_admin()) return $html;
    $defer = [
        'rankmath',
        'accessibility-assistant',
        'cookie-notice-front',
        'dashicons',
    ];
    foreach ($defer as $h) {
        if (strpos($handle, $h) !== false) {
            $html = str_replace("rel='stylesheet'", "rel='stylesheet' media='print' onload=\"this.media='all';this.onload=null\"", $html);
            $html = str_replace('rel="stylesheet"', 'rel="stylesheet" media="print" onload="this.media=\'all\';this.onload=null"', $html);
            break;
        }
    }
    return $html;
}, 10, 2);

/* 3) Diferir JS render-blocking (RankMath front.min.js) */
add_filter('script_loader_tag', function ($tag, $handle) {
    if (is_admin()) return $tag;
    $defer_scripts = ['cookie-notice-front'];
    foreach ($defer_scripts as $h) {
        if (strpos($handle, $h) !== false) {
            $tag = str_replace(' src=', ' defer src=', $tag);
            break;
        }
    }
    return $tag;
}, 10, 2);

/* 4) Meta description fallback (si RankMath no la emite) */
add_action('wp_head', function () {
    if (is_front_page() || is_home()) {
        echo '<meta name="description" content="Two Minds Trading: formación de trading profesional con Order Flow (ATAS) y Gamma Exposure (gexbot). Metodología institucional, reglas claras y proceso, no intuición.">' . "\n";
        echo '<meta property="og:description" content="Formación profesional de trading con Order Flow y Gamma Exposure. Metodología institucional y acompañamiento de traders reales.">' . "\n";
    }
}, 1);

/* 5) Preload de la imagen LCP del hero */
add_action('wp_head', function () {
    if (!is_front_page()) return;
    echo '<link rel="preload" as="image" type="image/webp" href="https://twomindstrading.com/wp-content/uploads/2026/04/Gemini_Generated_Image_iyxbb2iyxbb2iyxb-scaled-1-1024x572.webp" imagesrcset="https://twomindstrading.com/wp-content/uploads/2026/04/Gemini_Generated_Image_iyxbb2iyxbb2iyxb-scaled-1-768x429.webp 768w, https://twomindstrading.com/wp-content/uploads/2026/04/Gemini_Generated_Image_iyxbb2iyxbb2iyxb-scaled-1-1024x572.webp 1024w" imagesizes="(max-width: 1023px) 90vw, 1024px" fetchpriority="high">' . "\n";
}, 2);

/* 6) Arreglar robots.txt (sin Content-Signal que da error en PSI) */
add_filter('robots_txt', function ($output, $public) {
    if ('0' == $public) return $output;
    $out  = "User-agent: *\n";
    $out .= "Disallow: /wp-admin/\n";
    $out .= "Allow: /wp-admin/admin-ajax.php\n";
    $out .= "Disallow: /wp-includes/\n";
    $out .= "Disallow: /?s=\n";
    $out .= "Sitemap: " . home_url('/sitemap_index.xml') . "\n";
    return $out;
}, 10, 2);

/* 7) Cache headers más largos para estáticos */
add_filter('wp_headers', function ($headers) {
    if (!is_admin()) {
        $headers['Cache-Control'] = 'public, max-age=3600';
    }
    return $headers;
});

/* 8) Critical CLS-prevention CSS + cookie button contrast + responsive fixes */
add_action('wp_head', function () {
    echo '<style>' .
        '#cookie-notice{position:fixed!important;bottom:0;left:0;right:0;z-index:10000;width:100%}' .
        '.cn-button{background-color:#00c9b7!important;color:#000!important;font-weight:600!important}' .
        '.nav-logo img{width:44px;height:44px}' .
        '.eyebrow,.why-tag{background:rgb(18,40,54)!important;color:#45c7df!important}' .
        '.hero-pill{background:rgb(5,13,22)!important}' .
        '.inst-tag{background:rgb(12,20,35)!important}' .
        '.why-icon{background:rgb(47,57,74)!important}' .
        '.disclaimer{color:#a0b4cc!important}' .
    '</style>' . "\n";

    echo '<style id="tmt-responsive">' .

    /* ── TABLET 768–1024 ── */
    '@media(max-width:1024px){' .
        '.hero-v2 .hero-dashboard-wrap{max-width:90vw;margin-bottom:-80px}' .
        '.hero-v2 .hero-dashboard{border-radius:16px}' .
        '.sec{padding:56px 20px}' .
        '.wrap{padding:0 20px}' .
        '.courses-grid{gap:20px}' .
        '.instructors-grid{gap:20px}' .
        'footer{padding:48px 20px 0}' .
    '}' .

    /* ── TABLET SMALL 860 ── nav hamburger already triggers */
    '@media(max-width:860px){' .
        '.hero-v2 .hero-dashboard-wrap{max-width:95vw;margin-bottom:-60px}' .
        '.hero-v2 .hero-h1{font-size:clamp(32px,6vw,52px)}' .
        '.hero-v2 .hero-desc{font-size:15px;max-width:540px;margin-left:auto;margin-right:auto}' .
        '.btn-nav{font-size:13px;padding:8px 16px}' .
        '.process-row{grid-template-columns:1fr 1fr}' .
    '}' .

    /* ── MOBILE ≤768 ── */
    '@media(max-width:768px){' .
        '.hero-v2{padding:100px 16px 30px;width:100vw;left:50%;margin-left:-50vw;margin-right:-50vw}' .
        '.hero-v2 .hero-inner-c{max-width:100%;padding:0 4px}' .
        '.hero-v2 .hero-h1{font-size:clamp(28px,7vw,38px);line-height:1.15}' .
        '.hero-v2 .hero-desc{font-size:14px;line-height:1.7}' .
        '.hero-v2 .hero-dashboard-wrap{display:none}' .
        '.hero-v2 .hero-marquee{margin:0 -16px 24px}' .
        '.hero-v2 .hm-item{font-    size:13px}' .
        '.hero-v2 .hero-actions{flex-direction:column;align-items:center;gap:12px}' .
        '.hero-v2 .btn-primary{width:100%;max-width:320px;text-align:center;justify-content:center}' .
        '.trust-bar{padding:16px}' .
        '.trust-bar-inner{gap:16px 24px}' .
        '.trust-item{font-size:12px}' .
        '.sec{padding:48px 16px}' .
        '.wrap{padding:0 16px}' .
        '.sec-title{font-size:clamp(26px,5vw,36px)}' .
        '.sec-sub{font-size:14px}' .
        '.metrics-grid{grid-template-columns:1fr 1fr}' .
        '.metric-num{font-size:clamp(28px,5vw,36px)}' .
        '.why-grid{grid-template-columns:1fr;gap:16px}' .
        '.method-grid{grid-template-columns:1fr;gap:20px}' .
        '.courses-grid{grid-template-columns:1fr;gap:20px}' .
        '.instructors-grid{grid-template-columns:1fr;gap:16px}' .
        '.inst-card{padding:24px 20px}' .
        '.process-row{grid-template-columns:1fr;gap:16px}' .
        '.footer-grid{grid-template-columns:1fr 1fr;gap:32px}' .
        '.footer-bar{flex-direction:column;gap:8px;text-align:center}' .
    '}' .

    /* ── SMALL MOBILE ≤540 ── */
    '@media(max-width:540px){' .
        '.hero-v2 .hero-h1{font-size:26px}' .
        '.hero-v2{padding:90px 12px 24px}' .
        '.sec{padding:40px 12px}' .
        '.wrap{padding:0 12px}' .
        '.metrics-grid{grid-template-columns:1fr}' .
        '.metric+.metric::before{display:none}' .
        '.metric{border-top:1px solid var(--b1);padding:16px 12px}' .
        '.metric:first-child{border-top:none}' .
        '.footer-grid{grid-template-columns:1fr;gap:24px}' .
        '.trust-bar-inner{flex-direction:column;gap:12px;align-items:flex-start}' .
        '.course-card{padding:24px 18px}' .
        '.btn-primary,.btn-lg{font-size:15px;padding:14px 24px}' .
    '}' .

    '</style>' . "\n";
}, 99);

/* 9) Fix heading order: footer h4 -> h3 vía JS (Kadence footer builder) */
add_action('wp_footer', function () {
    echo '<script>document.querySelectorAll("footer h4,.site-footer h4,.footer-col h4").forEach(function(h){var n=document.createElement("h3");n.className=h.className;n.innerHTML=h.innerHTML;n.style.cssText=h.style.cssText;h.parentNode.replaceChild(n,h)})</script>' . "\n";
}, 99);

/* 10) Resize avatar/logo images server-side on upload (for future uploads) */
add_filter('wp_generate_attachment_metadata', function ($metadata, $attachment_id) {
    if (!isset($metadata['sizes'])) return $metadata;
    $custom_sizes = [
        'avatar-thumb' => ['width' => 144, 'height' => 144, 'crop' => true],
        'logo-thumb'   => ['width' => 88,  'height' => 88,  'crop' => true],
    ];
    $file = get_attached_file($attachment_id);
    if (!$file) return $metadata;
    $editor = wp_get_image_editor($file);
    if (is_wp_error($editor)) return $metadata;
    foreach ($custom_sizes as $name => $size) {
        $editor2 = wp_get_image_editor($file);
        if (is_wp_error($editor2)) continue;
        $editor2->resize($size['width'], $size['height'], $size['crop']);
        $info = pathinfo($file);
        $resized = $editor2->save($info['dirname'] . '/' . $info['filename'] . '-' . $size['width'] . 'x' . $size['height'] . '.' . $info['extension']);
        if (!is_wp_error($resized)) {
            $metadata['sizes'][$name] = [
                'file'      => basename($resized['path']),
                'width'     => $resized['width'],
                'height'    => $resized['height'],
                'mime-type' => $resized['mime-type'],
            ];
        }
    }
    return $metadata;
}, 10, 2);
