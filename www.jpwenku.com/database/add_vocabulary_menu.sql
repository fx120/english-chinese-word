-- ============================================
-- 添加词表管理和单词管理菜单
-- 执行前请确认 fa_auth_rule 表中 pid 的值
-- ============================================

-- 添加一级菜单：词库管理
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES ('file', 0, 'vocabulary', '词库管理', 'fa fa-book', '', '', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal');

SET @pid = LAST_INSERT_ID();

-- 添加二级菜单：词表管理
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES ('file', @pid, 'vocabulary_list', '词表管理', 'fa fa-list', '', '', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal');

SET @vl_pid = LAST_INSERT_ID();

-- 词表管理的操作权限
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES
('file', @vl_pid, 'vocabulary_list/index', '查看', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/add', '添加', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/edit', '编辑', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/del', '删除', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/words', '管理单词', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/addword', '添加单词', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @vl_pid, 'vocabulary_list/delword', '移除单词', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal');

-- 添加二级菜单：单词管理
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES ('file', @pid, 'word', '单词管理', 'fa fa-font', '', '', 1, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal');

SET @w_pid = LAST_INSERT_ID();

-- 单词管理的操作权限
INSERT INTO `fa_auth_rule` (`type`, `pid`, `name`, `title`, `icon`, `condition`, `remark`, `ismenu`, `createtime`, `updatetime`, `weigh`, `status`)
VALUES
('file', @w_pid, 'word/index', '查看', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @w_pid, 'word/add', '添加', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @w_pid, 'word/edit', '编辑', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal'),
('file', @w_pid, 'word/del', '删除', 'fa fa-circle-o', '', '', 0, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), 0, 'normal');
