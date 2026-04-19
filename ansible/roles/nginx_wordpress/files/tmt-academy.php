<?php
/**
 * Plugin Name: TMT Academy Branding
 * Description: Aplica el branding de Two Minds Trading a la academy (Kadence + LearnDash).
 * Version: 1.0.0
 * Author: Two Minds Trading
 */

if (!defined('ABSPATH')) exit;

add_action('wp_head', function () {
    echo '<style id="tmt-academy-brand">
:root {
    --tmt-bg: #060b14;
    --tmt-bg-nav: #0a0e1a;
    --tmt-bg-card: #0f1a2e;
    --tmt-bg-footer: #0a1220;
    --tmt-bg-tag: #122836;
    --tmt-text: #f0f6fc;
    --tmt-text-muted: #8fa4be;
    --tmt-accent: #00d4f5;
    --tmt-accent-hover: #00b8d4;
    --tmt-tag-color: #45c7df;
    --tmt-border: rgba(255,255,255,0.05);
    --tmt-radius: 28px;
    --tmt-radius-sm: 16px;
    --tmt-radius-pill: 100px;
}

html, body {
    background: var(--tmt-bg) !important;
    color: var(--tmt-text) !important;
    font-family: "Outfit", system-ui, sans-serif !important;
}

h1, h2, h3, h4, h5, h6,
.entry-title,
.ld-heading,
.learndash-wrapper h2,
.learndash-wrapper h3 {
    color: var(--tmt-text) !important;
    font-family: "Outfit", system-ui, sans-serif !important;
    font-weight: 900 !important;
}

p, li, td, th, span, label,
.entry-content,
.learndash-wrapper p,
.learndash-wrapper li {
    color: var(--tmt-text-muted) !important;
    font-family: "Outfit", system-ui, sans-serif !important;
}

a { color: var(--tmt-accent) !important; }
a:hover { color: var(--tmt-accent-hover) !important; }

/* Header / Nav */
#masthead,
.site-header,
header.banner,
.wp-site-blocks > header {
    background: var(--tmt-bg-nav) !important;
    border-bottom: 1px solid var(--tmt-border) !important;
}

.site-title, .site-title a,
.custom-logo-link { color: var(--tmt-text) !important; }

.site-header .navigation a,
.site-header .menu a,
.main-navigation a,
#masthead a {
    color: var(--tmt-text) !important;
    font-weight: 500 !important;
}
#masthead a:hover,
.main-navigation a:hover { color: var(--tmt-accent) !important; }

/* Footer */
footer, .site-footer,
.wp-site-blocks > footer {
    background: var(--tmt-bg-footer) !important;
    border-top: 1px solid var(--tmt-border) !important;
}

footer a, .site-footer a { color: var(--tmt-text-muted) !important; }
footer a:hover, .site-footer a:hover { color: var(--tmt-accent) !important; }

/* Content areas */
#inner-wrap, .site-container,
.content-area, .site-main,
main, article, .entry-content,
.wp-site-blocks {
    background: transparent !important;
}

/* Cards */
.learndash-wrapper .ld-item-list .ld-item-list-item,
.learndash-wrapper .ld-table-list .ld-table-list-item,
.ld-course-list-items .ld-item-list-item,
.learndash-wrapper .ld-focus .ld-focus-sidebar,
.wp-block-kadence-pane,
.kt-accordion-panel,
.entry-content .wp-block-group {
    background: var(--tmt-bg-card) !important;
    border: 1px solid var(--tmt-border) !important;
    border-radius: var(--tmt-radius-sm) !important;
}

/* LearnDash specifics */
.learndash-wrapper .ld-focus .ld-focus-header {
    background: var(--tmt-bg-nav) !important;
    border-bottom: 1px solid var(--tmt-border) !important;
}

.learndash-wrapper .ld-focus .ld-focus-sidebar {
    background: var(--tmt-bg-nav) !important;
}

.learndash-wrapper .ld-focus .ld-focus-content {
    background: var(--tmt-bg) !important;
}

.learndash-wrapper .ld-progress .ld-progress-bar .ld-progress-bar-percentage {
    background: var(--tmt-accent) !important;
}

.learndash-wrapper .ld-progress .ld-progress-bar {
    background: rgba(255,255,255,0.08) !important;
}

.learndash-wrapper .ld-status.ld-status-complete {
    background: var(--tmt-accent) !important;
    color: #000 !important;
}

.learndash-wrapper .ld-status.ld-status-incomplete {
    background: var(--tmt-bg-tag) !important;
    color: var(--tmt-tag-color) !important;
}

.learndash-wrapper .ld-item-list .ld-item-list-item a,
.learndash-wrapper .ld-lesson-item a,
.learndash-wrapper .ld-topic-list a {
    color: var(--tmt-text) !important;
}
.learndash-wrapper .ld-item-list .ld-item-list-item a:hover {
    color: var(--tmt-accent) !important;
}

.learndash-wrapper .ld-expand-button,
.learndash-wrapper .ld-item-list .ld-item-list-item .ld-item-details {
    color: var(--tmt-text-muted) !important;
}

/* Buttons - primary */
.learndash-wrapper .ld-button,
.learndash-wrapper #btn-join,
.learndash-wrapper input[type="submit"],
.wp-block-button__link,
.button.primary,
.kb-button,
input[type="submit"] {
    background: var(--tmt-accent) !important;
    color: #000 !important;
    border: none !important;
    border-radius: var(--tmt-radius-pill) !important;
    font-weight: 700 !important;
    font-family: "Outfit", system-ui, sans-serif !important;
    padding: 12px 28px !important;
    transition: background 0.2s !important;
}
.learndash-wrapper .ld-button:hover,
.wp-block-button__link:hover,
.kb-button:hover,
input[type="submit"]:hover {
    background: var(--tmt-accent-hover) !important;
}

/* Buttons - secondary */
.learndash-wrapper .ld-button.ld-button-reverse,
.button.secondary {
    background: transparent !important;
    color: var(--tmt-accent) !important;
    border: 1px solid var(--tmt-accent) !important;
}

/* Forms */
input[type="text"],
input[type="email"],
input[type="password"],
input[type="search"],
textarea, select {
    background: var(--tmt-bg-card) !important;
    color: var(--tmt-text) !important;
    border: 1px solid var(--tmt-border) !important;
    border-radius: var(--tmt-radius-sm) !important;
    font-family: "Outfit", system-ui, sans-serif !important;
}
input:focus, textarea:focus, select:focus {
    border-color: var(--tmt-accent) !important;
    outline: none !important;
    box-shadow: 0 0 0 2px rgba(0,212,245,0.15) !important;
}

/* Login form */
.learndash-wrapper .ld-login-modal,
.ld-modal .ld-modal-dialog {
    background: var(--tmt-bg-card) !important;
    border: 1px solid var(--tmt-border) !important;
    border-radius: var(--tmt-radius) !important;
}

/* Tables */
table, .learndash-wrapper table {
    border-color: var(--tmt-border) !important;
}
table th {
    background: var(--tmt-bg-nav) !important;
    color: var(--tmt-text) !important;
}
table td {
    background: var(--tmt-bg-card) !important;
    border-color: var(--tmt-border) !important;
}

/* Breadcrumbs */
.kadence-breadcrumbs, .kadence-breadcrumbs a,
.learndash-wrapper .ld-breadcrumbs,
.learndash-wrapper .ld-breadcrumbs a {
    color: var(--tmt-text-muted) !important;
}

/* Tags / Badges */
.ld-status, .learndash-wrapper .ld-status {
    border-radius: var(--tmt-radius-pill) !important;
    font-weight: 600 !important;
}

/* Video embed wrappers */
.learndash-wrapper .ld-video,
.wp-block-embed__wrapper {
    border-radius: var(--tmt-radius-sm) !important;
    overflow: hidden !important;
}

/* Quiz styles */
.learndash-wrapper .wpProQuiz_content {
    background: var(--tmt-bg-card) !important;
    border-radius: var(--tmt-radius-sm) !important;
    padding: 24px !important;
}
.learndash-wrapper .wpProQuiz_question {
    background: transparent !important;
}

/* Scrollbar */
::-webkit-scrollbar { width: 8px; }
::-webkit-scrollbar-track { background: var(--tmt-bg); }
::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.2); }

/* Selection */
::selection { background: rgba(0,212,245,0.3); color: var(--tmt-text); }

/* WP Admin bar fix */
#wpadminbar { background: var(--tmt-bg-nav) !important; }

</style>' . "\n";
}, 99);

/* Enqueue Google Font: Outfit */
add_action('wp_enqueue_scripts', function () {
    wp_enqueue_style('tmt-outfit-font', 'https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;900&display=swap', [], null);
}, 5);

/* Fix site title */
add_filter('bloginfo', function ($output, $show) {
    if ($show === 'name') return 'Two Minds Trading Academy';
    return $output;
}, 10, 2);

/* Remove default tagline */
add_filter('bloginfo', function ($output, $show) {
    if ($show === 'description') return 'Formación profesional de trading con Order Flow y Gamma Exposure';
    return $output;
}, 10, 2);
