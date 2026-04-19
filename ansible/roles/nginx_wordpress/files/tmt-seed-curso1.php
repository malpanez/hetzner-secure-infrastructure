<?php
/**
 * TMT LearnDash Course Seeder — Order Flow para Principiantes
 *
 * USO: Copiar a mu-plugins, cargar cualquier pagina del admin UNA VEZ,
 *      luego borrar el archivo. Crea el curso + lecciones + temas.
 *
 * IMPORTANTE: Ejecutar solo una vez. Si se ejecuta dos veces, duplicará contenido.
 */

if (!defined('ABSPATH')) exit;

add_action('admin_init', function () {

    if (get_option('tmt_curso1_seeded')) return;

    $course_id = wp_insert_post([
        'post_title'   => 'Order Flow para Principiantes',
        'post_type'    => 'sfwd-courses',
        'post_status'  => 'publish',
        'post_content' => 'Curso completo de Order Flow desde cero. Enfoque práctico, visual y progresivo. Incluye videos, PDFs, ejercicios, glosario interactivo y comunidad.',
    ]);
    if (!$course_id || is_wp_error($course_id)) return;

    update_post_meta($course_id, '_sfwd-courses', [
        'sfwd-courses_course_materials'       => '',
        'sfwd-courses_course_price_type'      => 'closed',
        'sfwd-courses_course_prerequisite_enabled' => '',
    ]);

    $lessons = [
        [
            'title' => 'Módulo 0: Bienvenida e Instalación',
            'content' => 'Objetivo: Preparar el entorno para operar. Familiarizarse con las herramientas que usaremos durante todo el curso.',
            'topics' => [
                ['title' => '¿Qué es el Order Flow?', 'content' => 'Diferencia con el análisis técnico clásico. Metáforas visuales para entender el concepto.'],
                ['title' => 'Qué necesito para empezar', 'content' => 'PC, cuenta demo (sin riesgo), plataforma ATAS o Bookmap.'],
                ['title' => 'Instalación paso a paso de ATAS', 'content' => 'Video paso a paso con la instalación y configuración básica: gráfico, volumen, DOM.'],
                ['title' => 'Comparativa de plataformas', 'content' => 'Bonus: ATAS vs Bookmap — ventajas y desventajas de cada una.'],
                ['title' => 'Glosario visual', 'content' => 'Los 12 conceptos clave del curso. PDF descargable.'],
            ],
        ],
        [
            'title' => 'Módulo 1: Conceptos Básicos del Mercado',
            'content' => 'Objetivo: Comprender qué vamos a operar. Índices, futuros, CFDs y cuentas fondeadas.',
            'topics' => [
                ['title' => 'Índices: S&P 500 y Nasdaq 100', 'content' => 'Qué son los índices y por qué los operamos.'],
                ['title' => 'Qué es un contrato de futuro', 'content' => 'Explicación clara con ejemplos del ES y NQ.'],
                ['title' => 'Spot vs Futuro vs CFD', 'content' => 'Comparaciones visuales entre los tres tipos de instrumentos.'],
                ['title' => 'Qué es una cuenta fondeada', 'content' => 'Cómo funcionan las prop firms y cómo acceder a capital.'],
            ],
        ],
        [
            'title' => 'Módulo 2: Gestión Monetaria y Plan de Trading',
            'content' => 'Objetivo: Proteger tu capital y establecer reglas claras antes de operar.',
            'topics' => [
                ['title' => 'Money Management', 'content' => 'Riesgo por operación: 0.5% – 1%. Cómo calcular el tamaño de posición.'],
                ['title' => 'Límite diario de pérdida y ganancia', 'content' => 'Reglas para protegerte de ti mismo. Cuándo parar de operar.'],
                ['title' => 'Diario de Trading y autoevaluación', 'content' => 'Cómo llevar un diario útil. Plantilla editable incluida.'],
                ['title' => 'Crea tu propio plan operativo', 'content' => 'Paso a paso para construir tu plan. Ejemplo rellenado como referencia.'],
            ],
        ],
        [
            'title' => 'Módulo 3: Niveles Relevantes',
            'content' => 'Objetivo: Detectar zonas clave de reacción del precio. Los niveles donde los institucionales actúan.',
            'topics' => [
                ['title' => 'YHOD / YLOD / YGAP / HALFGAP', 'content' => 'Los niveles del día anterior y los gaps. Cómo marcarlos cada día.'],
                ['title' => 'ONH / ONL — Overnight High & Low', 'content' => 'Los niveles de la sesión nocturna y su relevancia.'],
                ['title' => 'Initial Balance y proyecciones', 'content' => 'IB, IB+25, IB+50. Cómo calcularlos y usarlos como objetivo.'],
                ['title' => 'Volume Profile: POC / VAH / VAL / HVN / LVN', 'content' => 'Lectura del perfil de volumen. Zonas de valor y nodos de alto/bajo volumen.'],
            ],
        ],
        [
            'title' => 'Módulo 4: Introducción al Footprint y DOM',
            'content' => 'Objetivo: Leer la acción real del mercado. Compradores vs vendedores en tiempo real.',
            'topics' => [
                ['title' => 'Qué es el DOM y cómo leerlo', 'content' => 'El libro de órdenes explicado de forma visual. Bid vs Ask.'],
                ['title' => 'Qué muestra un gráfico Footprint', 'content' => 'Anatomía del Footprint. Cómo leer volumen por nivel de precio.'],
                ['title' => 'Primeros patrones: volumen seco y clúster', 'content' => 'Detectar absorciones, agotamiento y acumulación de volumen.'],
                ['title' => 'Ejercicios: ¿Qué ves aquí?', 'content' => 'Casos reales con pausas para practicar la lectura del Footprint.'],
            ],
        ],
        [
            'title' => 'Módulo 5: Lectura del Contexto del Mercado',
            'content' => 'Objetivo: Entender qué está haciendo el mercado antes de operar. Leer el escenario completo.',
            'topics' => [
                ['title' => 'Rango vs Tendencia', 'content' => 'Identificar si el mercado está en consolidación o en movimiento direccional.'],
                ['title' => 'Volumen creciente o agotamiento', 'content' => 'Cómo el volumen confirma o invalida un movimiento.'],
                ['title' => 'Apertura, rompimiento, consolidación', 'content' => 'Los tres escenarios típicos y cómo operar cada uno.'],
                ['title' => 'Lectura del mercado como escenario', 'content' => 'Cómo combinar todos los elementos para construir un escenario operativo.'],
            ],
        ],
        [
            'title' => 'Módulo 6: Operativa en Vivo y Ejercicios',
            'content' => 'Objetivo: Aplicar todo lo aprendido en condiciones reales de mercado.',
            'topics' => [
                ['title' => 'Sesiones de trading comentadas', 'content' => 'Videos pausados de operativa real con explicación de entradas y salidas.'],
                ['title' => 'Entradas por absorción + niveles', 'content' => 'Cómo combinar la lectura del Footprint con los niveles relevantes.'],
                ['title' => 'Justificación de escenarios', 'content' => 'Plantilla para documentar y justificar cada entrada antes de ejecutar.'],
                ['title' => 'Revisión de errores', 'content' => 'Hoja de revisión editable. Autoevaluación diaria y semanal.'],
            ],
        ],
        [
            'title' => 'Bonus 1: Errores Comunes de Principiantes',
            'content' => 'Objetivo: Evitar las trampas típicas que cometen los traders nuevos.',
            'topics' => [
                ['title' => 'No operar sin plan', 'content' => 'El error más común. Por qué necesitas reglas antes de abrir la plataforma.'],
                ['title' => 'No seguir la cinta sin contexto', 'content' => 'El Time & Sales sin contexto es ruido. Cómo filtrarlo.'],
                ['title' => 'No operar solo por absorción', 'content' => 'Una absorción sin confluencia no es señal. Necesitas más.'],
            ],
        ],
        [
            'title' => 'Bonus 2: Checklist de Entrada Mental',
            'content' => 'Objetivo: Ayudarte a tomar mejores decisiones antes de cada operación.',
            'topics' => [
                ['title' => '¿Estoy operando con contexto?', 'content' => 'Verificar que tienes escenario antes de buscar entrada.'],
                ['title' => '¿Confluencia entre volumen, nivel y DOM?', 'content' => 'Al menos 2 de 3 factores deben coincidir.'],
                ['title' => '¿El riesgo es aceptable?', 'content' => 'Verificar stop, tamaño de posición y límite diario antes de entrar.'],
            ],
        ],
        [
            'title' => 'Retos Semanales',
            'content' => 'Objetivo: Consolidar hábitos con práctica progresiva. Entregable opcional para la comunidad.',
            'topics' => [
                ['title' => 'Semana 1: Solo observar niveles', 'content' => 'Marcar YHOD, YLOD, POC, VAH, VAL cada día sin operar.'],
                ['title' => 'Semana 2: Detectar absorciones', 'content' => 'Identificar absorciones en el Footprint durante la sesión. Anotar en el diario.'],
                ['title' => 'Semana 3: Simular entradas con diario', 'content' => 'Paper trading documentado. Justificar cada entrada con la plantilla.'],
            ],
        ],
    ];

    $lesson_order = 1;
    foreach ($lessons as $lesson_data) {
        $lesson_id = wp_insert_post([
            'post_title'   => $lesson_data['title'],
            'post_type'    => 'sfwd-lessons',
            'post_status'  => 'publish',
            'post_content' => $lesson_data['content'],
            'menu_order'   => $lesson_order,
        ]);
        if (!$lesson_id || is_wp_error($lesson_id)) continue;

        update_post_meta($lesson_id, 'course_id', $course_id);
        update_post_meta($lesson_id, '_sfwd-lessons', [
            'sfwd-lessons_course'       => $course_id,
            'sfwd-lessons_lesson_materials' => '',
        ]);

        if (!empty($lesson_data['topics'])) {
            $topic_order = 1;
            foreach ($lesson_data['topics'] as $topic_data) {
                $topic_id = wp_insert_post([
                    'post_title'   => $topic_data['title'],
                    'post_type'    => 'sfwd-topic',
                    'post_status'  => 'publish',
                    'post_content' => $topic_data['content'],
                    'menu_order'   => $topic_order,
                ]);
                if (!$topic_id || is_wp_error($topic_id)) continue;

                update_post_meta($topic_id, 'course_id', $course_id);
                update_post_meta($topic_id, 'lesson_id', $lesson_id);
                update_post_meta($topic_id, '_sfwd-topic', [
                    'sfwd-topic_course' => $course_id,
                    'sfwd-topic_lesson' => $lesson_id,
                ]);
                $topic_order++;
            }
        }
        $lesson_order++;
    }

    learndash_update_setting($course_id, 'course_lesson_order', 'ASC');

    update_option('tmt_curso1_seeded', true);

    add_action('admin_notices', function () {
        echo '<div class="notice notice-success"><p><strong>TMT:</strong> Curso "Order Flow para Principiantes" creado con éxito — 10 lecciones, 37 temas.</p></div>';
    });
});
