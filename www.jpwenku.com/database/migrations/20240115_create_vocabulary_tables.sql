-- ============================================
-- AI背单词应用 - 数据库表结构
-- 创建时间: 2024-01-15
-- 说明: 创建所有9个数据库表，包含表结构、索引、外键约束
-- ============================================

-- 设置字符集
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================
-- 表1: fa_user (用户表 - 复用FastAdmin)
-- 说明: 存储用户基本信息，复用FastAdmin的用户表结构
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_user` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `mobile` varchar(11) NOT NULL COMMENT '手机号',
  `nickname` varchar(50) DEFAULT NULL COMMENT '昵称',
  `avatar` varchar(255) DEFAULT NULL COMMENT '头像URL',
  `created_at` int(11) DEFAULT NULL COMMENT '创建时间(Unix时间戳)',
  `updated_at` int(11) DEFAULT NULL COMMENT '更新时间(Unix时间戳)',
  `status` enum('normal','hidden') DEFAULT 'normal' COMMENT '状态:normal=正常,hidden=隐藏',
  PRIMARY KEY (`id`),
  UNIQUE KEY `mobile` (`mobile`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- ============================================
-- 表2: fa_sms_code (短信验证码表)
-- 说明: 存储短信验证码，用于用户登录验证
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_sms_code` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '验证码ID',
  `mobile` varchar(11) NOT NULL COMMENT '手机号',
  `code` varchar(6) NOT NULL COMMENT '验证码(6位数字)',
  `ip` varchar(45) NOT NULL DEFAULT '' COMMENT '发送IP地址',
  `created_at` int(11) NOT NULL COMMENT '创建时间(Unix时间戳)',
  `expired_at` int(11) NOT NULL COMMENT '过期时间(Unix时间戳)',
  `used` tinyint(1) DEFAULT 0 COMMENT '是否已使用:0=未使用,1=已使用',
  PRIMARY KEY (`id`),
  KEY `idx_mobile` (`mobile`),
  KEY `idx_ip` (`ip`),
  KEY `idx_expired_at` (`expired_at`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='短信验证码表';

-- ============================================
-- 表3: fa_word (全局单词表)
-- 说明: 存储全局共享的单词数据，避免重复存储
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_word` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '单词ID',
  `word` varchar(100) NOT NULL COMMENT '单词文本',
  `phonetic` varchar(100) DEFAULT NULL COMMENT '音标',
  `part_of_speech` varchar(20) DEFAULT NULL COMMENT '词性(如:n.,v.,adj.)',
  `definition` text NOT NULL COMMENT '释义',
  `example` text DEFAULT NULL COMMENT '例句',
  `created_at` int(11) DEFAULT NULL COMMENT '创建时间(Unix时间戳)',
  `updated_at` int(11) DEFAULT NULL COMMENT '更新时间(Unix时间戳)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_word` (`word`),
  KEY `idx_word` (`word`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='全局单词表';

-- ============================================
-- 表4: fa_vocabulary_list (词表定义表)
-- 说明: 存储词表的元信息，包括官方词表和用户自定义词表
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_vocabulary_list` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '词表ID',
  `name` varchar(100) NOT NULL COMMENT '词表名称',
  `description` text DEFAULT NULL COMMENT '词表描述',
  `category` varchar(50) DEFAULT NULL COMMENT '分类(如:CET4,CET6,TOEFL,IELTS,考研,custom)',
  `difficulty_level` tinyint(1) DEFAULT 1 COMMENT '难度级别(1-5):1=最简单,5=最难',
  `word_count` int(11) DEFAULT 0 COMMENT '单词总数',
  `is_official` tinyint(1) DEFAULT 1 COMMENT '是否官方词表:0=自定义,1=官方',
  `created_at` int(11) DEFAULT NULL COMMENT '创建时间(Unix时间戳)',
  `updated_at` int(11) DEFAULT NULL COMMENT '更新时间(Unix时间戳)',
  `status` enum('normal','hidden') DEFAULT 'normal' COMMENT '状态:normal=正常,hidden=隐藏',
  PRIMARY KEY (`id`),
  KEY `idx_category` (`category`),
  KEY `idx_is_official` (`is_official`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='词表定义表';

-- ============================================
-- 表5: fa_vocabulary_list_word (词表单词关联表)
-- 说明: 建立词表和单词的多对多关系，一个单词可以属于多个词表
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_vocabulary_list_word` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '关联ID',
  `vocabulary_list_id` int(11) unsigned NOT NULL COMMENT '词表ID',
  `word_id` int(11) unsigned NOT NULL COMMENT '单词ID',
  `sort_order` int(11) DEFAULT 0 COMMENT '排序顺序(用于顺序学习)',
  `created_at` int(11) DEFAULT NULL COMMENT '创建时间(Unix时间戳)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_list_word` (`vocabulary_list_id`, `word_id`),
  KEY `idx_vocabulary_list_id` (`vocabulary_list_id`),
  KEY `idx_word_id` (`word_id`),
  KEY `idx_sort_order` (`sort_order`),
  CONSTRAINT `fk_vlw_vocabulary_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_vlw_word` FOREIGN KEY (`word_id`) REFERENCES `fa_word` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='词表单词关联表';

-- ============================================
-- 表6: fa_user_vocabulary_list (用户词表关联表)
-- 说明: 记录用户下载或创建的词表
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_user_vocabulary_list` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '关联ID',
  `user_id` int(11) unsigned NOT NULL COMMENT '用户ID',
  `vocabulary_list_id` int(11) unsigned NOT NULL COMMENT '词表ID',
  `downloaded_at` int(11) DEFAULT NULL COMMENT '下载时间(Unix时间戳)',
  `is_custom` tinyint(1) DEFAULT 0 COMMENT '是否自定义词表:0=下载的官方词表,1=用户自定义',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_list` (`user_id`, `vocabulary_list_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_vocabulary_list_id` (`vocabulary_list_id`),
  KEY `idx_downloaded_at` (`downloaded_at`),
  CONSTRAINT `fk_uvl_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uvl_vocabulary_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户词表关联表';

-- ============================================
-- 表7: fa_user_word_progress (用户单词学习进度表)
-- 说明: 记录用户对每个单词的学习进度和复习计划
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_user_word_progress` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '进度ID',
  `user_id` int(11) unsigned NOT NULL COMMENT '用户ID',
  `word_id` int(11) unsigned NOT NULL COMMENT '单词ID',
  `vocabulary_list_id` int(11) unsigned NOT NULL COMMENT '词表ID',
  `status` enum('not_learned','mastered','need_review') DEFAULT 'not_learned' COMMENT '学习状态:not_learned=未学习,mastered=已掌握,need_review=需复习',
  `learned_at` int(11) DEFAULT NULL COMMENT '首次学习时间(Unix时间戳)',
  `last_review_at` int(11) DEFAULT NULL COMMENT '最后复习时间(Unix时间戳)',
  `next_review_at` int(11) DEFAULT NULL COMMENT '下次复习时间(Unix时间戳)',
  `review_count` int(11) DEFAULT 0 COMMENT '复习次数',
  `error_count` int(11) DEFAULT 0 COMMENT '错误次数(标记为不认识/忘记的次数)',
  `memory_level` tinyint(1) DEFAULT 0 COMMENT '记忆级别(0-5):0=未学习,1-5对应记忆曲线节点',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_word_list` (`user_id`, `word_id`, `vocabulary_list_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_word_id` (`word_id`),
  KEY `idx_vocabulary_list_id` (`vocabulary_list_id`),
  KEY `idx_next_review_at` (`next_review_at`),
  KEY `idx_status` (`status`),
  KEY `idx_memory_level` (`memory_level`),
  CONSTRAINT `fk_uwp_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwp_word` FOREIGN KEY (`word_id`) REFERENCES `fa_word` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwp_vocabulary_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户单词学习进度表';

-- ============================================
-- 表8: fa_user_word_exclusion (用户单词排除表)
-- 说明: 记录用户在特定词表中删除(排除)的单词，实现软删除
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_user_word_exclusion` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '排除ID',
  `user_id` int(11) unsigned NOT NULL COMMENT '用户ID',
  `word_id` int(11) unsigned NOT NULL COMMENT '单词ID',
  `vocabulary_list_id` int(11) unsigned NOT NULL COMMENT '词表ID',
  `excluded_at` int(11) DEFAULT NULL COMMENT '排除时间(Unix时间戳)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_word_list` (`user_id`, `word_id`, `vocabulary_list_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_word_id` (`word_id`),
  KEY `idx_vocabulary_list_id` (`vocabulary_list_id`),
  KEY `idx_excluded_at` (`excluded_at`),
  CONSTRAINT `fk_uwe_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwe_word` FOREIGN KEY (`word_id`) REFERENCES `fa_word` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_uwe_vocabulary_list` FOREIGN KEY (`vocabulary_list_id`) REFERENCES `fa_vocabulary_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户单词排除表';

-- ============================================
-- 表9: fa_user_statistics (用户学习统计表)
-- 说明: 记录用户的学习统计数据，用于展示学习进度和成就
-- ============================================
CREATE TABLE IF NOT EXISTS `fa_user_statistics` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT COMMENT '统计ID',
  `user_id` int(11) unsigned NOT NULL COMMENT '用户ID',
  `total_days` int(11) DEFAULT 0 COMMENT '总学习天数',
  `continuous_days` int(11) DEFAULT 0 COMMENT '连续学习天数',
  `total_words_learned` int(11) DEFAULT 0 COMMENT '总学习单词数',
  `total_words_mastered` int(11) DEFAULT 0 COMMENT '已掌握单词数',
  `last_learn_date` date DEFAULT NULL COMMENT '最后学习日期',
  `updated_at` int(11) DEFAULT NULL COMMENT '更新时间(Unix时间戳)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id` (`user_id`),
  KEY `idx_last_learn_date` (`last_learn_date`),
  KEY `idx_updated_at` (`updated_at`),
  CONSTRAINT `fk_us_user` FOREIGN KEY (`user_id`) REFERENCES `fa_user` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户学习统计表';

-- ============================================
-- 恢复外键检查
-- ============================================
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================
-- 说明文档
-- ============================================
-- 
-- 表关系说明:
-- 1. fa_user: 用户基础表，所有用户相关数据的根表
-- 2. fa_sms_code: 独立的验证码表，不与其他表关联
-- 3. fa_word: 全局单词表，所有单词的唯一来源
-- 4. fa_vocabulary_list: 词表定义表，描述词表元信息
-- 5. fa_vocabulary_list_word: 词表和单词的多对多关联表
-- 6. fa_user_vocabulary_list: 用户和词表的多对多关联表
-- 7. fa_user_word_progress: 用户学习进度表，记录每个用户对每个单词的学习状态
-- 8. fa_user_word_exclusion: 用户单词排除表，实现软删除功能
-- 9. fa_user_statistics: 用户统计表，每个用户一条记录
--
-- 数据完整性保证:
-- 1. 使用外键约束确保引用完整性
-- 2. 使用唯一键约束防止重复数据
-- 3. 使用级联删除(ON DELETE CASCADE)保证数据一致性
-- 4. 使用索引优化查询性能
--
-- 字符集说明:
-- - 使用utf8mb4字符集，支持emoji和特殊字符
-- - 所有文本字段使用utf8mb4编码
--
-- 时间戳说明:
-- - 所有时间字段使用Unix时间戳(int类型)
-- - 便于跨时区处理和计算
-- - last_learn_date使用date类型，用于日期比较
--
-- 索引说明:
-- - 主键索引: 所有表的id字段
-- - 唯一索引: 防止重复数据(如手机号、单词文本、关联关系)
-- - 普通索引: 优化常用查询字段(如状态、时间、外键)
--
-- ============================================
