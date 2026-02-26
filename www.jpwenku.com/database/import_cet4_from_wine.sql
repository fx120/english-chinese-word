-- ============================================
-- 从 wine_cet4_word 表导入CET4词表数据
-- 前提：wine_cet4_word 表已导入到同一数据库
-- ============================================

SET NAMES utf8mb4;

-- 步骤1: 创建CET4词表
INSERT INTO `fa_vocabulary_list` (`name`, `description`, `category`, `difficulty_level`, `word_count`, `is_official`, `created_at`, `updated_at`, `status`)
VALUES ('大学英语四级词汇', 'CET4核心词汇表，包含4416个常用单词', 'CET4', 3, 0, 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 'normal');

SET @vl_id = LAST_INSERT_ID();

-- 步骤2: 将 wine_cet4_word 的单词导入 fa_word（跳过已存在的）
INSERT IGNORE INTO `fa_word` (`word`, `phonetic`, `part_of_speech`, `definition`, `example`, `created_at`, `updated_at`)
SELECT
    w.`cet4_word`,
    w.`cet4_phonetic`,
    NULL,
    CONCAT(
        w.`cet4_translate`,
        IF(w.`cet4_distortion` IS NOT NULL AND w.`cet4_distortion` != '', CONCAT('\n', w.`cet4_distortion`), '')
    ),
    CASE
        WHEN (w.`cet4_samples` IS NOT NULL AND w.`cet4_samples` != '') AND (w.`cet4_phrase` IS NOT NULL AND w.`cet4_phrase` != '')
            THEN CONCAT('【短语】\n', w.`cet4_phrase`, '\n\n【例句】\n', w.`cet4_samples`)
        WHEN w.`cet4_samples` IS NOT NULL AND w.`cet4_samples` != ''
            THEN w.`cet4_samples`
        WHEN w.`cet4_phrase` IS NOT NULL AND w.`cet4_phrase` != ''
            THEN CONCAT('【短语】\n', w.`cet4_phrase`)
        ELSE NULL
    END,
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP()
FROM `wine_cet4_word` w;

-- 步骤3: 建立词表-单词关联关系（IGNORE跳过重复单词）
INSERT IGNORE INTO `fa_vocabulary_list_word` (`vocabulary_list_id`, `word_id`, `sort_order`, `created_at`)
SELECT
    @vl_id,
    fw.`id`,
    w.`id`,
    UNIX_TIMESTAMP()
FROM `wine_cet4_word` w
INNER JOIN `fa_word` fw ON fw.`word` = w.`cet4_word`
ORDER BY w.`id`;

-- 步骤4: 更新词表的单词数
UPDATE `fa_vocabulary_list`
SET `word_count` = (
    SELECT COUNT(*) FROM `fa_vocabulary_list_word` WHERE `vocabulary_list_id` = @vl_id
),
`updated_at` = UNIX_TIMESTAMP()
WHERE `id` = @vl_id;

-- 完成，查看结果
SELECT CONCAT('导入完成！词表ID: ', @vl_id, ', 单词数: ', word_count) AS result
FROM `fa_vocabulary_list` WHERE `id` = @vl_id;
