<?php

return [
    'autoload' => false,
    'hooks' => [
        'app_init' => [
            'alioss',
        ],
        'module_init' => [
            'alioss',
        ],
        'upload_config_init' => [
            'alioss',
        ],
        'upload_delete' => [
            'alioss',
        ],
        'sms_send' => [
            'alisms',
        ],
        'sms_notice' => [
            'alisms',
        ],
        'sms_check' => [
            'alisms',
        ],
        'epay_config_init' => [
            'epay',
        ],
        'addon_action_begin' => [
            'epay',
        ],
        'action_begin' => [
            'epay',
        ],
        'config_init' => [
            'markdown',
        ],
    ],
    'route' => [],
    'priority' => [],
    'domain' => '',
];
