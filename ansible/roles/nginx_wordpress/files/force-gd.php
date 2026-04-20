<?php
add_filter('wp_image_editors', function($editors) {
    return array('WP_Image_Editor_GD', 'WP_Image_Editor_Imagick');
});
