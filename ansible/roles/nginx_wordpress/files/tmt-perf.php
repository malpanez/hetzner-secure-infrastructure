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

/* 5) Preload de la imagen LCP del hero (actualizar URL al cambiar el hero) */
define('TMT_HERO_IMAGE', 'https://twomindstrading.com/wp-content/uploads/2026/04/unnamed-22.jpg');
add_action('wp_head', function () {
    if (!is_front_page()) return;
    echo '<link rel="preload" as="image" href="' . TMT_HERO_IMAGE . '" fetchpriority="high">' . "\n";
}, 2);

/* 5b) Google Fonts: preconnect + carga diferida (evita render-blocking) */
add_action('wp_head', function () {
    echo '<link rel="preconnect" href="https://fonts.googleapis.com">' . "\n";
    echo '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' . "\n";
    echo '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=Rethink+Sans:ital,wght@0,400;0,600;0,700;0,800;1,400&family=Lexend:wght@400;600;700&display=swap" media="print" onload="this.media=\'all\'">' . "\n";
    echo '<noscript><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=Rethink+Sans:ital,wght@0,400;0,600;0,700;0,800;1,400&family=Lexend:wght@400;600;700&display=swap"></noscript>' . "\n";
}, 3);

/* 5c) DNS prefetch para terceros (Calendly, Stripe, Cloudflare) */
add_action('wp_head', function () {
    $origins = [
        'https://assets.calendly.com',
        'https://js.stripe.com',
        'https://cdnjs.cloudflare.com',
    ];
    foreach ($origins as $o) {
        echo '<link rel="dns-prefetch" href="' . $o . '">' . "\n";
    }
}, 4);

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

/* 8) Critical CLS-prevention CSS + cookie button contrast fix */
add_action('wp_head', function () {
    echo '<style>' .
        '#cookie-notice{position:fixed!important;bottom:0;left:0;right:0;z-index:10000;width:100%}' .
        '.cn-button{background-color:#00c9b7!important;color:#000!important;font-weight:600!important}' .
        '.nav-logo img{width:44px;height:44px}' .
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