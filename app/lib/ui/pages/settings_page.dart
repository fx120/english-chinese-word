import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // 进入设置页时刷新用户信息
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      auth.refreshUserInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isLoggedIn) {
            return _buildNotLoggedIn();
          }
          return CustomScrollView(
            slivers: [
              _buildHeader(auth.user!),
              SliverToBoxAdapter(child: _buildProfileSection(auth.user!)),
              SliverToBoxAdapter(child: _buildAccountSection(auth.user!)),
              SliverToBoxAdapter(child: _buildLogoutButton(auth)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('请先登录', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(User user) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20, right: 20, bottom: 28,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text('个人资料', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 24),
            // 头像
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                  ? NetworkImage(user.avatar!)
                  : null,
              child: user.avatar == null || user.avatar!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 42)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user.nickname ?? '未设置昵称',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(user.bio!, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== 个人信息编辑区 ====================
  Widget _buildProfileSection(User user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('个人信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
            ),
            _buildEditItem(
              icon: Icons.person_outline,
              label: '昵称',
              value: user.nickname ?? '未设置',
              onTap: () => _editNickname(user),
            ),
            _buildDivider(),
            _buildEditItem(
              icon: Icons.wc_outlined,
              label: '性别',
              value: user.genderText,
              onTap: () => _editGender(user),
            ),
            _buildDivider(),
            _buildEditItem(
              icon: Icons.cake_outlined,
              label: '生日',
              value: user.birthday ?? '未设置',
              onTap: () => _editBirthday(user),
            ),
            _buildDivider(),
            _buildEditItem(
              icon: Icons.edit_note_rounded,
              label: '个性签名',
              value: (user.bio != null && user.bio!.isNotEmpty) ? user.bio! : '未设置',
              onTap: () => _editBio(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(User user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('账号信息', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3436))),
            ),
            _buildEditItem(
              icon: Icons.phone_android,
              label: '手机号',
              value: _maskMobile(user.mobile),
              showArrow: false,
            ),
            _buildDivider(),
            _buildEditItem(
              icon: Icons.email_outlined,
              label: '邮箱',
              value: (user.email != null && user.email!.isNotEmpty) ? user.email! : '未设置',
              onTap: () => _editEmail(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditItem({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF4A90E2)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF2D3436))),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showArrow && onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 48, color: Colors.grey.shade200);
  }

  Widget _buildLogoutButton(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmLogout(auth),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('退出登录'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red, width: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  String _maskMobile(String mobile) {
    if (mobile.length >= 11) {
      return '${mobile.substring(0, 3)}****${mobile.substring(7)}';
    }
    return mobile;
  }

  // ==================== 编辑操作 ====================

  Future<void> _editNickname(User user) async {
    final controller = TextEditingController(text: user.nickname ?? '');
    final result = await _showEditDialog(
      title: '修改昵称',
      hint: '请输入昵称（最多20个字符）',
      controller: controller,
      maxLength: 20,
    );
    if (result != null && result.isNotEmpty) {
      await _saveField({'nickname': result});
    }
  }

  Future<void> _editBio(User user) async {
    final controller = TextEditingController(text: user.bio ?? '');
    final result = await _showEditDialog(
      title: '修改个性签名',
      hint: '写点什么介绍自己吧（最多100个字符）',
      controller: controller,
      maxLength: 100,
      maxLines: 3,
    );
    if (result != null) {
      await _saveField({'bio': result});
    }
  }

  Future<void> _editEmail(User user) async {
    final controller = TextEditingController(text: user.email ?? '');
    final result = await _showEditDialog(
      title: '修改邮箱',
      hint: '请输入邮箱地址',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
    );
    if (result != null) {
      await _saveField({'email': result});
    }
  }

  Future<void> _editGender(User user) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('选择性别', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              _buildGenderOption(ctx, '男', 1, user.gender == 1),
              _buildGenderOption(ctx, '女', 2, user.gender == 2),
              _buildGenderOption(ctx, '保密', 0, user.gender == 0),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (result != null) {
      await _saveField({'gender': result});
    }
  }

  Widget _buildGenderOption(BuildContext ctx, String label, int value, bool selected) {
    return ListTile(
      title: Text(label, textAlign: TextAlign.center),
      trailing: selected ? const Icon(Icons.check_rounded, color: Color(0xFF4A90E2)) : null,
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  Future<void> _editBirthday(User user) async {
    DateTime initial = DateTime(2000, 1, 1);
    if (user.birthday != null && user.birthday!.isNotEmpty) {
      try {
        initial = DateTime.parse(user.birthday!);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('zh'),
    );
    if (picked != null) {
      final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      await _saveField({'birthday': dateStr});
    }
  }

  Future<String?> _showEditDialog({
    required String title,
    required String hint,
    required TextEditingController controller,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 17)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveField(Map<String, dynamic> data) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '修改成功' : '修改失败: ${auth.error ?? "未知错误"}'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmLogout(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？学习数据会保留在本地。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await auth.logout();
      if (mounted) Navigator.pop(context);
    }
  }
}
