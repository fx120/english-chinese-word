-- 允许同一单词在不同词表中有不同释义
-- 例如：china 在小学词表里释义是"中国"，在CET4词表里释义是"中国；瓷器"

-- 1. 扩大 part_of_speech 字段长度（原来varchar(20)太短）
ALTER TABLE `fa_word` MODIFY COLUMN `part_of_speech` varchar(100) DEFAULT NULL COMMENT '词性(如:n.,v.,adj.)';

-- 2. 去掉 word 字段的唯一约束
-- 注意：索引名可能是 'word' 或其他名称，请先执行 SHOW INDEX FROM fa_word; 确认
ALTER TABLE `fa_word` DROP INDEX `word`;

-- 3. 添加普通索引方便查询
ALTER TABLE `fa_word` ADD INDEX `idx_word_text` (`word`);
