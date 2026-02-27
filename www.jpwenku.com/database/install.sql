-- ============================================
-- AI背单词应用 - 完整安装SQL
-- 
-- 使用方法：
-- 1. 创建数据库: CREATE DATABASE your_db_name DEFAULT CHARSET utf8mb4;
-- 2. 导入此文件: mysql -u root -p your_db_name < install.sql
-- 3. 导入种子词库: mysql -u root -p your_db_name < seed_data.sql (可选)
-- 4. 安装FastAdmin框架表（如果是全新安装）
-- ============================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================
-- 业务表（9张）
-- ============================================

CREATE TABLE IF NOT EXISTS `fa_user` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `mobile` varchar(11) NOT NULL COMMENT '手机号',
  `nickname` varchar(50) DEFAULT NULL COMMENT '昵称',
  `avatar` varchar(255) DEFAULT NULL COMMENT '头像',
  `created_at` int(11) DEFAULT NULL,
  `updated_at` int(11) DEFAULT NULL,
  `status` enum('normal','hidden') DEFAULT 'normal',
  PRIMARY KEY (`id`),
  UNIQUE KEY `mobile` (`mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

CREATE TABLE IF NOT EXISTS `fa_sms_code` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `mobile` varchar(11) NOT NULL,
  `code` varchar(6) NOT NULL,
  `ip` varchar(45) NOT NULL DEFAULT '',
  `created_at` int(11) NOT NULL,
  `expired_at` int(11) NOT NULL,
  `used` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_mobile` (`mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短信验证码表';

CREATE TABLE IF NOT EXISTS `fa_word` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `word` varchar(100) NOT NULL COMMENT '单词',
  `phonetic` varchar(100) DEFAULT NULL COMMENT '音标',
  `part_of_speech` varchar(20) DEFAULT NULL COMMENT '词性',
  `definition` text NOT NULL COMMENT '释义',
  `example` text DEFAULT NULL COMMENT '例句',
  `created_at` int(11) DEFAULT NULL,
  `updated_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_word` (`word`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='单词表';

CREATE TABLE IF NOT EXISTS `fa_vocabulary_list` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL COMMENT '词表名称',
  `description` text DEFAULT NULL COMMENT '描述',
  `category` varchar(50) DEFAULT NULL COMMENT '分类',
  `difficulty_level` tinyint(1) DEFAULT 1 COMMENT '难度1-5',
  `word_count` int(11) DEFAULT 0 COMMENT '单词数',
  `is_official` tinyint(1) DEFAULT 1 COMMENT '是否官方词表',
  `created_at` int(11) DEFAULT NULL,
  `updated_at` int(11) DEFAULT NULL,
  `status` enum('normal','hidden') DEFAULT 'normal',
  PRIMARY KEY (`id`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='词表定义表';

CREATE TABLE IF NOT EXISTS `fa_vocabulary_list_word` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `vocabulary_list_id` int(11) unsigned NOT NULL,
  `word_id` int(11) unsigned NOT NULL,
  `sort_order` int(11) DEFAULT 0 COMMENT '排序',
  `created_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_list_word` (`vocabulary_list_id`, `word_id`),
  KEY `idx_word_id` (`word_id`),
  CONSTRAINT `fk_vlw_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_vlw_word` FOREIGN KEY (`word_id`) REFERENCES `fa_word` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='词表单词关联表';

CREATE TABLE IF NOT EXISTS `fa_user_vocabulary_list` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) unsigned NOT NULL,
  `vocabulary_list_id` int(11) unsigned NOT NULL,
  `downloaded_at` int(11) DEFAULT NULL,
  `is_custom` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_list` (`user_id`, `vocabulary_list_id`),
  CONSTRAINT `fk_uvl_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uvl_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户词表关联表';

CREATE TABLE IF NOT EXISTS `fa_user_word_progress` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) unsigned NOT NULL,
  `word_id` int(11) unsigned NOT NULL,
  `vocabulary_list_id` int(11) unsigned NOT NULL,
  `status` enum('not_learned','mastered','need_review') DEFAULT 'not_learned',
  `learned_at` int(11) DEFAULT NULL,
  `last_review_at` int(11) DEFAULT NULL,
  `next_review_at` int(11) DEFAULT NULL,
  `review_count` int(11) DEFAULT 0,
  `error_count` int(11) DEFAULT 0,
  `memory_level` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_word_list` (`user_id`, `word_id`, `vocabulary_list_id`),
  KEY `idx_next_review_at` (`next_review_at`),
  CONSTRAINT `fk_uwp_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwp_word` FOREIGN KEY (`word_id`) REFERENCES `fa_word` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwp_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学习进度表';

CREATE TABLE IF NOT EXISTS `fa_user_word_exclusion` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) unsigned NOT NULL,
  `word_id` int(11) unsigned NOT NULL,
  `vocabulary_list_id` int(11) unsigned NOT NULL,
  `excluded_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_word_list` (`user_id`, `word_id`, `vocabulary_list_id`),
  CONSTRAINT `fk_uwe_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwe_word` FOREIGN KEY (`word_id`) REFERENCES `fa_word` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwe_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='单词排除表';

CREATE TABLE IF NOT EXISTS `fa_user_statistics` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(11) unsigned NOT NULL,
  `total_days` int(11) DEFAULT 0,
  `continuous_days` int(11) DEFAULT 0,
  `total_words_learned` int(11) DEFAULT 0,
  `total_words_mastered` int(11) DEFAULT 0,
  `last_learn_date` date DEFAULT NULL,
  `updated_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id` (`user_id`),
  CONSTRAINT `fk_us_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学习统计表';

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================
-- 后台菜单（fa_auth_rule）
-- 注意：pid 需要根据实际安装后的 ID 调整
-- 这里用 pid=0 表示顶级菜单
-- ============================================

-- 词表管理菜单
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES
('menu', 0, 'vocabulary_list', '词表管理', 'fa fa-book', '', '管理词表和单词', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 90, 'normal');

SET @vl_pid = LAST_INSERT_ID();

INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES
('file', @vl_pid, 'vocabulary_list/index', '查看', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/add', '添加', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/edit', '编辑', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/del', '删除', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal');

-- OCR配置菜单
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES ('menu', 0, 'ocr/setting', 'OCR配置', 'fa fa-camera', '', 'OCR识别服务配置', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 80, 'normal');

-- 词库导出菜单
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES ('menu', 0, 'dataexport/index', '词库导出', 'fa fa-database', '', '导出词库种子数据', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 70, 'normal');

-- ============================================
-- OCR系统配置（fa_config）
-- 首次访问后台OCR配置页面时也会自动创建
-- ============================================

-- 在 configgroup 中添加 ocr 分组（需要先查询当前值再更新，这里提供参考）
-- UPDATE `fa_config` SET `value` = JSON_SET(`value`, '$.ocr', 'OCR识别') WHERE `name` = 'configgroup';

INSERT INTO `fa_config` (`name`, `group`, `title`, `tip`, `type`, `visible`, `value`, `content`, `rule`, `extend`)
VALUES
('ocr_provider', 'ocr', 'OCR服务商', '当前仅支持百度OCR', 'select', '', 'baidu', '{"baidu":"百度OCR"}', 'required', ''),
('ocr_baidu_app_id', 'ocr', '百度App ID', '百度智能云OCR应用的App ID', 'string', '', '', '', '', ''),
('ocr_baidu_api_key', 'ocr', '百度API Key', '百度智能云OCR应用的API Key', 'string', '', '', '', 'required', ''),
('ocr_baidu_secret_key', 'ocr', '百度Secret Key', '百度智能云OCR应用的Secret Key', 'string', '', '', '', 'required', ''),
('ocr_max_image_size', 'ocr', '最大图片大小(字节)', '默认4MB=4194304', 'number', '', '4194304', '', '', '')
ON DUPLICATE KEY UPDATE `name` = `name`;
