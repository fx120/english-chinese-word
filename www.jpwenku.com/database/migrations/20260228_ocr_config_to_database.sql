-- OCR配置迁移：从文件配置迁移到fa_config数据库表
-- 
-- 注意：此SQL为手动迁移参考。
-- 实际上，访问后台「系统管理 > OCR配置」页面时会自动完成迁移：
--   1. 自动检测fa_config表中是否已有OCR配置项
--   2. 如果没有，自动从旧的 application/extra/ocr.php 读取已有值并写入数据库
--   3. 自动在configgroup中添加ocr分组
--   4. 自动刷新site.php缓存
--
-- 迁移完成后，可以删除旧配置文件 application/extra/ocr.php
-- OCR配置将统一在「常规管理 > 系统配置」的OCR识别分组中管理
--
-- 如需手动执行，请先备份数据库，然后运行以下SQL：

-- 1. 插入OCR配置项（如果旧配置有值，请替换空字符串）
INSERT INTO `fa_config` (`name`, `group`, `title`, `tip`, `type`, `visible`, `value`, `content`, `rule`, `extend`) VALUES
('ocr_provider', 'ocr', 'OCR服务商', '当前仅支持百度OCR', 'select', '', 'baidu', '{"baidu":"百度OCR"}', 'required', ''),
('ocr_baidu_app_id', 'ocr', '百度App ID', '百度智能云OCR应用的App ID', 'string', '', '', '', '', ''),
('ocr_baidu_api_key', 'ocr', '百度API Key', '百度智能云OCR应用的API Key', 'string', '', '', '', 'required', ''),
('ocr_baidu_secret_key', 'ocr', '百度Secret Key', '百度智能云OCR应用的Secret Key', 'string', '', '', '', 'required', ''),
('ocr_max_image_size', 'ocr', '最大图片大小(字节)', '默认4MB=4194304', 'number', '', '4194304', '', '', '');
