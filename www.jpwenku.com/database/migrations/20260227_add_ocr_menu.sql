-- 添加OCR配置菜单到FastAdmin后台
-- 执行方式：在FastAdmin后台 > 权限管理 > 菜单规则 中手动添加，或执行此SQL

-- 添加OCR配置菜单（挂在顶级菜单下）
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES ('menu', 0, 'ocr/setting', 'OCR配置', 'fa fa-camera', '', 'OCR识别服务配置', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal');
